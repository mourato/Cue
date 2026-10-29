//
//  AllInOneCaptureCoordinator.swift
//  Notinhas
//
//  Owns the All-In-One capture session: HUD toolbars, selection refinement, and dispatch.
//

import AppKit
import Carbon.HIToolbox
import SwiftUI

@MainActor
final class AllInOneCaptureCoordinator {
    static let shared = AllInOneCaptureCoordinator()

    private weak var viewModel: ScreenCaptureViewModel?
    private var sessionState: AllInOneCaptureSessionState?
    private var modeHUD: CaptureFloatingHUDWindow?
    private var actionHUD: CaptureFloatingHUDWindow?
    private var refinementController: AllInOneSelectionRefinementController?
    private var frozenSession: FrozenAreaCaptureSession?
    private var frozenBackdropHost = AllInOneFrozenBackdropHost()
    private let timerScheduler = AllInOneTimerScheduler()
    private var isActive = false
    private var isTearingDown = false
    private var isAwaitingInitialSelection = false
    private var sessionGeneration = UUID()
    private let cursorArbiter = AllInOneCaptureCursorArbiter()
    private var localModeShortcutMonitor: Any?

    private init() {}

    var isSessionActive: Bool {
        isActive
    }

    static func isSelectedModeActivationKey(_ keyCode: UInt16) -> Bool {
        keyCode == UInt16(kVK_Return) || keyCode == UInt16(kVK_ANSI_KeypadEnter)
    }

    func start(from viewModel: ScreenCaptureViewModel) {
        timerScheduler.cancel()
        if isActive || isTearingDown {
            cancel()
        }

        self.viewModel = viewModel
        isActive = true
        let generation = UUID()
        sessionGeneration = generation

        let configuredModes = AllInOneCaptureModeConfigurationStore.shared.orderedModes(
            videoEnabled: VideoModuleAvailability.isEnabled,
            includeDisabled: false
        )
        let state = AllInOneCaptureSessionState(availableModes: configuredModes)
        state.onModeActivated = { [weak self] mode in
            guard let self, isActive, sessionGeneration == generation else { return }
            // Area-based modes need a rect. Before the first drag finishes, keep the open
            // selection instead of failing (freeze) or consuming the frozen session (timer).
            guard !(isAwaitingInitialSelection && mode.preservesSelectionRect) else { return }
            activate(mode)
        }
        state.onRectChanged = { [weak self] rect in
            guard let self, isActive, sessionGeneration == generation else { return }
            applyRect(rect)
        }
        state.onCancel = { [weak self] in
            guard let self, isActive, sessionGeneration == generation else { return }
            cancel()
        }
        state.onAspectLockChanged = { [weak self] locked, ratio in
            guard let self, isActive, sessionGeneration == generation else { return }
            refinementController?.updateLockedAspectRatio(ratio)
            refinementController?.updateAspectLock(locked)
        }
        sessionState = state

        if viewModel.isFreezeAreaCaptureEnabled {
            Task { @MainActor [weak self] in
                await self?.startWithFrozenSessionIfNeeded(generation: generation)
            }
        } else {
            continueStartup(generation: generation)
        }
    }

    func cancel() {
        guard isActive else {
            timerScheduler.cancel()
            return
        }

        sessionGeneration = UUID()
        tearDownSession(invalidateFrozenSession: true)
        DiagnosticLogger.shared.log(.info, .capture, "All-In-One capture session cancelled")
    }

    /// Test seam: builds a live HUD + `ObservableObject` session, then relies on `cancel()`
    /// for teardown — the path that crashed on All-In-One hotkey re-entry.
    func seedActiveHUDSessionForTesting() {
        cancel()
        isActive = true
        let state = AllInOneCaptureSessionState(videoEnabled: false)
        state.currentRect = CGRect(x: 40, y: 50, width: 320, height: 180)
        state.onCancel = { [weak self] in
            self?.cancel()
        }
        sessionState = state

        let modeWindow = CaptureFloatingHUDWindow()
        modeWindow.setContent(AnyView(AllInOneCaptureToolbarView(session: state)))
        modeHUD = modeWindow

        let actionWindow = CaptureFloatingHUDWindow()
        actionWindow.setContent(AnyView(AllInOneActionToolbarView(session: state)))
        actionHUD = actionWindow
    }

    // MARK: - Private

    private func startWithFrozenSessionIfNeeded(generation: UUID) async {
        guard isActive, sessionGeneration == generation, let viewModel else { return }

        switch await viewModel.prepareAllInOneFrozenSelectionSession() {
        case let .success(session):
            guard isActive, sessionGeneration == generation else {
                session.invalidate()
                return
            }
            frozenSession = session
            continueStartup(generation: generation)
        case let .failure(error):
            guard isActive, sessionGeneration == generation else { return }
            viewModel.recordCaptureFailure(error)
            tearDownSession(invalidateFrozenSession: true)
        }
    }

    private func continueStartup(generation: UUID) {
        guard isActive, sessionGeneration == generation else { return }

        installHUDs(using: sessionState!)
        syncHUDDisplayLevel()
        startCursorOwnershipIfNeeded()
        installModeShortcutMonitorsIfNeeded()

        let screenFrames = NSScreen.screens.map(\.frame)
        if let lastRect = CaptureLastSelectionStore.restoredRect(userDefaults: .standard, screens: screenFrames) {
            showFrozenBackdropHostIfNeeded()
            beginRefinement(with: lastRect, generation: generation)
        } else {
            startInitialAreaSelection(generation: generation)
        }
    }

    private func installHUDs(using state: AllInOneCaptureSessionState) {
        let modeWindow = CaptureFloatingHUDWindow()
        modeWindow.setContent(AnyView(AllInOneCaptureToolbarView(session: state)))

        let actionWindow = CaptureFloatingHUDWindow()
        actionWindow.setContent(AnyView(AllInOneActionToolbarView(session: state)))

        modeHUD = modeWindow
        actionHUD = actionWindow
        positionHUDs()
    }

    private func startInitialAreaSelection(generation: UUID) {
        isAwaitingInitialSelection = true
        viewModel?.setAllInOneSelectionBlocking(true)

        AreaSelectionController.shared.cursorExclusionFrames = { [weak self] in
            self?.visibleHUDFrames() ?? []
        }

        let backdrops = frozenSession?.backdrops ?? [:]
        AreaSelectionController.shared.startSelection(
            mode: .screenshot,
            backdrops: backdrops,
            completion: { [weak self] result in
                guard let self else { return }
                guard isActive, sessionGeneration == generation else { return }
                isAwaitingInitialSelection = false
                viewModel?.setAllInOneSelectionBlocking(false)
                AreaSelectionController.shared.cursorExclusionFrames = { [] }

                guard let result else {
                    cancel()
                    return
                }

                showFrozenBackdropHostIfNeeded()
                beginRefinement(with: result.rect, generation: generation)
            }
        )

        // AreaSelectionController presents screen-saver-level panels. Reassert the All-In-One
        // controls above them so the user can change modes before completing the first drag.
        DispatchQueue.main.async { [weak self] in
            guard let self, isActive, sessionGeneration == generation, isAwaitingInitialSelection else { return }
            syncHUDDisplayLevel()
        }
    }

    private func syncHUDDisplayLevel() {
        let level: CaptureFloatingHUDDisplayLevel = isAwaitingInitialSelection ? .aboveCaptureOverlay : .standard
        modeHUD?.setDisplayLevel(level)
        actionHUD?.setDisplayLevel(level)
        positionHUDs()
    }

    private func beginRefinement(with rect: CGRect, generation: UUID) {
        guard isActive, sessionGeneration == generation else { return }
        let normalized = CaptureSelectionGeometry.normalized(
            rect,
            minSize: CaptureSelectionChromeMetrics.confirmedMinimumSize
        )
        sessionState?.currentRect = normalized
        positionHUDs()

        let aspectLocked = UserDefaults.standard.bool(forKey: PreferencesKeys.captureAllInOneAspectRatioLocked)
        let aspectRatio = CaptureSelectionGeometry.aspectRatio(of: normalized)

        refinementController?.onCancel = nil
        refinementController?.onRectChanged = nil
        refinementController?.tearDown()

        let controller = AllInOneSelectionRefinementController(
            initialRect: normalized,
            aspectLocked: aspectLocked,
            aspectRatio: aspectRatio,
            frozenBackdrops: frozenSession?.backdrops
        )
        controller.onRectChanged = { [weak self] updated in
            guard let self, isActive, sessionGeneration == generation else { return }
            handleRefinementRectChanged(updated)
        }
        controller.onCancel = { [weak self] in
            guard let self, isActive, sessionGeneration == generation else { return }
            cancel()
        }
        refinementController = controller
        controller.cursorExclusionFrames = { [weak self] in
            self?.visibleHUDFrames() ?? []
        }
        controller.present()
        syncHUDDisplayLevel()
    }

    // MARK: - HUD cursor exclusion

    private func visibleHUDFrames() -> [CGRect] {
        [modeHUD, actionHUD].compactMap { window in
            guard let window, window.isVisible else { return nil }
            let frame = window.frame
            guard frame.width > 1, frame.height > 1 else { return nil }
            return frame
        }
    }

    private func startCursorOwnershipIfNeeded() {
        cursorArbiter.hudExclusionFrames = { [weak self] in
            self?.visibleHUDFrames() ?? []
        }
        cursorArbiter.fallbackCursor = { [weak self] in
            self?.isAwaitingInitialSelection == true ? .crosshair : .arrow
        }
        cursorArbiter.overlayCandidate = { [weak self] location in
            self?.refinementController?.cursorKind(at: location)
        }
        AreaSelectionController.shared.cursorOwner = { [weak self] location in
            self?.cursorArbiter.resolvedCursor(at: location)
        }
        cursorArbiter.startPolling()
    }

    private func stopCursorOwnership() {
        cursorArbiter.stopPolling()
        AreaSelectionController.shared.cursorOwner = nil
        cursorArbiter.fallbackCursor = nil
        cursorArbiter.overlayCandidate = nil
        cursorArbiter.hudExclusionFrames = { [] }
    }

    private func showFrozenBackdropHostIfNeeded() {
        guard let backdrops = frozenSession?.backdrops, !backdrops.isEmpty else { return }
        frozenBackdropHost.present(backdrops: backdrops)
    }

    private func handleRefinementRectChanged(_ rect: CGRect) {
        sessionState?.currentRect = rect
        positionHUDs()
    }

    private func applyRect(_ rect: CGRect) {
        let screens = NSScreen.screens.map(\.frame)
        let normalized = CaptureSelectionGeometry.fitted(CaptureSelectionGeometry.normalized(rect), toScreens: screens)
            ?? CaptureSelectionGeometry.normalized(rect)
        sessionState?.currentRect = normalized
        refinementController?.applyRect(normalized)
        positionHUDs()
    }

    private func positionHUDs() {
        let anchorRect = sessionState?.currentRect ?? defaultAnchorRect()
        let showsDimensions = sessionState?.selectedMode.showsDimensionsBar == true
            && sessionState?.currentRect != nil

        guard let modeHUD else { return }

        // Refresh sizes without single-toolbar reposition; paired/absolute placement follows.
        modeHUD.refreshContentSize(reposition: false)

        if showsDimensions, let actionHUD {
            actionHUD.refreshContentSize(reposition: false)
            let screen = NSScreen.screens.first(where: { $0.frame.intersects(anchorRect) })
                ?? ScreenUtility.activeScreen()
            let screenFrame = screen.visibleFrame
            let origins = CaptureFloatingToolbarPlacement.pairedFrameOrigins(
                leadingSize: modeHUD.frame.size,
                trailingSize: actionHUD.frame.size,
                anchorRect: anchorRect,
                screenFrame: screenFrame
            )
            modeHUD.show(at: origins.leading)
            if let trailing = origins.trailing {
                actionHUD.show(at: trailing)
            }
        } else {
            actionHUD?.orderOut(nil)
            modeHUD.show(anchorRect: anchorRect)
        }
    }

    private func defaultAnchorRect() -> CGRect {
        let screen = ScreenUtility.activeScreen()
        let frame = screen.visibleFrame
        return CGRect(
            x: frame.midX - 160,
            y: frame.midY - 120,
            width: 320,
            height: 240
        )
    }

    private func activate(_ mode: AllInOneCaptureMode) {
        guard isActive, let viewModel, let sessionState else { return }

        let rect = sessionState.currentRect
        let command = AllInOneCaptureCommand.make(for: mode, rect: rect)
        let freezeEnabled = viewModel.isFreezeAreaCaptureEnabled
        let transferredSession = frozenSession
        frozenSession = nil

        // Annotate and recording keep the selection editable, so those flows save
        // the area themselves once the user finishes or starts recording.
        // Timer saves when the countdown fires, so a cancelled countdown keeps the old area.
        if let rect, ![.annotate, .recording, .timer].contains(mode), mode.preservesSelectionRect {
            Self.rememberArea(rect)
        }

        if case let .timer(rect) = command {
            guard let rect else {
                transferredSession?.invalidate()
                DiagnosticLogger.shared.log(.info, .capture, "All-In-One timer capture ignored: no selection")
                return
            }

            transferredSession?.invalidate()
            let capturedViewModel = viewModel
            let capturedRect = rect
            tearDownSession(invalidateFrozenSession: false)
            timerScheduler.scheduleAreaCapture { [capturedViewModel] in
                Self.rememberArea(capturedRect)
                capturedViewModel.captureAreaWithFreshFrozenSession(at: capturedRect)
            }
            DiagnosticLogger.shared.log(.info, .capture, "All-In-One timer capture scheduled")
            return
        }

        tearDownSession(invalidateFrozenSession: false)

        AllInOneCaptureCommandDispatcher.dispatch(
            command,
            viewModel: viewModel,
            frozenSession: transferredSession,
            freezeEnabled: freezeEnabled
        )
    }

    private static func rememberArea(_ rect: CGRect) {
        guard CaptureLastSelectionStore.isEnabled(userDefaults: .standard) else { return }
        CaptureLastSelectionStore.save(rect, userDefaults: .standard)
    }

    private func tearDownSession(invalidateFrozenSession: Bool) {
        guard !isTearingDown else { return }
        isTearingDown = true
        defer { isTearingDown = false }

        isActive = false
        let ownsInitialSelection = isAwaitingInitialSelection
        isAwaitingInitialSelection = false
        timerScheduler.cancel()
        removeModeShortcutMonitors()
        stopCursorOwnership()
        viewModel?.setAllInOneSelectionBlocking(false)
        AreaSelectionController.shared.cursorExclusionFrames = { [] }

        // Break observation callbacks before releasing SwiftUI-hosted state.
        sessionState?.onModeActivated = { _ in }
        sessionState?.onRectChanged = { _ in }
        sessionState?.onCancel = {}
        sessionState?.onAspectLockChanged = { _, _ in }

        refinementController?.onCancel = nil
        refinementController?.onRectChanged = nil
        refinementController?.tearDown()

        frozenBackdropHost.tearDown()

        if invalidateFrozenSession {
            frozenSession?.invalidate()
        }

        if ownsInitialSelection {
            AreaSelectionController.shared.cancelSelection()
        }

        modeHUD?.restoreStandardDisplayLevel()
        actionHUD?.restoreStandardDisplayLevel()
        modeHUD?.clearContent()
        actionHUD?.clearContent()
        modeHUD?.close()
        actionHUD?.close()

        // Keep @MainActor-isolated session/HUD objects alive until the next main-queue
        // turn. Releasing them synchronously inside start()/cancel() on the hotkey stack
        // has crashed in swift_task_deinitOnExecutor (EXC_BAD_ACCESS at 0x220).
        let orphanedRefinement = refinementController
        let orphanedModeHUD = modeHUD
        let orphanedActionHUD = actionHUD
        let orphanedSessionState = sessionState
        let orphanedFrozenSession = frozenSession

        refinementController = nil
        modeHUD = nil
        actionHUD = nil
        sessionState = nil
        frozenSession = nil
        viewModel = nil

        DispatchQueue.main.async {
            _ = orphanedRefinement
            _ = orphanedModeHUD
            _ = orphanedActionHUD
            _ = orphanedSessionState
            _ = orphanedFrozenSession
        }
    }

    // MARK: - Mode shortcuts (child layer)

    private func installModeShortcutMonitorsIfNeeded() {
        guard localModeShortcutMonitor == nil else { return }

        localModeShortcutMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return handleModeShortcut(event) ? nil : event
        }
        // No global monitor: it cannot consume keys, so other apps would also receive them.
    }

    private func removeModeShortcutMonitors() {
        if let localModeShortcutMonitor {
            NSEvent.removeMonitor(localModeShortcutMonitor)
            self.localModeShortcutMonitor = nil
        }
    }

    @discardableResult
    private func handleModeShortcut(_ event: NSEvent) -> Bool {
        // A focused dimensions field keeps its own keys (digits, Return).
        guard isActive, let sessionState, !(NSApp.keyWindow?.firstResponder is NSText) else { return false }

        if Self.isSelectedModeActivationKey(event.keyCode) {
            sessionState.activateSelectedMode()
            return true
        }

        guard KeyboardShortcutManager.shared.isShortcutEnabled(for: .allInOne),
              let mode = AllInOneModeShortcutSettings.mode(matching: event, in: sessionState.availableModes)
        else {
            return false
        }
        sessionState.activateMode(mode)
        return true
    }
}
