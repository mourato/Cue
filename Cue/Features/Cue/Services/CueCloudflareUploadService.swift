import Combine
import Foundation

enum CueCloudflareConfiguration {
    static let displayName = "Cloudflare Worker"
    static let workerURLKey = "uploads.cloudflare.workerURL"
    static let maximumUploadBytes: Int64 = 95 * 1_048_576

    static func validWorkerURL(_ value: String) -> URL? {
        guard let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              ["https", "http"].contains(url.scheme?.lowercased()),
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

struct CueCloudflareUploadResult: Equatable, Sendable { let url: String }

actor CueCloudflareUploadService {
    static let shared = CueCloudflareUploadService()
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func upload(fileURL: URL, workerURL: String, token: String,
                progress: (@Sendable (Double) -> Void)? = nil) async throws -> CueCloudflareUploadResult {
        guard let endpoint = CueCloudflareConfiguration.validWorkerURL(workerURL)
        else { throw CueCloudflareUploadError.missingWorkerURL }
        guard !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { throw CueCloudflareUploadError.missingToken }
        guard let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size > 0 else { throw CueCloudflareUploadError.invalidFile }
        guard Int64(size) <= CueCloudflareConfiguration.maximumUploadBytes
        else { throw CueCloudflareUploadError.fileTooLarge }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(contentType(for: fileURL.pathExtension), forHTTPHeaderField: "Content-Type")
        request.setValue(safeFileName(for: fileURL), forHTTPHeaderField: "X-Filename")
        progress?(0)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.upload(for: request, fromFile: fileURL)
        } catch is CancellationError { throw CancellationError() } catch { throw CueCloudflareUploadError.transport }
        progress?(1)

        guard let http = response as? HTTPURLResponse,
              (200 ... 299).contains(http.statusCode) else { throw CueCloudflareUploadError.rejected }
        guard let result = try? JSONDecoder().decode(Response.self, from: data),
              let url = URL(string: result.url), ["https", "http"].contains(url.scheme?.lowercased()),
              url.host != nil else {
            throw CueCloudflareUploadError.invalidResponse
        }
        return CueCloudflareUploadResult(url: result.url)
    }

    private struct Response: Decodable { let url: String }

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

@MainActor
final class CueCloudflareCredentialStore: ObservableObject {
    static let shared = CueCloudflareCredentialStore()
    @Published private(set) var isConfigured = false
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        reload()
    }

    var token: String? {
        guard case let .success(value) = CloudKeychainStore.readCloudflareToken(context: "cloudflare-token-read")
        else { return nil }
        return value
    }

    var maskedToken: String {
        token.map { String(repeating: "•", count: max(4, $0.count - 4)) + $0.suffix(4) } ?? ""
    }

    func reload() {
        isConfigured = defaults.bool(forKey: CueCloudflareConfiguration.workerURLKey + ".configured") ||
            CloudKeychainStore.probeCloudflareToken(context: "cloudflare-token-presence") == .present
    }

    func save(token: String) throws {
        let value = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw CueCloudflareUploadError.missingToken }
        try CloudKeychainStore.upsertCloudflareToken(value)
        defaults.set(true, forKey: CueCloudflareConfiguration.workerURLKey + ".configured")
        isConfigured = true
    }

    func clear() {
        CloudKeychainStore.deleteCloudflareToken()
        defaults.set(false, forKey: CueCloudflareConfiguration.workerURLKey + ".configured")
        isConfigured = false
    }
}
