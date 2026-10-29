//
//  AllInOneCaptureCommandDispatcher.swift
//  Cue
//
//  Hands an All-In-One command to the capture flow that performs it.
//

import CoreGraphics

@MainActor
enum AllInOneCaptureCommandDispatcher {
    /// Runs `command` after the All-In-One session is torn down. Takes ownership of
    /// `frozenSession`: flows that cannot reuse it invalidate it.
    static func dispatch(
        _ command: AllInOneCaptureCommand,
        viewModel: ScreenCaptureViewModel,
        frozenSession: FrozenAreaCaptureSession?,
        freezeEnabled: Bool
    ) {
        switch command {
        case let .area(rect):
            runAreaBased(
                rect: rect,
                context: AreaContext(viewModel: viewModel, frozenSession: frozenSession, freezeEnabled: freezeEnabled),
                frozen: { viewModel.captureArea(at: $0, from: $1) },
                live: { viewModel.captureArea(at: $0) },
                select: { viewModel.captureArea() }
            )
        case .fullscreen:
            frozenSession?.invalidate()
            viewModel.captureFullscreen()
        case .window:
            frozenSession?.invalidate()
            viewModel.captureApplication()
        case .activeWindow:
            frozenSession?.invalidate()
            viewModel.captureActiveWindow()
        case let .annotate(rect):
            runAreaBased(
                rect: rect,
                context: AreaContext(viewModel: viewModel, frozenSession: frozenSession, freezeEnabled: freezeEnabled),
                frozen: { viewModel.captureAreaAnnotate(at: $0, from: $1) },
                live: { viewModel.captureAreaAnnotate(at: $0) },
                select: { viewModel.captureAreaAnnotate() }
            )
        case let .scrolling(rect):
            frozenSession?.invalidate()
            if let rect {
                viewModel.captureScrolling(at: rect)
            } else {
                viewModel.captureScrolling()
            }
        case let .ocr(rect):
            runAreaBased(
                rect: rect,
                context: AreaContext(viewModel: viewModel, frozenSession: frozenSession, freezeEnabled: freezeEnabled),
                frozen: { viewModel.captureOCR(at: $0, from: $1) },
                live: { viewModel.captureOCR(at: $0) },
                select: { viewModel.captureOCR() }
            )
        case .timer:
            frozenSession?.invalidate()
        case .objectCutout:
            frozenSession?.invalidate()
            viewModel.captureObjectCutout()
        case .smartElement:
            frozenSession?.invalidate()
            SmartElementCaptureController.shared.startCapture()
        case let .recording(rect):
            frozenSession?.invalidate()
            #if CUE_VIDEO_MODULE
                let capturedViewModel = viewModel
                DiagnosticLogger.shared.log(
                    .info,
                    .recording,
                    "All-In-One recording handoff queued",
                    context: [
                        "hasRect": "\(rect != nil)",
                        "areaSelectionPresenting": "\(AreaSelectionController.shared.isPresenting)"
                    ]
                )
                DispatchQueue.main.async { [weak capturedViewModel] in
                    guard let capturedViewModel else {
                        DiagnosticLogger.shared.log(
                            .warning,
                            .recording,
                            "All-In-One recording handoff dropped: view model deallocated"
                        )
                        return
                    }
                    if let rect {
                        capturedViewModel.startRecordingFlow(at: rect)
                    } else {
                        capturedViewModel.startRecordingFlow()
                    }
                }
            #endif
        }
    }
    private struct AreaContext {
        let viewModel: ScreenCaptureViewModel
        let frozenSession: FrozenAreaCaptureSession?
        let freezeEnabled: Bool
    }

    /// Freeze sessions need both the frozen backdrop and a rect; live captures fall
    /// back to a fresh selection when no rect exists.
    private static func runAreaBased(
        rect: CGRect?,
        context: AreaContext,
        frozen: (CGRect, FrozenAreaCaptureSession) -> Void,
        live: (CGRect) -> Void,
        select: () -> Void
    ) {
        if context.freezeEnabled {
            guard let frozenSession = context.frozenSession, let rect else {
                context.frozenSession?.invalidate()
                context.viewModel.recordCaptureFailure(.captureFailed(L10n.ScreenCapture.unableToCaptureSelectedArea))
                return
            }
            frozen(rect, frozenSession)
        } else if let rect {
            live(rect)
        } else {
            select()
        }
    }
}
