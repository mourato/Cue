import Foundation

enum CueCloudflareConfiguration {
    static let displayName = "Cloudflare"
    static let workerURLKey = "uploads.cloudflare.workerURL"
    static let maximumUploadBytes: Int64 = 95 * 1_048_576

    static func validWorkerURL(_ value: String) -> URL? {
        guard let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme?.lowercased() == "https",
              url.host != nil, url.query == nil, url.fragment == nil else { return nil }
        return url
    }
}

enum CueCloudflareUploadError: LocalizedError, Equatable {
    case missingWorkerURL, missingToken, invalidFile, fileTooLarge, invalidResponse, rejected, transport

    var errorDescription: String? {
        switch self {
        case .missingWorkerURL: CueL10n.cloudflareMissingWorkerURL
        case .missingToken: CueL10n.cloudflareMissingToken
        case .invalidFile: L10n.Cue.invalidImageData
        case .fileTooLarge: L10n.QuickAccess.uploadFileTooLarge
        case .invalidResponse: CueL10n.cloudflareInvalidResponse
        case .rejected: CueL10n.cloudflareUploadFailed
        case .transport: CueL10n.cloudflareOffline
        }
    }
}

enum CueCloudflareConnectionState: Equatable, Sendable {
    case unconfigured
    case verifying
    case connected
    case error
}

struct CueCloudflareUploadResult: Equatable, Sendable { let url: String }

actor CueCloudflareUploadService {
    static let shared = CueCloudflareUploadService()
    private let session: URLSession
    private let progressDelegate: UploadProgressDelegate?

    init(session: URLSession? = nil) {
        let delegate = session == nil ? UploadProgressDelegate() : nil
        progressDelegate = delegate
        self.session = session ?? URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
    }

    func upload(fileURL: URL, workerURL: String, token: String,
                progress: (@Sendable (Double) -> Void)? = nil) async throws -> CueCloudflareUploadResult {
        guard let endpoint = CueCloudflareConfiguration.validWorkerURL(workerURL)
        else { throw CueCloudflareUploadError.missingWorkerURL }
        let token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty
        else { throw CueCloudflareUploadError.missingToken }
        guard let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size > 0 else { throw CueCloudflareUploadError.invalidFile }
        guard Int64(size) <= CueCloudflareConfiguration.maximumUploadBytes
        else { throw CueCloudflareUploadError.fileTooLarge }

        var request = URLRequest(url: endpoint.appendingPathComponent("api/upload"))
        request.httpMethod = "PUT"
        request.timeoutInterval = 300
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(contentType(for: fileURL.pathExtension), forHTTPHeaderField: "Content-Type")
        request.setValue(safeFileName(for: fileURL), forHTTPHeaderField: "X-Filename")
        progress?(0)
        progressDelegate?.setHandler(progress)
        defer { progressDelegate?.setHandler(nil) }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.upload(for: request, fromFile: fileURL)
        } catch is CancellationError { throw CancellationError() }
        catch let error as URLError where error.code == .cancelled { throw CancellationError() }
        catch { throw CueCloudflareUploadError.transport }
        progress?(1)

        guard let http = response as? HTTPURLResponse,
              (200 ... 299).contains(http.statusCode) else { throw CueCloudflareUploadError.rejected }
        guard let result = try? JSONDecoder().decode(Response.self, from: data),
              !result.id.isEmpty, !result.filename.isEmpty, result.size >= 0,
              let url = URL(string: result.url), url.scheme?.lowercased() == "https",
              url.host != nil else {
            throw CueCloudflareUploadError.invalidResponse
        }
        return CueCloudflareUploadResult(url: result.url)
    }

    func verify(workerURL: String, token: String) async throws {
        guard let endpoint = CueCloudflareConfiguration.validWorkerURL(workerURL) else {
            throw CueCloudflareUploadError.missingWorkerURL
        }
        let token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            throw CueCloudflareUploadError.missingToken
        }
        var request = URLRequest(url: endpoint.appendingPathComponent("api/ping"))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
                throw CueCloudflareUploadError.rejected
            }
            guard let result = try? JSONDecoder().decode(PingResponse.self, from: data), result.ok else {
                throw CueCloudflareUploadError.invalidResponse
            }
        } catch let error as CueCloudflareUploadError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw CueCloudflareUploadError.transport
        }
    }

    private struct Response: Decodable {
        let id: String
        let url: String
        let filename: String
        let size: Int64
    }

    private struct PingResponse: Decodable { let ok: Bool }

    private func contentType(for ext: String) -> String {
        switch ext.lowercased() {
        case "gif": "image/gif"
        case "mov": "video/quicktime"
        case "mp4": "video/mp4"
        case "m4v": "video/x-m4v"
        case "jpg", "jpeg": "image/jpeg"
        case "png": "image/png"
        case "webp": "image/webp"
        default: "application/octet-stream"
        }
    }

    private func safeFileName(for url: URL) -> String {
        let name = url.lastPathComponent.replacingOccurrences(
            of: "[^A-Za-z0-9._-]",
            with: "-",
            options: .regularExpression,
        )
        return name.isEmpty ? "upload.bin" : name
    }
}

private final class UploadProgressDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var handler: (@Sendable (Double) -> Void)?

    func setHandler(_ handler: (@Sendable (Double) -> Void)?) {
        lock.lock()
        self.handler = handler
        lock.unlock()
    }

    func urlSession(
        _: URLSession,
        task _: URLSessionTask,
        didSendBodyData _: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64,
    ) {
        guard totalBytesExpectedToSend > 0 else { return }
        lock.lock()
        let handler = handler
        lock.unlock()
        handler?(Double(totalBytesSent) / Double(totalBytesExpectedToSend))
    }
}
