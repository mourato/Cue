@testable import Cue
import XCTest

@MainActor
final class CueImgBBUploadServiceTests: XCTestCase {
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
        } catch let error as CueImgBBUploadError {
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
        let image = makeTestImage()
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
        let result = try await service.upload(image: image, apiKey: "test-api-key")

        XCTAssertEqual(result.link, "https://i.ibb.co/example/image.png")
        XCTAssertEqual(result.deleteURL, "https://ibb.co/delete/example")
    }

    func testUploadPreservesGIFContentTypeAndPayload() async throws {
        let gifData = Data("GIF89a-animation-fixture".utf8)
        MockImgBBURLProtocol.requestHandler = { request in
            let body = Self.requestBodyData(request)
            XCTAssertTrue(String(data: body, encoding: .utf8)?.contains("Content-Type: image/gif") == true)
            XCTAssertTrue(body.range(of: gifData) != nil)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil,
            )!
            return (response, Data(#"{"data":{"url":"https://i.ibb.co/example/animation.gif"}}"#.utf8))
        }

        let result = try await makeService().upload(
            image: CueEncodedImage(data: gifData, fileExtension: "gif", contentType: "image/gif"),
            apiKey: "test-api-key",
        )

        XCTAssertEqual(result.link, "https://i.ibb.co/example/animation.gif")
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
        } catch let error as CueImgBBUploadError {
            XCTAssertEqual(error, .apiError("Invalid API key"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func makeService() -> CueImgBBUploadService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockImgBBURLProtocol.self]
        let session = URLSession(configuration: configuration)
        return CueImgBBUploadService(session: session)
    }

    private func makeTestImage() -> CueEncodedImage {
        CueEncodedImage(data: Data("image-payload".utf8), fileExtension: "webp", contentType: "image/webp")
    }

    private static func requestBodyData(_ request: URLRequest) -> Data {
        if let httpBody = request.httpBody {
            return httpBody
        }

        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
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
