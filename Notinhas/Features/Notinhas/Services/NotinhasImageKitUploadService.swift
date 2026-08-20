import Foundation

enum NotinhasImageKitUploadError: LocalizedError, Equatable {
    case missingPrivateKey
    case invalidImageData
    case unauthorized
    case rateLimited
    case providerRejected
    case transport
    case malformedResponse
    case missingPublicURL

    var errorDescription: String? {
        switch self {
        case .missingPrivateKey: L10n.Notinhas.imageKitMissingPrivateKey
        case .invalidImageData: NotinhasL10n.imgbbInvalidImageData
        case .unauthorized: L10n.Notinhas.imageKitUnauthorized
        case .rateLimited: L10n.Notinhas.imageKitRateLimited
        case .providerRejected: L10n.Notinhas.imageKitUploadFailed
        case .transport: L10n.Notinhas.imageKitOffline
        case .malformedResponse, .missingPublicURL: L10n.Notinhas.imageKitInvalidResponse
        }
    }
}

struct NotinhasImageKitUploadResult: Equatable {
    let url: String
}

actor NotinhasImageKitUploadService {
    static let shared = NotinhasImageKitUploadService()
    private let session: URLSession
    private let endpoint = URL(string: "https://upload.imagekit.io/api/v1/files/upload")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    func upload(image: NotinhasEncodedImage, privateKey: String) async throws -> NotinhasImageKitUploadResult {
        let key = privateKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw NotinhasImageKitUploadError.missingPrivateKey }
        guard !image.data.isEmpty else { throw NotinhasImageKitUploadError.invalidImageData }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(
            Data("\(key):".utf8).base64EncodedString(),
            forHTTPHeaderField: "Authorization",
        )
        request.httpBody = makeMultipartBody(boundary: boundary, image: image)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw NotinhasImageKitUploadError.transport
        }

        guard let http = response as? HTTPURLResponse else {
            throw NotinhasImageKitUploadError.malformedResponse
        }
        switch http.statusCode {
        case 401, 403: throw NotinhasImageKitUploadError.unauthorized
        case 429: throw NotinhasImageKitUploadError.rateLimited
        case 200 ... 299: break
        default: throw NotinhasImageKitUploadError.providerRejected
        }

        guard let result = try? JSONDecoder().decode(Response.self, from: data) else {
            throw NotinhasImageKitUploadError.malformedResponse
        }
        guard let url = URL(string: result.url), url.scheme == "https", !result.url.isEmpty else {
            throw NotinhasImageKitUploadError.missingPublicURL
        }
        return NotinhasImageKitUploadResult(url: result.url)
    }

    private struct Response: Decodable {
        let url: String
    }

    private func makeMultipartBody(boundary: String, image: NotinhasEncodedImage) -> Data {
        var body = Data()
        let lineBreak = "\r\n"
        body.append("--\(boundary)\(lineBreak)")
        body
            .append(
                "Content-Disposition: form-data; name=\"file\"; filename=\"notinhas.\(image.fileExtension)\"\(lineBreak)",
            )
        body.append("Content-Type: \(image.contentType)\(lineBreak)\(lineBreak)")
        body.append(image.data)
        body.append(lineBreak)
        body.append("--\(boundary)\(lineBreak)")
        body.append("Content-Disposition: form-data; name=\"fileName\"\(lineBreak)\(lineBreak)")
        body.append("notinhas.\(image.fileExtension)\(lineBreak)")
        body.append("--\(boundary)--\(lineBreak)")
        return body
    }
}

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}
