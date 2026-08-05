import AppKit
@testable import Notinhas
import XCTest

@MainActor
final class NotinhasImgBBUploadServiceTests: XCTestCase {
    override func tearDown() {
        MockImgBBURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testUploadRejectsMissingAPIKey() async {
        let service = makeService()
        let image = makeTestImage()

        do {
            _ = try await service.upload(image: image, apiKey: " ")
            XCTFail("Expected missing API key error")
        } catch let error as NotinhasImgBBUploadError {
            XCTAssertEqual(error, .missingAPIKey)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testUploadParsesSuccessResponse() async throws {
        let responseJSON = """
        {
          "data": {
            "url": "https://i.ibb.co/example/image.png",
            "display_url": "https://ibb.co/example",
            "delete_url": "https://ibb.co/delete/example"
          },
          "success": true,
          "status": 200
        }
        """
        MockImgBBURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://api.imgbb.com/1/upload")
            XCTAssertEqual(request.httpMethod, "POST")
            let contentType = request.value(forHTTPHeaderField: "Content-Type")
            XCTAssertTrue(contentType?.contains("multipart/form-data") == true)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil,
            )!
            return (response, Data(responseJSON.utf8))
        }

        let service = makeService()
        let image = makeTestImage()
        let result = try await service.upload(image: image, apiKey: "test-api-key")

        XCTAssertEqual(result.link, "https://i.ibb.co/example/image.png")
        XCTAssertEqual(result.deleteURL, "https://ibb.co/delete/example")
    }

    func testUploadMapsAPIError() async {
        let responseJSON = """
        {
          "status_code": 400,
          "error": {
            "message": "Invalid API key",
            "code": 100
          },
          "status_txt": "Bad Request"
        }
        """
        MockImgBBURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 400,
                httpVersion: nil,
                headerFields: nil,
            )!
            return (response, Data(responseJSON.utf8))
        }

        let service = makeService()
        let image = makeTestImage()

        do {
            _ = try await service.upload(image: image, apiKey: "bad-key")
            XCTFail("Expected API error")
        } catch let error as NotinhasImgBBUploadError {
            XCTAssertEqual(error, .apiError("Invalid API key"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func makeService() -> NotinhasImgBBUploadService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockImgBBURLProtocol.self]
        let session = URLSession(configuration: configuration)
        return NotinhasImgBBUploadService(session: session)
    }

    private func makeTestImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 10, height: 10))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 10, height: 10).fill()
        image.unlockFocus()
        return image
    }
}

private final class MockImgBBRequestHandlerState: @unchecked Sendable {
    typealias Handler = (URLRequest) throws -> (HTTPURLResponse, Data)

    private let lock = NSLock()
    private var storedHandler: Handler?

    /// Serializes test setup/teardown with URLProtocol callback reads. The
    /// handler itself is invoked after the lock is released.
    var handler: Handler? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storedHandler
        }
        set {
            lock.lock()
            storedHandler = newValue
            lock.unlock()
        }
    }
}

private final class MockImgBBURLProtocol: URLProtocol {
    private static let handlerState = MockImgBBRequestHandlerState()

    static var requestHandler: MockImgBBRequestHandlerState.Handler? {
        get { handlerState.handler }
        set { handlerState.handler = newValue }
    }

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
