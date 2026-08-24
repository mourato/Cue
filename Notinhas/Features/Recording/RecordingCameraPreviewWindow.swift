#if NOTINHAS_VIDEO_MODULE
    import AppKit
    import AVFoundation

    enum RecordingCameraPreviewPlacement {
        static let inset: CGFloat = 16
        static let maximumWidth: CGFloat = 240
        static let aspectRatio: CGFloat = 16 / 9

        static func frame(in selectionRect: CGRect) -> CGRect {
            guard !selectionRect.isEmpty else { return .zero }

            let availableWidth = max(0, selectionRect.width - inset * 2)
            let availableHeight = max(0, selectionRect.height - inset * 2)
            let width = min(maximumWidth, availableWidth * 0.28)
            let height = min(width / aspectRatio, availableHeight)
            let fittedWidth = min(width, height * aspectRatio)

            guard fittedWidth > 0, height > 0 else { return .zero }

            return CGRect(
                x: selectionRect.maxX - fittedWidth - inset,
                y: selectionRect.minY + inset,
                width: fittedWidth,
                height: height,
            )
        }
    }

    nonisolated enum RecordingCameraPreviewSetupError: Error {
        case noDevice
        case cannotAddInput
    }

    /// Owns the camera session separately from the recording writer so the user can
    /// verify framing before pressing Record. It has no data output: the preview layer
    /// consumes the session directly and the writer creates its own session later.
    final nonisolated class RecordingCameraPreviewSession: @unchecked Sendable {
        let session: AVCaptureSession
        private let sessionQueue = DispatchQueue(
            label: "com.mourato.notinhas.camera.preview",
            qos: .userInteractive,
        )

        init(deviceID: String?) throws {
            let captureSession = AVCaptureSession()
            guard let device = RecordingCameraDeviceProvider.device(matching: deviceID) else {
                throw RecordingCameraPreviewSetupError.noDevice
            }

            let input = try AVCaptureDeviceInput(device: device)
            guard captureSession.canAddInput(input) else {
                throw RecordingCameraPreviewSetupError.cannotAddInput
            }

            if captureSession.canSetSessionPreset(.high) {
                captureSession.sessionPreset = .high
            }
            captureSession.beginConfiguration()
            captureSession.addInput(input)
            captureSession.commitConfiguration()
            session = captureSession
        }

        func start() {
            sessionQueue.async { [session] in
                guard !session.isRunning else { return }
                session.startRunning()
            }
        }

        func stop() {
            sessionQueue.sync { [session] in
                guard session.isRunning else { return }
                session.stopRunning()
            }
        }
    }

    @MainActor
    final class RecordingCameraPreviewWindow: NSPanel {
        let deviceID: String

        private let cameraSession: RecordingCameraPreviewSession
        private let previewLayer: AVCaptureVideoPreviewLayer

        init?(deviceID: String?, selectionRect: CGRect) {
            guard let cameraSession = try? RecordingCameraPreviewSession(deviceID: deviceID) else {
                return nil
            }

            self.deviceID = deviceID ?? RecordingCameraDeviceProvider.systemDefaultID
            self.cameraSession = cameraSession
            previewLayer = AVCaptureVideoPreviewLayer(session: cameraSession.session)

            super.init(
                contentRect: RecordingCameraPreviewPlacement.frame(in: selectionRect),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false,
            )

            configureWindow()

            let previewView = NSView(frame: .zero)
            previewView.wantsLayer = true
            previewView.layer?.cornerRadius = ToolbarConstants.buttonCornerRadius
            previewView.layer?.cornerCurve = .continuous
            previewView.layer?.masksToBounds = true
            previewView.layer?.borderColor = NSColor.white.withAlphaComponent(0.75).cgColor
            previewView.layer?.borderWidth = 1

            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame = previewView.bounds
            previewView.layer?.addSublayer(previewLayer)
            contentView = previewView
            previewLayer.frame = previewView.bounds
        }

        func start() {
            orderFrontRegardless()
            cameraSession.start()
        }

        override func close() {
            cameraSession.stop()
            super.close()
        }

        func updateSelectionRect(_ selectionRect: CGRect) {
            let previewFrame = RecordingCameraPreviewPlacement.frame(in: selectionRect)
            guard !previewFrame.isEmpty else {
                orderOut(nil)
                return
            }

            setFrame(previewFrame, display: true)
            previewLayer.frame = contentView?.bounds ?? .zero
            orderFrontRegardless()
        }

        private func configureWindow() {
            isFloatingPanel = true
            isOpaque = false
            backgroundColor = .clear
            sharingType = .none
            level = .popUpMenu
            ignoresMouseEvents = true
            hasShadow = true
            hidesOnDeactivate = false
            isReleasedWhenClosed = false
            collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            animationBehavior = .none
        }

        override var canBecomeKey: Bool {
            false
        }

        override var canBecomeMain: Bool {
            false
        }
    }
#endif
