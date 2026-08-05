import AppKit
import Foundation

enum NotinhasImgBBUploadError: LocalizedError, Equatable {
    case missingAPIKey
    case invalidImageData
    case invalidResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            NotinhasL10n.imgbbMissingAPIKey
        case .invalidImageData:
            NotinhasL10n.imgbbInvalidImageData
        case .invalidResponse:
            NotinhasL10n.imgbbInvalidResponse
        case let .apiError(message):
            message
        }
    }
}

struct NotinhasImgBBUploadResult: Equatable {
    let link: String
    let deleteURL: String?
}

actor NotinhasImgBBUploadService {
    static let shared = NotinhasImgBBUploadService()

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func upload(image: NSImage, apiKey: String) async throws -> NotinhasImgBBUploadResult {
        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAPIKey.isEmpty else {
            throw NotinhasImgBBUploadError.missingAPIKey
        }

        guard let pngData = image.pngData() else {
            throw NotinhasImgBBUploadError.invalidImageData
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: URL(string: "https://api.imgbb.com/1/upload")!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = makeMultipartBody(
            boundary: boundary,
            apiKey: trimmedAPIKey,
            base64Image: pngData.base64EncodedString(),
        )

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NotinhasImgBBUploadError.invalidResponse
        }

        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        if !(200 ... 299).contains(http.statusCode) {
            let message = parseErrorMessage(from: json)
                ?? String(data: data, encoding: .utf8)
                ?? NotinhasL10n.imgbbInvalidResponse
            throw NotinhasImgBBUploadError.apiError(message)
        }

        guard let result = parseSuccessResult(from: json) else {
            throw NotinhasImgBBUploadError.invalidResponse
        }

        return result
    }

    private func makeMultipartBody(boundary: String, apiKey: String, base64Image: String) -> Data {
        var body = Data()
        let lineBreak = "\r\n"

        body.append("--\(boundary)\(lineBreak)")
        body.append("Content-Disposition: form-data; name=\"key\"\(lineBreak)\(lineBreak)")
        body.append("\(apiKey)\(lineBreak)")

        body.append("--\(boundary)\(lineBreak)")
        body.append("Content-Disposition: form-data; name=\"image\"\(lineBreak)\(lineBreak)")
        body.append("\(base64Image)\(lineBreak)")

        body.append("--\(boundary)--\(lineBreak)")
        return body
    }

    private func parseSuccessResult(from json: [String: Any]?) -> NotinhasImgBBUploadResult? {
        guard let dataObject = json?["data"] as? [String: Any] else { return nil }
        let link = (dataObject["url"] as? String) ?? (dataObject["display_url"] as? String)
        guard let link else { return nil }
        return NotinhasImgBBUploadResult(
            link: link,
            deleteURL: dataObject["delete_url"] as? String,
        )
    }

    private func parseErrorMessage(from json: [String: Any]?) -> String? {
        if let errorObject = json?["error"] as? [String: Any],
           let message = errorObject["message"] as? String {
            return message
        }
        return json?["status_txt"] as? String
    }
}

private extension Data {
    mutating func append(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        append(data)
    }
}

private extension NSImage {
    func pngData() -> Data? {
        guard let tiff = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }
}
