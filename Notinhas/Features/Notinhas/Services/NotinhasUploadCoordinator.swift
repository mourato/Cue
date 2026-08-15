import AppKit
import Combine
import Foundation

@MainActor
final class NotinhasUploadCoordinator: ObservableObject {
    @Published private(set) var isUploading = false
    @Published private(set) var lastUploadedURL: String?
    @Published private(set) var lastErrorMessage: String?

    private let uploadService: NotinhasImgBBUploadService

    init(uploadService: NotinhasImgBBUploadService = .shared) {
        self.uploadService = uploadService
    }

    func upload(finalImage: NSImage, apiKey: String) async -> String? {
        guard let imageSnapshot = finalImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            lastErrorMessage = NotinhasL10n.imgbbInvalidImageData
            return nil
        }

        let settings = NotinhasUploadEncodingSettings.current()
        return await performUpload(apiKey: apiKey) {
            try await Task.detached(priority: .userInitiated) {
                try NotinhasUploadImageEncoder.encode(image: imageSnapshot, settings: settings)
            }.value
        }
    }

    func upload(fileURL: URL, apiKey: String) async -> String? {
        let settings = NotinhasUploadEncodingSettings.current()
        return await performUpload(apiKey: apiKey) {
            try await Task.detached(priority: .userInitiated) {
                try NotinhasUploadImageEncoder.encode(fileURL: fileURL, settings: settings)
            }.value
        }
    }

    private func performUpload(
        apiKey: String,
        encoding: @escaping @Sendable () async throws -> NotinhasEncodedImage,
    ) async -> String? {
        isUploading = true
        lastErrorMessage = nil
        defer { isUploading = false }

        do {
            let encodedImage = try await encoding()
            let result = try await uploadService.upload(image: encodedImage, apiKey: apiKey)
            lastUploadedURL = result.link
            return result.link
        } catch let error as NotinhasUploadEncodingError {
            if case .invalidImageData = error {
                lastErrorMessage = NotinhasL10n.imgbbInvalidImageData
            } else {
                lastErrorMessage = error.localizedDescription
            }
            return nil
        } catch {
            lastErrorMessage = error.localizedDescription
            return nil
        }
    }
}
