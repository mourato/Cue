#if NOTINHAS_VIDEO_MODULE
    import AVFoundation
    import CoreMedia
    import Foundation

    nonisolated protocol CameraVideoCapturerDelegate: AnyObject {
        func cameraCapturer(_ capturer: CameraVideoCapturer, didOutput sampleBuffer: CMSampleBuffer)
        func cameraCapturerDidBecomeUnavailable(_ capturer: CameraVideoCapturer)
    }

    nonisolated protocol CameraCaptureSession: AnyObject {
        func canAddInput(_ input: AVCaptureInput) -> Bool
        func addInput(_ input: AVCaptureInput)
        func canAddOutput(_ output: AVCaptureOutput) -> Bool
        func addOutput(_ output: AVCaptureOutput)
        func startRunning()
        func stopRunning()
    }

    final nonisolated class AVFoundationCameraCaptureSession: CameraCaptureSession {
        let session = AVCaptureSession()
        func canAddInput(_ input: AVCaptureInput) -> Bool {
            session.canAddInput(input)
        }

        func addInput(_ input: AVCaptureInput) {
            session.addInput(input)
        }

        func canAddOutput(_ output: AVCaptureOutput) -> Bool {
            session.canAddOutput(output)
        }

        func addOutput(_ output: AVCaptureOutput) {
            session.addOutput(output)
        }

        func startRunning() {
            session.startRunning()
        }

        func stopRunning() {
            session.stopRunning()
        }
    }

    nonisolated enum CameraCaptureSetupError: Error {
        case noDevice, cannotAddInput, cannotAddOutput, unsupportedFormat
    }

    nonisolated protocol CameraCaptureSessionFactory {
        func authorizationStatus() -> AVAuthorizationStatus
        func makeSession() -> CameraCaptureSession
        func configureInput(on session: CameraCaptureSession, preferredDeviceID: String?) throws -> String
        func configureOutput(
            on session: CameraCaptureSession,
            delegate: AVCaptureVideoDataOutputSampleBufferDelegate,
            queue: DispatchQueue,
        ) throws
    }

    nonisolated enum RecordingCameraDeviceProvider {
        static let systemDefaultID = "system-default"

        static func devices() -> [AVCaptureDevice] {
            AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
                mediaType: .video,
                position: .unspecified,
            ).devices.sorted { $0.localizedName.localizedCaseInsensitiveCompare($1.localizedName) == .orderedAscending }
        }

        static func device(matching id: String?) -> AVCaptureDevice? {
            if let id, id != systemDefaultID,
               let device = devices().first(where: { $0.uniqueID == id }) {
                return device
            }
            return devices().first
        }
    }

    nonisolated struct AVFoundationCameraCaptureSessionFactory: CameraCaptureSessionFactory {
        func authorizationStatus() -> AVAuthorizationStatus {
            AVCaptureDevice.authorizationStatus(for: .video)
        }

        func makeSession() -> CameraCaptureSession {
            AVFoundationCameraCaptureSession()
        }

        func configureInput(on session: CameraCaptureSession, preferredDeviceID: String?) throws -> String {
            guard let device = RecordingCameraDeviceProvider.device(matching: preferredDeviceID)
            else { throw CameraCaptureSetupError.noDevice }
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else { throw CameraCaptureSetupError.cannotAddInput }
            session.addInput(input)
            return device.localizedName
        }

        func configureOutput(
            on session: CameraCaptureSession,
            delegate: AVCaptureVideoDataOutputSampleBufferDelegate,
            queue: DispatchQueue,
        ) throws {
            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(delegate, queue: queue)
            guard session.canAddOutput(output) else { throw CameraCaptureSetupError.cannotAddOutput }
            session.addOutput(output)
        }
    }

    final nonisolated class CameraVideoCapturer: NSObject, @unchecked Sendable {
        weak var delegate: CameraVideoCapturerDelegate?
        private let factory: CameraCaptureSessionFactory
        private let preferredDeviceID: String?
        private var captureSession: CameraCaptureSession?
        private var isRunning = false
        private let sessionQueue = DispatchQueue(label: "com.mourato.notinhas.camera.session", qos: .userInteractive)
        private let dataOutputQueue = DispatchQueue(label: "com.mourato.notinhas.camera.data", qos: .userInteractive)

        init(
            preferredDeviceID: String? = nil,
            factory: CameraCaptureSessionFactory = AVFoundationCameraCaptureSessionFactory(),
        ) {
            self.preferredDeviceID = preferredDeviceID
            self.factory = factory
            super.init()
        }

        var running: Bool {
            sessionQueue.sync { isRunning }
        }

        func start() {
            sessionQueue.async { [weak self] in
                guard let self, !isRunning else { return }
                isRunning = true
                guard factory.authorizationStatus() == .authorized else { fail()
                    return
                }
                let session = factory.makeSession()
                captureSession = session
                do {
                    _ = try factory.configureInput(on: session, preferredDeviceID: preferredDeviceID)
                    try factory.configureOutput(on: session, delegate: self, queue: dataOutputQueue)
                    session.startRunning()
                } catch { fail() }
            }
        }

        func stop() {
            sessionQueue.async { [weak self] in
                guard let self, isRunning || captureSession != nil else { return }
                isRunning = false
                captureSession?.stopRunning()
                captureSession = nil
            }
        }

        private func fail() {
            isRunning = false
            captureSession?.stopRunning()
            captureSession = nil
            delegate?.cameraCapturerDidBecomeUnavailable(self)
        }
    }

    nonisolated extension CameraVideoCapturer: AVCaptureVideoDataOutputSampleBufferDelegate {
        func captureOutput(_: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from _: AVCaptureConnection) {
            guard sampleBuffer.isValid else { return }
            delegate?.cameraCapturer(self, didOutput: sampleBuffer)
        }
    }
#endif
