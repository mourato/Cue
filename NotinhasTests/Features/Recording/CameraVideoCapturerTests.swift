#if NOTINHAS_VIDEO_MODULE
    import AVFoundation
    @testable import Notinhas
    import XCTest

    final class CameraVideoCapturerTests: XCTestCase {
        func testDeniedCameraDoesNotStartSession() {
            let factory = FakeCameraFactory(status: .denied)
            let capturer = CameraVideoCapturer(factory: factory)
            capturer.start()
            let stopped = expectation(description: "camera setup completes")
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { stopped.fulfill() }
            wait(for: [stopped], timeout: 1)
            XCTAssertFalse(factory.session.started)
            capturer.stop()
            capturer.stop()
        }
    }

    private final class FakeCameraSession: CameraCaptureSession {
        var started = false
        func canAddInput(_: AVCaptureInput) -> Bool {
            true
        }

        func addInput(_: AVCaptureInput) {}
        func canAddOutput(_: AVCaptureOutput) -> Bool {
            true
        }

        func addOutput(_: AVCaptureOutput) {}
        func startRunning() {
            started = true
        }

        func stopRunning() {
            started = false
        }
    }

    private struct FakeCameraFactory: CameraCaptureSessionFactory {
        let status: AVAuthorizationStatus
        let session = FakeCameraSession()
        func authorizationStatus() -> AVAuthorizationStatus {
            status
        }

        func makeSession() -> CameraCaptureSession {
            session
        }

        func configureInput(on _: CameraCaptureSession, preferredDeviceID _: String?) throws -> String {
            "Fake Camera"
        }

        func configureOutput(
            on _: CameraCaptureSession,
            delegate _: AVCaptureVideoDataOutputSampleBufferDelegate,
            queue _: DispatchQueue,
        ) throws {}
    }
#endif
