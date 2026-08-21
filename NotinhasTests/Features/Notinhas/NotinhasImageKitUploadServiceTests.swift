@testable import Notinhas
import XCTest

@MainActor
final class NotinhasImageKitUploadServiceTests: XCTestCase {
    override func tearDown() {
        MockImageKitURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testUploadSendsMultipartAndParsesURL() async throws {
        MockImageKitURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://upload.imagekit.io/api/v1/files/upload")
            XCTAssertEqual(request.httpMethod, "POST")
            let expectedAuthorization = "Basic \(Data("fixture-private-key:".utf8).base64EncodedString())"
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), expectedAuthorization)
            let body = String(data: Self.requestBodyData(request), encoding: .utf8) ?? ""
            XCTAssertTrue(body.contains("name=\"file\""))
            XCTAssertTrue(body.contains("name=\"fileName\""))
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"url":"https://ik.imagekit.io/demo/notinhas.webp"}"#.utf8))
        }

        let result = try await makeService().upload(image: makeImage(), privateKey: "fixture-private-key")
        XCTAssertEqual(result.url, "https://ik.imagekit.io/demo/notinhas.webp")
    }

    func testUnauthorizedResponseDoesNotExposeCredential() async {
        MockImageKitURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data("private-key must not appear".utf8))
        }

        do {
            _ = try await makeService().upload(image: makeImage(), privateKey: "fixture-private-key")
            XCTFail("Expected authorization error")
        } catch let error as NotinhasImageKitUploadError {
            XCTAssertEqual(error, .unauthorized)
            XCTAssertFalse(error.localizedDescription.contains("fixture-private-key"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testMissingCredentialDoesNotSendRequest() async {
        do {
            _ = try await makeService().upload(image: makeImage(), privateKey: " ")
            XCTFail("Expected missing credential error")
        } catch let error as NotinhasImageKitUploadError {
            XCTAssertEqual(error, .missingPrivateKey)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func makeService() -> NotinhasImageKitUploadService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockImageKitURLProtocol.self]
        return NotinhasImageKitUploadService(session: URLSession(configuration: configuration))
    }

    private func makeImage() -> NotinhasEncodedImage {
        NotinhasEncodedImage(data: Data("image-payload".utf8), fileExtension: "webp", contentType: "image/webp")
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

private final class MockImageKitURLProtocol: URLProtocol {
    typealias Handler = (URLRequest) throws -> (HTTPURLResponse, Data)
    private static let state = HandlerState()

    static var requestHandler: Handler? {
        get { state.handler }
        set { state.handler = newValue }
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

private final class HandlerState: @unchecked Sendable {
    private let lock = NSLock()
    private var storedHandler: MockImageKitURLProtocol.Handler?

    var handler: MockImageKitURLProtocol.Handler? {
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
