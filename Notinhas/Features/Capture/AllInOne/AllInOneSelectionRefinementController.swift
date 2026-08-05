//
//  AllInOneSelectionRefinementController.swift
//  Notinhas
//
//  Presents per-screen recording region overlays to refine an All-In-One capture selection.
//

import AppKit

@MainActor
final class AllInOneSelectionRefinementController: NSObject {
    var onRectChanged: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    /// Screen-space frames of floating HUDs that must keep the arrow cursor.
    var cursorExclusionFrames: () -> [CGRect] = { [] }

    private var currentRect: CGRect
    private var regionOverlayWindows: [ObjectIdentifier: RecordingRegionOverlayWindow] = [:]
    private var cursorTrackingTimer: Timer?
    private var keyboardOwnerOverlayID: ObjectIdentifier?
    private var localEscapeMonitor: Any?
    private var globalEscapeMonitor: Any?
    private var screenParametersObserver: NSObjectProtocol?

    private var aspectLocked: Bool
    private var lockedAspectRatio: CGFloat?
    private var resizeStartRect: CGRect?
    private var activeResizeHandle: CaptureSelectionResizeHandle?

    private var snappingConfiguration: CaptureSelectionSnappingConfiguration
    private let semanticProvider: CaptureSelectionSemanticBoundaryProviding
    private let backdropCapturer: any AreaSelectionBackdropCapturing
    private var backdropCache: [CGDirectDisplayID: AreaSelectionBackdrop] = [:]
    private var backdropSamplers: [CGDirectDisplayID: CaptureSelectionSnappingCGImageSampler] = [:]
    private var backdropTasks: [CGDirectDisplayID: Task<Void, Never>] = [:]
    private let frozenBackdrops: [CGDirectDisplayID: AreaSelectionBackdrop]?

    init(
        initialRect: CGRect,
        aspectLocked: Bool = false,
        aspectRatio: CGFloat? = nil,
        snappingConfiguration: CaptureSelectionSnappingConfiguration? = nil,
        semanticProvider: CaptureSelectionSemanticBoundaryProviding? = nil,
        backdropCapturer: (any AreaSelectionBackdropCapturing)? = nil,
        frozenBackdrops: [CGDirectDisplayID: AreaSelectionBackdrop]? = nil,
    ) {
        currentRect = CaptureSelectionGeometry.normalized(
            initialRect,
            minSize: CaptureSelectionSnapping.refinementMinimumSize,
        )
        self.aspectLocked = aspectLocked
        lockedAspectRatio = aspectRatio ?? CaptureSelectionGeometry.aspectRatio(of: initialRect)
        self.snappingConfiguration = snappingConfiguration ?? Self.loadSnappingConfiguration()
        self.semanticProvider = semanticProvider ?? CaptureSelectionSemanticBoundaryProvider()
        self.backdropCapturer = backdropCapturer ?? AreaSelectionBackdropCapturerPolicy.makeDefault()
        self.frozenBackdrops = frozenBackdrops
        super.init()
    }

    isolated deinit {
        if let screenParametersObserver {
            NotificationCenter.default.removeObserver(screenParametersObserver)
        }
        if let localEscapeMonitor {
            NSEvent.removeMonitor(localEscapeMonitor)
        }
        if let globalEscapeMonitor {
            NSEvent.removeMonitor(globalEscapeMonitor)
        }
        cursorTrackingTimer?.invalidate()
        backdropTasks.values.forEach { $0.cancel() }
        regionOverlayWindows.removeAll()
    }

    // MARK: - Session

    func present() {
        tearDownOverlays()
        observeScreenParameters()
        reconcileScreenOverlays()
        startCursorTrackingIfNeeded()
        installEscapeMonitorsIfNeeded()
        refreshBackdropCache()
        publishRectChange()
    }

    func tearDown() {
        removeEscapeMonitors()
        removeScreenParametersObserver()
        cancelBackdropTasks()
        semanticProvider.clearCache()
        stopCursorTracking()
        tearDownOverlays()
        resizeStartRect = nil
        activeResizeHandle = nil
        onRectChanged = nil
        onCancel = nil
    }

    func updateAspectLock(_ locked: Bool) {
        aspectLocked = locked
        if locked, lockedAspectRatio == nil {
            lockedAspectRatio = CaptureSelectionGeometry.aspectRatio(of: currentRect)
        }
        if locked, let ratio = lockedAspectRatio {
            updateRect(CaptureSelectionGeometry.rectByLockingAspectRatio(currentRect, aspectRatio: ratio))
        }
    }

    func updateLockedAspectRatio(_ ratio: CGFloat?) {
        lockedAspectRatio = ratio
        guard aspectLocked, let ratio, ratio > 0 else { return }
        updateRect(CaptureSelectionGeometry.rectByLockingAspectRatio(currentRect, aspectRatio: ratio))
    }

    func applyRect(_ rect: CGRect) {
        updateRect(rect)
    }

    var rect: CGRect {
        currentRect
    }

    var backdropCacheCountForTesting: Int {
        backdropCache.count
    }

    // MARK: - Overlays

    private func makeRegionOverlay(for screen: NSScreen) -> RecordingRegionOverlayWindow {
        let overlay = RecordingRegionOverlayWindow(screen: screen, highlightRect: currentRect)
        overlay.setDrawsContinuousBorder(false)
        overlay.interactionDelegate = self
        overlay.setInteractionEnabled(true)
        overlay.orderFrontRegardless()
        overlay.refreshCursor()
        return overlay
    }

    private func observeScreenParameters() {
        guard screenParametersObserver == nil else { return }
        screenParametersObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main,
        ) { [weak self] _ in
            self?.reconcileScreenOverlays()
            if self?.frozenBackdrops == nil {
                self?.refreshBackdropCache()
            }
        }
    }

    private func removeScreenParametersObserver() {
        if let screenParametersObserver {
            NotificationCenter.default.removeObserver(screenParametersObserver)
            self.screenParametersObserver = nil
        }
    }

    private func reconcileScreenOverlays() {
        let screens = NSScreen.screens
        let screenIDs = Set(screens.map(ObjectIdentifier.init))

        let removedScreenIDs = regionOverlayWindows.keys.filter { !screenIDs.contains($0) }
        for screenID in removedScreenIDs {
            guard let overlay = regionOverlayWindows[screenID] else { continue }
            if keyboardOwnerOverlayID == ObjectIdentifier(overlay) {
                keyboardOwnerOverlayID = nil
            }
            overlay.interactionDelegate = nil
            overlay.close()
            regionOverlayWindows.removeValue(forKey: screenID)
        }

        for screen in screens {
            let screenID = ObjectIdentifier(screen)
            if let overlay = regionOverlayWindows[screenID] {
                overlay.updateHighlightRect(currentRect)
            } else {
                regionOverlayWindows[screenID] = makeRegionOverlay(for: screen)
            }
        }
    }

    private func tearDownOverlays() {
        for overlay in regionOverlayWindows.values {
            overlay.interactionDelegate = nil
            overlay.close()
        }
        regionOverlayWindows.removeAll()
        keyboardOwnerOverlayID = nil
    }

    // MARK: - Cursor ownership

    /// A nonactivating panel receives reliable cursor rects only while it owns
    /// key-window state. Polling the pointer lets All-In-One keep the app in the
    /// background while moving that ownership between per-display overlays.
    private func startCursorTrackingIfNeeded() {
        guard cursorTrackingTimer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.handleCursorTrackingTick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        cursorTrackingTimer = timer
    }

    private func handleCursorTrackingTick() {
        guard !regionOverlayWindows.isEmpty else { return }

        let location = NSEvent.mouseLocation

        if let ownerID = keyboardOwnerOverlayID,
           let owner = regionOverlayWindows[ownerID],
           owner.isGestureInProgress {
            return
        }
        guard let overlay = regionOverlayWindows.values.first(where: { $0.frame.contains(location) }) else {
            return
        }

        let overlayID = ObjectIdentifier(overlay)
        if overlayID != keyboardOwnerOverlayID {
            if let previousOwnerID = keyboardOwnerOverlayID,
               let previousOwner = regionOverlayWindows[previousOwnerID] {
                previousOwner.setReceivesKeyboardInput(false)
            }
            keyboardOwnerOverlayID = overlayID
            overlay.setReceivesKeyboardInput(true)
            overlay.orderFrontRegardless()
            overlay.activateKeyboardInputIfNeeded()
        }
    }

    func cursorKind(at location: CGPoint) -> CaptureSelectionCursorKind? {
        if let ownerID = keyboardOwnerOverlayID,
           let owner = regionOverlayWindows[ownerID],
           owner.isGestureInProgress {
            return owner.cursorKind(atScreenLocation: location)
        }
        guard let overlay = regionOverlayWindows.values.first(where: { $0.frame.contains(location) }) else {
            return .arrow
        }
        return overlay.cursorKind(atScreenLocation: location)
    }

    private func stopCursorTracking() {
        cursorTrackingTimer?.invalidate()
        cursorTrackingTimer = nil
        keyboardOwnerOverlayID = nil
    }

    private func updateRect(_ rect: CGRect, notifyDuringInteraction: Bool = true) {
        let normalizedRect = CaptureSelectionGeometry.normalized(
            rect,
            minSize: CaptureSelectionSnapping.refinementMinimumSize,
        )
        guard normalizedRect != currentRect else { return }

        currentRect = normalizedRect
        for overlay in regionOverlayWindows.values {
            overlay.updateHighlightRect(normalizedRect)
        }

        if notifyDuringInteraction {
            publishRectChange()
        }
    }

    private func finishInteraction(with rect: CGRect) {
        var finalRect = CaptureSelectionGeometry.normalized(
            rect,
            minSize: CaptureSelectionSnapping.refinementMinimumSize,
        )
        if aspectLocked, activeResizeHandle != nil {
            finalRect = aspectLockedResizeRect(from: rect)
        } else if aspectLocked, let ratio = lockedAspectRatio, ratio > 0 {
            finalRect = CaptureSelectionGeometry.rectByLockingAspectRatio(finalRect, aspectRatio: ratio)
        }
        updateRect(finalRect)
        resizeStartRect = nil
        activeResizeHandle = nil
        semanticProvider.clearCache()
    }

    private func beginResizeIfNeeded(with proposedRect: CGRect, overlay: RecordingRegionOverlayWindow) {
        guard resizeStartRect == nil else { return }
        resizeStartRect = currentRect
        if let recordingHandle = overlay.currentResizeHandle {
            activeResizeHandle = captureHandle(from: recordingHandle)
        } else {
            activeResizeHandle = inferResizeHandle(from: currentRect, to: proposedRect)
        }
    }

    private func aspectLockedResizeRect(from proposedRect: CGRect) -> CGRect {
        guard let startRect = resizeStartRect,
              let handle = activeResizeHandle,
              let ratio = lockedAspectRatio,
              ratio > 0 else {
            return CaptureSelectionGeometry.normalized(
                proposedRect,
                minSize: CaptureSelectionSnapping.refinementMinimumSize,
            )
        }

        return CaptureSelectionGeometry.resizedRect(
            original: startRect,
            handle: handle,
            translation: resizeTranslation(from: startRect, to: proposedRect, handle: handle),
            aspectLocked: true,
            aspectRatio: ratio,
            minSize: CaptureSelectionSnapping.refinementMinimumSize,
        )
    }

    private func applySnapping(to rawProposedRect: CGRect, pointer: CGPoint) -> CGRect {
        guard let handle = activeResizeHandle else {
            return rawProposedRect
        }

        let screen = screenContaining(point: pointer) ?? NSScreen.main
        let screenFrame = screen?.frame ?? .zero
        let displayID = screen?.displayID ?? CGMainDisplayID()

        var candidates: [CaptureSelectionSnappingCandidate] = []
        // NSEvent.mouseLocation is AppKit's bottom-left global coordinate. The AX
        // provider follows the existing Smart Element contract and expects the
        // Quartz/AX top-left global coordinate returned by CGEvent.
        let accessibilityPointer = CGEvent(source: nil)?.location ?? pointer
        candidates.append(
            contentsOf: semanticProvider.semanticCandidates(
                at: accessibilityPointer,
                ownerPID: nil,
                handle: handle,
            ),
        )

        if let backdrop = backdropCache[displayID] {
            candidates.append(
                contentsOf: CaptureSelectionSnapping.imageCandidates(
                    proposedRect: rawProposedRect,
                    handle: handle,
                    backdrop: backdrop,
                    screenFrame: screenFrame,
                    configuration: snappingConfiguration,
                    sampler: backdropSamplers[displayID],
                ),
            )
        }

        let desktopBounds = unifiedDesktopFrame
        let result = CaptureSelectionSnapping.resolve(
            proposedRect: rawProposedRect,
            handle: handle,
            candidates: candidates,
            configuration: snappingConfiguration,
            desktopBounds: desktopBounds,
            minSize: CaptureSelectionSnapping.refinementMinimumSize,
        )
        return result.rect
    }

    private func refreshBackdropCache() {
        cancelBackdropTasks()
        backdropCache.removeAll()

        if let frozenBackdrops, !frozenBackdrops.isEmpty {
            backdropCache = frozenBackdrops
            for (displayID, backdrop) in frozenBackdrops {
                if let sampler = CaptureSelectionSnappingCGImageSampler(image: backdrop.image) {
                    backdropSamplers[displayID] = sampler
                }
            }
            return
        }

        for screen in NSScreen.screens {
            guard let displayID = screen.displayID else { continue }
            let captureRect = screen.frame
            let scaleFactor = screen.backingScaleFactor
            backdropTasks[displayID] = Task { @MainActor [backdropCapturer] in
                guard !Task.isCancelled else { return }
                let backdrop = await backdropCapturer.captureBackdrop(
                    displayID: displayID,
                    captureRect: captureRect,
                    scaleFactor: scaleFactor,
                    isVisible: true,
                )
                guard !Task.isCancelled, let backdrop else { return }
                backdropCache[displayID] = backdrop
                if let sampler = CaptureSelectionSnappingCGImageSampler(image: backdrop.image) {
                    backdropSamplers[displayID] = sampler
                }
            }
        }
    }

    private func cancelBackdropTasks() {
        backdropTasks.values.forEach { $0.cancel() }
        backdropTasks.removeAll()
        backdropCache.removeAll()
        backdropSamplers.removeAll()
    }

    private var unifiedDesktopFrame: CGRect {
        NSScreen.screens.reduce(CGRect.null) { $0.union($1.frame) }
    }

    private func screenContaining(point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) }
            ?? NSScreen.screens.first { $0.frame.insetBy(dx: -1, dy: -1).contains(point) }
    }

    private static func loadSnappingConfiguration() -> CaptureSelectionSnappingConfiguration {
        CaptureSelectionSnappingConfiguration.fromPreferences()
    }

    private func captureHandle(from recordingHandle: RecordingResizeHandle) -> CaptureSelectionResizeHandle {
        switch recordingHandle {
        case .topLeft: .topLeft
        case .top: .top
        case .topRight: .topRight
        case .left: .left
        case .right: .right
        case .bottomLeft: .bottomLeft
        case .bottom: .bottom
        case .bottomRight: .bottomRight
        }
    }

    private func inferResizeHandle(from startRect: CGRect, to proposedRect: CGRect) -> CaptureSelectionResizeHandle {
        let tolerance: CGFloat = 0.01
        let leftChanged = abs(startRect.minX - proposedRect.minX) > tolerance
        let rightChanged = abs(startRect.maxX - proposedRect.maxX) > tolerance
        let bottomChanged = abs(startRect.minY - proposedRect.minY) > tolerance
        let topChanged = abs(startRect.maxY - proposedRect.maxY) > tolerance

        switch (leftChanged, rightChanged, bottomChanged, topChanged) {
        case (true, false, true, false): return .bottomLeft
        case (true, false, false, true): return .topLeft
        case (false, true, true, false): return .bottomRight
        case (false, true, false, true): return .topRight
        case (false, true, false, false): return .right
        case (true, false, false, false): return .left
        case (false, false, true, false): return .bottom
        case (false, false, false, true): return .top
        default: return .bottomRight
        }
    }

    private func resizeTranslation(
        from startRect: CGRect,
        to proposedRect: CGRect,
        handle: CaptureSelectionResizeHandle,
    ) -> CGPoint {
        switch handle {
        case .topLeft:
            CGPoint(x: proposedRect.minX - startRect.minX, y: proposedRect.height - startRect.height)
        case .top:
            CGPoint(x: 0, y: proposedRect.height - startRect.height)
        case .topRight:
            CGPoint(x: proposedRect.width - startRect.width, y: proposedRect.height - startRect.height)
        case .left:
            CGPoint(x: proposedRect.minX - startRect.minX, y: 0)
        case .right:
            CGPoint(x: proposedRect.width - startRect.width, y: 0)
        case .bottomLeft:
            CGPoint(x: proposedRect.minX - startRect.minX, y: proposedRect.minY - startRect.minY)
        case .bottom:
            CGPoint(x: 0, y: proposedRect.minY - startRect.minY)
        case .bottomRight:
            CGPoint(x: proposedRect.width - startRect.width, y: proposedRect.minY - startRect.minY)
        }
    }

    private func publishRectChange() {
        onRectChanged?(currentRect)
    }

    // MARK: - Escape

    private func installEscapeMonitorsIfNeeded() {
        guard localEscapeMonitor == nil else { return }

        localEscapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }
            guard let self else { return event }
            return handleEscape() ? nil : event
        }

        globalEscapeMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return }
            DispatchQueue.main.async {
                _ = self?.handleEscape()
            }
        }
    }

    private func removeEscapeMonitors() {
        if let localEscapeMonitor {
            NSEvent.removeMonitor(localEscapeMonitor)
            self.localEscapeMonitor = nil
        }
        if let globalEscapeMonitor {
            NSEvent.removeMonitor(globalEscapeMonitor)
            self.globalEscapeMonitor = nil
        }
    }

    @discardableResult
    private func handleEscape() -> Bool {
        // `onCancel` owns session teardown (coordinator.cancel → refinement.tearDown).
        // Do not tear down again here; that races MainActor deinit of this controller.
        let cancel = onCancel
        onCancel = nil
        onRectChanged = nil
        cancel?()
        return true
    }
}

// MARK: - RecordingRegionOverlayDelegate

extension AllInOneSelectionRefinementController: RecordingRegionOverlayDelegate {
    func overlayDidRequestReselection(_: RecordingRegionOverlayWindow) {}

    func overlay(_: RecordingRegionOverlayWindow, didMoveRegionTo rect: CGRect) {
        updateRect(rect)
    }

    func overlayDidFinishMoving(_: RecordingRegionOverlayWindow) {
        finishInteraction(with: currentRect)
    }

    func overlay(_: RecordingRegionOverlayWindow, didReselectWithRect rect: CGRect) {
        finishInteraction(with: rect)
    }

    func overlay(_ overlay: RecordingRegionOverlayWindow, didResizeRegionTo rect: CGRect) {
        beginResizeIfNeeded(with: rect, overlay: overlay)
        let snappedRect = applySnapping(to: rect, pointer: NSEvent.mouseLocation)
        updateRect(aspectLocked ? aspectLockedResizeRect(from: snappedRect) : snappedRect)
    }

    func overlayDidFinishResizing(_: RecordingRegionOverlayWindow) {
        finishInteraction(with: currentRect)
    }
}
