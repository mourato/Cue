import Foundation

enum CueImageKitUploadError: LocalizedError, Equatable {
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
        case .missingPrivateKey: L10n.Cue.imageKitMissingPrivateKey
        case .invalidImageData: L10n.Cue.invalidImageData
        case .unauthorized: L10n.Cue.imageKitUnauthorized
        case .rateLimited: L10n.Cue.imageKitRateLimited
        case .providerRejected: L10n.Cue.imageKitUploadFailed
        case .transport: L10n.Cue.imageKitOffline
        case .malformedResponse, .missingPublicURL: L10n.Cue.imageKitInvalidResponse
        }
    }
}

struct CueImageKitUploadResult: Equatable {
    let url: String
}

actor CueImageKitUploadService {
    static let shared = CueImageKitUploadService()
    private let session: URLSession
    private let endpoint = URL(string: "https://upload.imagekit.io/api/v1/files/upload")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    func upload(image: CueEncodedImage, privateKey: String) async throws -> CueImageKitUploadResult {
        let key = privateKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw CueImageKitUploadError.missingPrivateKey }
        guard !image.data.isEmpty else { throw CueImageKitUploadError.invalidImageData }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(
            "Basic \(Data("\(key):".utf8).base64EncodedString())",
            forHTTPHeaderField: "Authorization",
        )
        let fileName = "\(UUID().uuidString.lowercased()).\(image.fileExtension)"
        request.httpBody = makeMultipartBody(boundary: boundary, image: image, fileName: fileName)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw CueImageKitUploadError.transport
        }

        return try decodeResult(data: data, response: response)
    }

    func upload(fileURL: URL, privateKey: String) async throws -> CueImageKitUploadResult {
        let key = privateKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw CueImageKitUploadError.missingPrivateKey }
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let fileSize = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              fileSize > 0 else {
            throw CueImageKitUploadError.invalidImageData
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        let fileName = "\(UUID().uuidString.lowercased()).\(fileURL.pathExtension.lowercased())"
        let bodyURL: URL
        do {
            bodyURL = try makeMultipartBodyFile(
                boundary: boundary,
                sourceURL: fileURL,
                fileName: fileName,
            )
        } catch let error as CueImageKitUploadError {
            throw error
        } catch {
            throw CueImageKitUploadError.transport
        }
        defer { try? FileManager.default.removeItem(at: bodyURL.deletingLastPathComponent()) }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(
            "Basic \(Data("\(key):".utf8).base64EncodedString())",
            forHTTPHeaderField: "Authorization",
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.upload(for: request, fromFile: bodyURL)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw CueImageKitUploadError.transport
        }

        return try decodeResult(data: data, response: response)
    }

    private struct Response: Decodable {
        let url: String
    }

    private func decodeResult(data: Data, response: URLResponse) throws -> CueImageKitUploadResult {
        guard let http = response as? HTTPURLResponse else {
            throw CueImageKitUploadError.malformedResponse
        }
        switch http.statusCode {
        case 401, 403: throw CueImageKitUploadError.unauthorized
        case 429: throw CueImageKitUploadError.rateLimited
        case 200 ... 299: break
        default: throw CueImageKitUploadError.providerRejected
        }

        guard let result = try? JSONDecoder().decode(Response.self, from: data) else {
            throw CueImageKitUploadError.malformedResponse
        }
        guard let url = URL(string: result.url), url.scheme == "https", !result.url.isEmpty else {
            throw CueImageKitUploadError.missingPublicURL
        }
        return CueImageKitUploadResult(url: result.url)
    }

    private func makeMultipartBodyFile(
        boundary: String,
        sourceURL: URL,
        fileName: String,
    ) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CueImageKitUpload-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let bodyURL = directory.appendingPathComponent("body.multipart")
        guard FileManager.default.createFile(atPath: bodyURL.path, contents: nil) else {
            try? FileManager.default.removeItem(at: directory)
            throw CueImageKitUploadError.transport
        }

        do {
            let output = try FileHandle(forWritingTo: bodyURL)
            let input = try FileHandle(forReadingFrom: sourceURL)
            defer {
                try? input.close()
                try? output.close()
            }

            try output.write(contentsOf: Data(
                "--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\nContent-Type: \(contentType(for: sourceURL.pathExtension))\r\n\r\n"
                    .utf8,
            ))
            while let chunk = try input.read(upToCount: 1_048_576), !chunk.isEmpty {
                try output.write(contentsOf: chunk)
            }
            try output.write(contentsOf: Data(
                "\r\n--\(boundary)\r\nContent-Disposition: form-data; name=\"fileName\"\r\n\r\n\(fileName)\r\n--\(boundary)--\r\n"
                    .utf8,
            ))
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }

        return bodyURL
    }

    private func contentType(for fileExtension: String) -> String {
        switch fileExtension.lowercased() {
        case "mov": "video/quicktime"
        case "mp4": "video/mp4"
        case "m4v": "video/x-m4v"
        default: "application/octet-stream"
        }
    }

    private func makeMultipartBody(boundary: String, image: CueEncodedImage, fileName: String) -> Data {
        var body = Data()
        let lineBreak = "\r\n"
        body.append("--\(boundary)\(lineBreak)")
        body
            .append(
                "Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\(lineBreak)",
            )
        body.append("Content-Type: \(image.contentType)\(lineBreak)\(lineBreak)")
        body.append(image.data)
        body.append(lineBreak)
        body.append("--\(boundary)\(lineBreak)")
        body.append("Content-Disposition: form-data; name=\"fileName\"\(lineBreak)\(lineBreak)")
        body.append("\(fileName)\(lineBreak)")
        body.append("--\(boundary)--\(lineBreak)")
        return body
    }
}

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}
