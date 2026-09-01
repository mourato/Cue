//
//  RecordingRegionOverlayWindow.swift
//  Notinhas
//
//  Persistent overlay window showing the recording region highlight
//

import AppKit

enum RecordingRegionOverlayGuidanceTone {
    case neutral
    case active
    case warning
    case progress

    var accentColor: NSColor {
        switch self {
        case .neutral:
            NSColor.white.withAlphaComponent(0.85)
        case .active:
            NSColor.systemBlue
        case .warning:
            NSColor.systemOrange
        case .progress:
            NSColor.systemTeal
        }
    }
}

struct RecordingRegionOverlayGuidance {
    let title: String
    let detail: String?
    let tone: RecordingRegionOverlayGuidanceTone
}

// MARK: - RecordingRegionOverlayDelegate

/// Delegate protocol for overlay interaction events
@MainActor
protocol RecordingRegionOverlayDelegate: AnyObject {
    func overlayDidRequestReselection(_ overlay: RecordingRegionOverlayWindow)
    func overlay(_ overlay: RecordingRegionOverlayWindow, didMoveRegionTo rect: CGRect)
    func overlayDidFinishMoving(_ overlay: RecordingRegionOverlayWindow)
    func overlay(_ overlay: RecordingRegionOverlayWindow, didReselectWithRect rect: CGRect)
    func overlay(
        _ overlay: RecordingRegionOverlayWindow,
        didResizeRegionTo rect: CGRect,
        modifiers: NSEvent.ModifierFlags,
    )
    func overlayDidFinishResizing(_ overlay: RecordingRegionOverlayWindow)
}

// MARK: - RecordingRegionOverlayWindow

/// Overlay panel showing the recording region highlight during recording
/// Uses NSPanel with .nonactivatingPanel to prevent background windows from deactivating
@MainActor
final class RecordingRegionOverlayWindow: NSPanel {
    weak var interactionDelegate: RecordingRegionOverlayDelegate?

    private let overlayView: RecordingRegionOverlayView
    private var receivesKeyboardInput = false

    init(screen: NSScreen, highlightRect: CGRect) {
        overlayView = RecordingRegionOverlayView(
            frame: screen.frame,
            highlightRect: highlightRect,
        )

        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false,
        )

        configureWindow(screen: screen)
        contentView = overlayView
    }

    private func configureWindow(screen: NSScreen) {
        isFloatingPanel = true
        isOpaque = false
        backgroundColor = .clear
        sharingType = .none
        level = .floating
        ignoresMouseEvents = true
        acceptsMouseMovedEvents = true
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        animationBehavior = .none // Disable window animations for instant appearance
        becomesKeyOnlyIfNeeded = true

        isMovable = false
        isMovableByWindowBackground = false
        minSize = screen.frame.size
        maxSize = screen.frame.size
    }

    override func setFrame(_ frameRect: NSRect, display displayFlag: Bool) {
        minSize = frameRect.size
        maxSize = frameRect.size
        super.setFrame(frameRect, display: displayFlag)
    }

    func updateHighlightRect(_ rect: CGRect) {
        let oldLocalRect = overlayView.localHighlightRect()
        overlayView.highlightRect = rect
        let newLocalRect = overlayView.localHighlightRect()

        // Dirty-rect invalidation: only redraw the union of old + new positions
        // with padding for resize handles and border width, instead of the entire
        // full-screen view (which can be 15M+ pixels on 4K/5K).
        let handlePadding: CGFloat = 25 // cornerHandleLength + margin
        let dirtyRect = oldLocalRect.insetBy(dx: -handlePadding, dy: -handlePadding)
            .union(newLocalRect.insetBy(dx: -handlePadding, dy: -handlePadding))
        overlayView.setNeedsDisplay(dirtyRect)
    }

    func updateBoundarySnapGuides(_ guides: [CaptureSelectionSnappingEdge: CGFloat]) {
        overlayView.boundarySnapGuides = guides
    }

    func updateGuidance(_ guidance: RecordingRegionOverlayGuidance?) {
        overlayView.guidance = guidance
    }

    /// Hide the border when recording starts (border would appear in video)
    func hideBorder() {
        overlayView.showBorder = false
        overlayView.needsDisplay = true
    }

    /// Show the border (for pre-record phase)
    func showBorder() {
        overlayView.showBorder = true
        overlayView.needsDisplay = true
    }

    /// When false, resize handles still draw but the continuous white outline is omitted.
    func setDrawsContinuousBorder(_ drawsContinuousBorder: Bool) {
        overlayView.drawsContinuousBorder = drawsContinuousBorder
        overlayView.needsDisplay = true
    }

    /// Enable or disable mouse interaction (disabled during recording)
    func setInteractionEnabled(_ enabled: Bool) {
        ignoresMouseEvents = !enabled
        overlayView.isInteractionEnabled = enabled
        if !enabled {
            overlayView.boundarySnapGuides = [:]
        }
        if enabled {
            overlayView.overlayWindow = self
        }
        overlayView.refreshCursor()
    }

    func refreshCursor() {
        overlayView.refreshCursor()
    }

    func cursorKind(atScreenLocation location: CGPoint) -> CaptureSelectionCursorKind {
        guard let contentView else { return .arrow }
        let windowPoint = convertPoint(fromScreen: location)
        let localPoint = contentView.convert(windowPoint, from: nil)
        return overlayView.cursorKind(for: localPoint)
    }

    /// Allow the All-In-One refinement controller to move key ownership to the
    /// overlay under the pointer without activating the application.
    func setReceivesKeyboardInput(_ receivesKeyboardInput: Bool) {
        self.receivesKeyboardInput = receivesKeyboardInput
    }

    func activateKeyboardInputIfNeeded() {
        guard receivesKeyboardInput else { return }
        makeKey()
        makeFirstResponder(overlayView)
        overlayView.updateTrackingAreas()
        overlayView.refreshCursor()
    }

    var isGestureInProgress: Bool {
        overlayView.isGestureInProgress
    }

    /// Active resize handle while the user is dragging a resize affordance.
    var currentResizeHandle: RecordingResizeHandle? {
        overlayView.currentResizeHandle
    }

    /// Only update interaction state when it actually changes, to avoid
    /// redundant invalidateCursorRects calls on every drag event.
    func setInteractionEnabledIfNeeded(_ enabled: Bool) {
        guard overlayView.isInteractionEnabled != enabled else { return }
        setInteractionEnabled(enabled)
    }

    override func close() {
        // Restore cursor to arrow before closing — the overlay may have set
        // a resize, openHand, or crosshair cursor that could persist if the
        // window is dismissed before mouseExited fires.
        NSCursor.arrow.set()
        super.close()
    }

    // Non-activating: prevent stealing focus from other apps
    override var canBecomeKey: Bool {
        receivesKeyboardInput
    }

    override var canBecomeMain: Bool {
        false
    }
}

// MARK: - RecordingRegionOverlayView

/// View that draws the dimmed overlay with highlighted recording region
final class RecordingRegionOverlayView: NSView {
    var highlightRect: CGRect
    var showBorder: Bool = true
    var drawsContinuousBorder: Bool = true
    var isInteractionEnabled: Bool = false
    var guidance: RecordingRegionOverlayGuidance? {
        didSet {
            needsDisplay = true
        }
    }

    var boundarySnapGuides: [CaptureSelectionSnappingEdge: CGFloat] = [:] {
        didSet {
            needsDisplay = true
        }
    }

    weak var overlayWindow: RecordingRegionOverlayWindow?

    // Drag state
    private var isDragging = false
    private var dragOffset: CGPoint = .zero

    // Resize state
    private var isResizing = false
    private var activeHandle: RecordingResizeHandle?
    private var resizeStartRect: CGRect = .zero
    private var resizeStartPoint: CGPoint = .zero

    // New selection state (for immediate reselection on click outside)
    private var isNewSelecting = false
    private var newSelectionStart: CGPoint = .zero
    private var newSelectionEnd: CGPoint = .zero

    /// Resize state exposed for refinement snapping integration.
    var currentResizeHandle: RecordingResizeHandle? {
        isResizing ? activeHandle : nil
    }

    var isGestureInProgress: Bool {
        isDragging || isResizing || isNewSelecting
    }

    // Cross-display event monitors — allow drag/resize/reselect gestures to continue
    // seamlessly when the pointer crosses screen boundaries. Without these, per-view
    // mouse events stop once the pointer exits this window's frame.
    private var crossDisplayLocalMonitor: Any?
    private var crossDisplayGlobalMonitor: Any?

    // Constants
    private let dimColor = NSColor.black.withAlphaComponent(0.4)
    private let borderColor = NSColor.white
    private let borderWidth = CaptureSelectionChromeMetrics.continuousBorderWidth
    private let handleHitSize = CaptureSelectionChromeMetrics.handleHitSize
    private let minimumSelectionSize = CaptureSelectionChromeMetrics.confirmedMinimumSize

    init(frame: CGRect, highlightRect: CGRect) {
        self.highlightRect = highlightRect
        super.init(frame: frame)
        setupTrackingArea()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupTrackingArea() {
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect, .cursorUpdate],
            owner: self,
            userInfo: nil,
        )
        addTrackingArea(trackingArea)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        setupTrackingArea()
    }

    override func cursorUpdate(with event: NSEvent) {
        guard isInteractionEnabled else {
            NSCursor.arrow.set()
            return
        }
        updateCursorFor(point: convert(event.locationInWindow, from: nil))
    }

    override func mouseEntered(with event: NSEvent) {
        guard isInteractionEnabled else {
            NSCursor.arrow.set()
            return
        }
        updateCursorFor(point: convert(event.locationInWindow, from: nil))
    }

    override func mouseExited(with _: NSEvent) {
        NSCursor.arrow.set()
    }

    override func resetCursorRects() {
        if !isInteractionEnabled {
            addCursorRect(bounds, cursor: .arrow)
            return
        }

        addCursorRect(bounds, cursor: .crosshair)

        let localRect = localHighlightRect()
        if !localRect.isEmpty {
            addCursorRect(localRect, cursor: .openHand)
            registerResizeHandleCursorRects(for: localRect)
        }
    }

    private func registerResizeHandleCursorRects(for rect: CGRect) {
        let hitSize = handleHitSize
        let layout = CaptureSelectionChromeLayout.layout(for: rect)
        for handle in layout.availableHandles {
            let hitRect = CaptureSelectionHandleGeometry.hitRect(for: handle, in: rect, hitSize: hitSize)
            addCursorRect(hitRect, cursor: CaptureSelectionResizeCursor.cursor(for: handle))
        }
    }

    func refreshCursor() {
        window?.invalidateCursorRects(for: self)

        guard isInteractionEnabled, let window else {
            NSCursor.arrow.set()
            return
        }

        let windowPoint = window.convertPoint(fromScreen: NSEvent.mouseLocation)
        let point = convert(windowPoint, from: nil)
        if bounds.contains(point) {
            updateCursorFor(point: point)
        }
    }

    /// Accept first mouse click without requiring window activation
    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    // MARK: - Coordinate Conversion

    func localHighlightRect() -> CGRect {
        guard let window else { return .zero }
        let windowFrame = window.frame
        return CGRect(
            x: highlightRect.origin.x - windowFrame.origin.x,
            y: highlightRect.origin.y - windowFrame.origin.y,
            width: highlightRect.width,
            height: highlightRect.height,
        )
    }

    private func convertToScreenCoords(_ localPoint: CGPoint) -> CGPoint {
        guard let window else { return localPoint }
        return CGPoint(
            x: localPoint.x + window.frame.origin.x,
            y: localPoint.y + window.frame.origin.y,
        )
    }

    // MARK: - Resize Handle Detection

    private func handleAt(point: CGPoint) -> RecordingResizeHandle? {
        let rect = localHighlightRect()
        let layout = CaptureSelectionChromeLayout.layout(for: rect)
        return CaptureSelectionHandleGeometry.handle(
            at: point,
            in: rect,
            hitSize: handleHitSize,
            layout: layout,
        )
    }

    func cursorKind(for point: CGPoint) -> CaptureSelectionCursorKind {
        guard isInteractionEnabled else { return .arrow }
        if let handle = handleAt(point: point) {
            return .resize(handle)
        }
        let localRect = localHighlightRect()
        if localRect.contains(point) {
            return .openHand
        }
        return .crosshair
    }
}

// MARK: - Drawing helpers (continued)

extension RecordingRegionOverlayView {
    private func calculateResizedRect(
        handle: RecordingResizeHandle,
        delta: CGPoint,
        modifiers: NSEvent.ModifierFlags,
    ) -> CGRect {
        let resized = CaptureSelectionGeometry.resizedRect(
            original: resizeStartRect,
            handle: handle,
            translation: delta,
            aspectLocked: false,
            aspectRatio: nil,
            minSize: minimumSelectionSize,
        )
        guard !modifiers.contains(.option) else { return resized }
        let candidates = CaptureSelectionSnapping.screenBoundaryCandidates(for: Self.unifiedDesktopFrame)
        return CaptureSelectionSnapping.resolve(
            proposedRect: resized,
            handle: handle,
            candidates: candidates,
            configuration: CaptureSelectionSnappingConfiguration.fromPreferences(),
            desktopBounds: Self.unifiedDesktopFrame,
            minSize: minimumSelectionSize,
        ).rect
    }

    // MARK: - Unified Desktop Frame

    /// Union of all connected screen frames — used as the outer boundary for
    /// cross-display drag/resize/reselect so the selection can move freely
    /// between displays but not drift outside the physical display area.
    private static var unifiedDesktopFrame: CGRect {
        NSScreen.screens.reduce(CGRect.null) { $0.union($1.frame) }
    }

    // MARK: - Cross-Display Event Monitors

    /// Install local + global event monitors so drag/resize/reselect gestures
    /// continue seamlessly when the pointer crosses a screen boundary.
    /// Each per-screen `NSView` stops receiving `mouseDragged`/`mouseUp` once
    /// the pointer exits its window's frame; these monitors fill that gap by
    /// using `NSEvent.mouseLocation` (global screen coordinates).
    private func installCrossDisplayMonitorIfNeeded() {
        guard crossDisplayLocalMonitor == nil else { return }

        crossDisplayLocalMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDragged, .leftMouseUp],
        ) { [weak self] event in
            guard let self else { return event }
            let screenPoint = NSEvent.mouseLocation
            switch event.type {
            case .leftMouseDragged:
                handleCrossDisplayDrag(screenPoint: screenPoint, modifiers: event.modifierFlags)
            case .leftMouseUp:
                handleCrossDisplayMouseUp(screenPoint: screenPoint)
            default:
                break
            }
            // Consume the event so the per-view handler doesn't double-process.
            return nil
        }

        crossDisplayGlobalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDragged, .leftMouseUp],
        ) { [weak self] event in
            let screenPoint = NSEvent.mouseLocation
            switch event.type {
            case .leftMouseDragged:
                self?.handleCrossDisplayDrag(screenPoint: screenPoint, modifiers: event.modifierFlags)
            case .leftMouseUp:
                self?.handleCrossDisplayMouseUp(screenPoint: screenPoint)
            default:
                break
            }
        }
    }

    private func removeCrossDisplayMonitor() {
        if let monitor = crossDisplayLocalMonitor {
            NSEvent.removeMonitor(monitor)
            crossDisplayLocalMonitor = nil
        }
        if let monitor = crossDisplayGlobalMonitor {
            NSEvent.removeMonitor(monitor)
            crossDisplayGlobalMonitor = nil
        }
    }

    override func removeFromSuperview() {
        removeCrossDisplayMonitor()
        super.removeFromSuperview()
    }

    // MARK: - Cross-Display Drag/Resize/Reselect Handlers

    /// Clamp `rect` so it stays fully within the unified desktop frame.
    private func clampRectToDesktop(_ rect: CGRect) -> CGRect {
        let desktop = Self.unifiedDesktopFrame
        var origin = rect.origin
        origin.x = max(desktop.minX, min(origin.x, desktop.maxX - rect.width))
        origin.y = max(desktop.minY, min(origin.y, desktop.maxY - rect.height))
        return CGRect(origin: origin, size: rect.size)
    }

    /// Clamp resize result so edges stay within the unified desktop frame
    /// while enforcing minimum selection size.
    private func clampResizedRectToDesktop(_ rect: CGRect) -> CGRect {
        let desktop = Self.unifiedDesktopFrame
        var r = rect
        // Clamp left edge
        if r.minX < desktop.minX {
            r.size.width -= (desktop.minX - r.minX)
            r.origin.x = desktop.minX
        }
        // Clamp bottom edge
        if r.minY < desktop.minY {
            r.size.height -= (desktop.minY - r.minY)
            r.origin.y = desktop.minY
        }
        // Clamp right edge
        if r.maxX > desktop.maxX {
            r.size.width = desktop.maxX - r.origin.x
        }
        // Clamp top edge
        if r.maxY > desktop.maxY {
            r.size.height = desktop.maxY - r.origin.y
        }
        // Re-enforce minimum size after clamping
        r.size.width = max(r.width, minimumSelectionSize)
        r.size.height = max(r.height, minimumSelectionSize)
        return r
    }

    private func handleCrossDisplayDrag(screenPoint: CGPoint, modifiers: NSEvent.ModifierFlags) {
        guard let overlayWindow else { return }

        if isResizing, let handle = activeHandle {
            // Resize: compute delta in screen coordinates relative to the start point.
            let screenStartPoint = convertToScreenCoords(resizeStartPoint)
            let delta = CGPoint(x: screenPoint.x - screenStartPoint.x, y: screenPoint.y - screenStartPoint.y)
            let newRect = clampResizedRectToDesktop(
                calculateResizedRect(handle: handle, delta: delta, modifiers: modifiers),
            )
            overlayWindow.interactionDelegate?.overlay(
                overlayWindow,
                didResizeRegionTo: newRect,
                modifiers: modifiers,
            )
            return
        }

        if isNewSelecting {
            // Reselect: track in screen coordinates.
            newSelectionEnd = screenPoint
            // Trigger redraw on all overlay windows via the delegate's highlight update.
            let rect = calculateNewSelectionScreenRect()
            if rect.width > 0, rect.height > 0 {
                overlayWindow.interactionDelegate?.overlay(
                    overlayWindow,
                    didResizeRegionTo: rect,
                    modifiers: modifiers,
                )
            }
            return
        }

        if isDragging {
            // Drag: compute new origin in screen coordinates and clamp to desktop.
            let newScreenOrigin = CGPoint(
                x: screenPoint.x - dragOffset.x,
                y: screenPoint.y - dragOffset.y,
            )
            let newRect = clampRectToDesktop(
                CGRect(origin: newScreenOrigin, size: highlightRect.size),
            )
            overlayWindow.interactionDelegate?.overlay(overlayWindow, didMoveRegionTo: newRect)
        }
    }

    private func handleCrossDisplayMouseUp(screenPoint: CGPoint) {
        guard let overlayWindow else {
            removeCrossDisplayMonitor()
            return
        }

        if isResizing {
            isResizing = false
            activeHandle = nil
            removeCrossDisplayMonitor()
            overlayWindow.interactionDelegate?.overlayDidFinishResizing(overlayWindow)
            let localPoint = convertFromScreenCoords(screenPoint)
            updateCursorFor(point: localPoint)
            return
        }

        if isNewSelecting {
            isNewSelecting = false
            removeCrossDisplayMonitor()
            let rect = calculateNewSelectionScreenRect()
            if rect.width > 5, rect.height > 5 {
                overlayWindow.interactionDelegate?.overlay(overlayWindow, didReselectWithRect: rect)
            }
            needsDisplay = true
            return
        }

        if isDragging {
            isDragging = false
            removeCrossDisplayMonitor()
            NSCursor.openHand.set()
            overlayWindow.interactionDelegate?.overlayDidFinishMoving(overlayWindow)
        }
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        guard isInteractionEnabled, overlayWindow != nil else { return }

        let point = convert(event.locationInWindow, from: nil)
        let localRect = localHighlightRect()

        // Check for resize handle first
        if let handle = handleAt(point: point) {
            isResizing = true
            activeHandle = handle
            resizeStartRect = highlightRect
            resizeStartPoint = point
            CaptureSelectionResizeCursor.cursor(for: handle).set()
            installCrossDisplayMonitorIfNeeded()
            return
        }

        if localRect.contains(point) {
            // Start dragging existing selection — store offset in screen coordinates
            // so the drag tracks correctly across display boundaries.
            isDragging = true
            let screenPoint = NSEvent.mouseLocation
            dragOffset = CGPoint(
                x: screenPoint.x - highlightRect.origin.x,
                y: screenPoint.y - highlightRect.origin.y,
            )
            NSCursor.closedHand.set()
            installCrossDisplayMonitorIfNeeded()
        } else {
            // Click outside - start new selection. Track in screen coordinates
            // so the gesture can span multiple displays.
            isNewSelecting = true
            let screenPoint = NSEvent.mouseLocation
            newSelectionStart = screenPoint
            newSelectionEnd = screenPoint
            NSCursor.crosshair.set()
            installCrossDisplayMonitorIfNeeded()
        }
    }

    override func mouseDragged(with _: NSEvent) {
        // Cross-display monitors handle drag events via handleCrossDisplayDrag().
        // This override is kept as a no-op guard so the gesture doesn't double-fire
        // when the pointer is still inside this view's window.
    }

    override func mouseUp(with _: NSEvent) {
        // Cross-display monitors handle mouseUp via handleCrossDisplayMouseUp().
        // This override is kept as a no-op guard.
    }

    /// Calculate new selection rect from screen-coordinate start/end points.
    private func calculateNewSelectionScreenRect() -> CGRect {
        let minX = min(newSelectionStart.x, newSelectionEnd.x)
        let maxX = max(newSelectionStart.x, newSelectionEnd.x)
        let minY = min(newSelectionStart.y, newSelectionEnd.y)
        let maxY = max(newSelectionStart.y, newSelectionEnd.y)
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Convert a screen-space point to this view's local coordinate space.
    private func convertFromScreenCoords(_ screenPoint: CGPoint) -> CGPoint {
        guard let window else { return screenPoint }
        return CGPoint(
            x: screenPoint.x - window.frame.origin.x,
            y: screenPoint.y - window.frame.origin.y,
        )
    }

    override func mouseMoved(with event: NSEvent) {
        guard isInteractionEnabled else { return }
        let point = convert(event.locationInWindow, from: nil)
        updateCursorFor(point: point)
    }

    private func updateCursorFor(point: CGPoint) {
        // Check for resize handle first
        if let handle = handleAt(point: point) {
            CaptureSelectionResizeCursor.cursor(for: handle).set()
            return
        }

        let localRect = localHighlightRect()
        if localRect.contains(point) {
            NSCursor.openHand.set()
        } else {
            NSCursor.crosshair.set()
        }
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Draw dim overlay — only the dirty region
        dimColor.setFill()
        dirtyRect.fill()
        drawBoundarySnapGuides(in: dirtyRect)

        // If actively making new selection, draw that instead
        if isNewSelecting {
            drawNewSelection()
            return
        }

        // Convert screen coords to view coords
        guard let window else { return }
        let windowFrame = window.frame
        let localRect = CGRect(
            x: highlightRect.origin.x - windowFrame.origin.x,
            y: highlightRect.origin.y - windowFrame.origin.y,
            width: highlightRect.width,
            height: highlightRect.height,
        )

        // Only draw highlight if rect intersects this screen
        guard localRect.intersects(bounds) else { return }

        // Clamp to bounds
        let clampedRect = localRect.intersection(bounds)

        // Clear the highlight area (only the portion within dirtyRect)
        let clearRect = clampedRect.intersection(dirtyRect)
        if !clearRect.isNull {
            NSColor.clear.setFill()
            clearRect.fill(using: .copy)
        }

        // Draw border around highlight (only in pre-record phase)
        if showBorder {
            // Only draw border and handles if they intersect the dirty rect
            let handlePadding: CGFloat = 25
            let borderArea = clampedRect.insetBy(dx: -handlePadding, dy: -handlePadding)
            if borderArea.intersects(dirtyRect) {
                if drawsContinuousBorder {
                    let borderPath = NSBezierPath(rect: clampedRect)
                    borderPath.lineWidth = borderWidth
                    borderColor.setStroke()
                    borderPath.stroke()
                }

                drawRecordingResizeHandles(for: clampedRect)
            }
        }

        if let guidance, bounds.contains(CGPoint(x: localRect.midX, y: localRect.midY)) {
            drawGuidance(guidance, in: clampedRect)
        }
    }

    private func drawBoundarySnapGuides(in _: NSRect) {
        guard !boundarySnapGuides.isEmpty else { return }
        let windowOrigin = overlayWindow?.frame.origin ?? .zero
        let guideColor = NSColor.systemTeal.withAlphaComponent(0.9)
        let guidePath = NSBezierPath()
        guidePath.lineWidth = 1
        guidePath.setLineDash([4, 3], count: 2, phase: 0)
        guideColor.setStroke()

        for x in [boundarySnapGuides[.minX], boundarySnapGuides[.maxX]].compactMap(\.self) {
            let localX = x - windowOrigin.x
            if bounds.insetBy(dx: -1, dy: 0).contains(CGPoint(x: localX, y: bounds.midY)) {
                guidePath.move(to: CGPoint(x: localX, y: bounds.minY))
                guidePath.line(to: CGPoint(x: localX, y: bounds.maxY))
            }
        }
        for y in [boundarySnapGuides[.minY], boundarySnapGuides[.maxY]].compactMap(\.self) {
            let localY = y - windowOrigin.y
            if bounds.insetBy(dx: 0, dy: -1).contains(CGPoint(x: bounds.midX, y: localY)) {
                guidePath.move(to: CGPoint(x: bounds.minX, y: localY))
                guidePath.line(to: CGPoint(x: bounds.maxX, y: localY))
            }
        }
        guidePath.stroke()
    }

    private func drawGuidance(_ guidance: RecordingRegionOverlayGuidance, in rect: CGRect) {
        let horizontalInset = min(max(16, rect.width * 0.08), 28)
        let availableWidth = rect.width - horizontalInset * 2
        guard availableWidth >= 120 else { return }

        let prefersCompactLayout = rect.width < 230 || rect.height < 110
        let showsDetail = !prefersCompactLayout && guidance.detail != nil
        let titleFont = NSFont.systemFont(ofSize: prefersCompactLayout ? 15 : 17, weight: .semibold)
        let detailFont = NSFont.systemFont(ofSize: prefersCompactLayout ? 11 : 12, weight: .medium)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byWordWrapping

        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
        shadow.shadowBlurRadius = 8
        shadow.shadowOffset = .zero

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraphStyle,
            .shadow: shadow,
        ]
        let detailAttributes: [NSAttributedString.Key: Any] = [
            .font: detailFont,
            .foregroundColor: NSColor.white.withAlphaComponent(0.84),
            .paragraphStyle: paragraphStyle,
        ]

        let textWidth = min(availableWidth - 24, 336)
        let titleString = NSAttributedString(string: guidance.title, attributes: titleAttributes)
        let titleBounds = titleString.boundingRect(
            with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
        )

        let detailString = showsDetail
            ? NSAttributedString(string: guidance.detail ?? "", attributes: detailAttributes)
            : nil
        let detailBounds = detailString?.boundingRect(
            with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
        ) ?? .zero

        let cardWidth = min(max(160, textWidth + 24), availableWidth)
        let cardHeight = max(
            prefersCompactLayout ? 38 : 44,
            ceil(titleBounds.height) + (showsDetail ? ceil(detailBounds.height) + 6 : 0) + 22,
        )
        let defaultY = rect.maxY - cardHeight - 18
        let cardY = max(rect.minY + 12, defaultY)
        let cardRect = CGRect(
            x: rect.midX - cardWidth / 2,
            y: cardY,
            width: cardWidth,
            height: cardHeight,
        )

        let fillPath = NSBezierPath(
            roundedRect: cardRect,
            xRadius: prefersCompactLayout ? 12 : 14,
            yRadius: prefersCompactLayout ? 12 : 14,
        )
        NSColor.black.withAlphaComponent(prefersCompactLayout ? 0.74 : 0.8).setFill()
        fillPath.fill()

        let strokePath = NSBezierPath(
            roundedRect: cardRect,
            xRadius: prefersCompactLayout ? 12 : 14,
            yRadius: prefersCompactLayout ? 12 : 14,
        )
        strokePath.lineWidth = 1
        guidance.tone.accentColor.withAlphaComponent(0.5).setStroke()
        strokePath.stroke()

        let accentRect = CGRect(
            x: cardRect.midX - min(cardRect.width * 0.22, 44) / 2,
            y: cardRect.maxY - 6,
            width: min(cardRect.width * 0.22, 44),
            height: 3,
        )
        let accentPath = NSBezierPath(
            roundedRect: accentRect,
            xRadius: 1.5,
            yRadius: 1.5,
        )
        guidance.tone.accentColor.withAlphaComponent(0.95).setFill()
        accentPath.fill()

        let titleRect = CGRect(
            x: cardRect.minX + 12,
            y: cardRect
                .maxY - ceil(titleBounds.height) - (showsDetail ? 12 : (cardHeight - ceil(titleBounds.height)) / 2),
            width: cardRect.width - 24,
            height: ceil(titleBounds.height),
        )
        titleString.draw(with: titleRect, options: [.usesLineFragmentOrigin, .usesFontLeading])

        if let detailString, showsDetail {
            let detailRect = CGRect(
                x: cardRect.minX + 12,
                y: cardRect.minY + 10,
                width: cardRect.width - 24,
                height: ceil(detailBounds.height),
            )
            detailString.draw(with: detailRect, options: [.usesLineFragmentOrigin, .usesFontLeading])
        }
    }

    private func drawRecordingResizeHandles(for rect: CGRect) {
        let colors = CaptureSelectionChromeAppearance
            .colors(for: CaptureSelectionChromeAppearanceContext(backdropLuma: nil))

        for bar in CaptureSelectionHandleGeometry.handleBars(
            in: rect,
            coordinateSpace: .bottomLeftOrigin,
        ) {
            drawHandleBar(bar, colors: colors, coordinateSpace: .bottomLeftOrigin)
        }
    }

    private func drawHandleBar(
        _ rect: CGRect,
        colors: CaptureSelectionChromeColors,
        coordinateSpace: CaptureSelectionCoordinateSpace,
    ) {
        let radius = CaptureSelectionChromeMetrics.handleCornerRadius
        let shadowOffset = CaptureSelectionChromeMetrics.handleShadowOffset(for: coordinateSpace)

        // Draw shadow
        let shadowPath = NSBezierPath(
            roundedRect: rect.offsetBy(dx: shadowOffset.width, dy: shadowOffset.height),
            xRadius: radius,
            yRadius: radius,
        )
        NSColor.black.withAlphaComponent(colors.shadowOpacity).setFill()
        shadowPath.fill()

        // Draw bar with rounded ends
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        NSColor(
            red: colors.strokeRed,
            green: colors.strokeGreen,
            blue: colors.strokeBlue,
            alpha: colors.strokeAlpha,
        ).setFill()
        path.fill()
    }

    private func drawNewSelection() {
        // New selection is now tracked in screen coordinates. Convert to local
        // for rendering, then clip to this view's bounds.
        let screenRect = calculateNewSelectionScreenRect()
        guard screenRect.width > 0, screenRect.height > 0 else { return }

        let localOrigin = convertFromScreenCoords(screenRect.origin)
        let localRect = CGRect(origin: localOrigin, size: screenRect.size)
            .intersection(bounds)
        guard !localRect.isEmpty else { return }

        // Clear the selection area
        NSColor.clear.setFill()
        localRect.fill(using: .copy)

        if drawsContinuousBorder {
            let borderPath = NSBezierPath(rect: localRect)
            borderPath.lineWidth = borderWidth
            borderColor.setStroke()
            borderPath.stroke()
        }

        // Draw size indicator (show full screen-space dimensions, not clipped)
        let sizeText = "\(Int(screenRect.width)) x \(Int(screenRect.height))"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let textSize = sizeText.size(withAttributes: attributes)
        var textRect = CGRect(
            x: localRect.maxX - textSize.width - 8,
            y: localRect.minY - textSize.height - 8,
            width: textSize.width + 8,
            height: textSize.height + 4,
        )
        if textRect.minY < 0 {
            textRect.origin.y = localRect.maxY + 4
        }
        if textRect.maxX > bounds.maxX {
            textRect.origin.x = localRect.minX
        }

        NSColor.black.withAlphaComponent(0.7).setFill()
        NSBezierPath(roundedRect: textRect, xRadius: 4, yRadius: 4).fill()
        sizeText.draw(at: CGPoint(x: textRect.minX + 4, y: textRect.minY + 2), withAttributes: attributes)
    }
}
