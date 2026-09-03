@testable import Cue
import XCTest

@MainActor
final class CueCloudflareUploadServiceTests: XCTestCase {
    override func tearDown() {
        MockCloudflareURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testUploadUsesWorkerContractAndReportsResult() async throws {
        MockCloudflareURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://worker.example/api/upload")
            XCTAssertEqual(request.httpMethod, "PUT")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer fixture-token")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "video/mp4")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Filename"), "capture.mp4")
            XCTAssertEqual(Self.body(for: request), Data("payload".utf8))
            return Self.response(
                status: 201,
                body: #"{"id":"abc123","url":"https://worker.example/abc123","filename":"capture.mp4","size":7}"#,
            )
        }

        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("capture.mp4")
        try Data("payload".utf8).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let result = try await makeService().upload(
            fileURL: fileURL,
            workerURL: " https://worker.example/ ",
            token: " fixture-token ",
        )

        XCTAssertEqual(result.url, "https://worker.example/abc123")
    }

    func testUploadRejectsHTTPWorkerAndHTTPResponseURL() async {
        do {
            _ = try await makeService().upload(
                fileURL: temporaryFile(),
                workerURL: "http://worker.example",
                token: "fixture-token",
            )
            XCTFail("Expected HTTPS validation")
        } catch let error as CueCloudflareUploadError {
            XCTAssertEqual(error, .missingWorkerURL)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testUnauthorizedResponseDoesNotExposeToken() async {
        MockCloudflareURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer fixture-token")
            return Self.response(status: 401, body: "fixture-token must not appear in errors")
        }

        do {
            _ = try await makeService().upload(
                fileURL: temporaryFile(),
                workerURL: "https://worker.example",
                token: "fixture-token",
            )
            XCTFail("Expected rejection")
        } catch let error as CueCloudflareUploadError {
            XCTAssertEqual(error, .rejected)
            XCTAssertFalse(error.localizedDescription.contains("fixture-token"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func makeService() -> CueCloudflareUploadService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockCloudflareURLProtocol.self]
        return CueCloudflareUploadService(session: URLSession(configuration: configuration))
    }

    private func temporaryFile() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("fixture.mp4")
        try? Data("fixture".utf8).write(to: url)
        return url
    }

    private static func body(for request: URLRequest) -> Data {
        guard let stream = request.httpBodyStream else { return request.httpBody ?? Data() }
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

    private static func response(status: Int, body: String) -> (HTTPURLResponse, Data) {
        (
            HTTPURLResponse(url: URL(string: "https://worker.example")!, statusCode: status, httpVersion: nil,
                            headerFields: nil)!,
            Data(body.utf8),
        )
    }
}

private final class MockCloudflareURLProtocol: URLProtocol {
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
    private var storedHandler: MockCloudflareURLProtocol.Handler?

    var handler: MockCloudflareURLProtocol.Handler? {
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
