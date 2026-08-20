import AppKit
import Combine
import Foundation

@MainActor
final class NotinhasUploadCoordinator: ObservableObject {
    @Published private(set) var isUploading = false
    @Published private(set) var lastUploadedURL: String?
    @Published private(set) var lastErrorMessage: String?

    private let configuration: NotinhasUploadConfigurationStore
    private let imgbbService: NotinhasImgBBUploadService
    private let imageKitService: NotinhasImageKitUploadService

    init(
        configuration: NotinhasUploadConfigurationStore = .shared,
        imgbbService: NotinhasImgBBUploadService = .shared,
        imageKitService: NotinhasImageKitUploadService = .shared,
    ) {
        self.configuration = configuration
        self.imgbbService = imgbbService
        self.imageKitService = imageKitService
    }

    func upload(finalImage: NSImage) async -> String? {
        guard let imageSnapshot = finalImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            lastErrorMessage = invalidImageMessage
            return nil
        }

        let settings = NotinhasUploadEncodingSettings.current()
        return await performUpload {
            try await Task.detached(priority: .userInitiated) {
                try NotinhasUploadImageEncoder.encode(image: imageSnapshot, settings: settings)
            }.value
        }
    }

    func upload(fileURL: URL) async -> String? {
        let settings = NotinhasUploadEncodingSettings.current()
        return await performUpload {
            try await Task.detached(priority: .userInitiated) {
                try NotinhasUploadImageEncoder.encode(fileURL: fileURL, settings: settings)
            }.value
        }
    }

    private func performUpload(
        encoding: @escaping @Sendable () async throws -> NotinhasEncodedImage,
    ) async -> String? {
        let provider = configuration.provider
        guard let credential = configuration.credential else {
            lastErrorMessage = missingCredentialMessage(for: provider)
            return nil
        }
        isUploading = true
        lastErrorMessage = nil
        defer { isUploading = false }

        do {
            let encodedImage = try await encoding()
            let link: String = switch provider {
            case .imgbb:
                try await imgbbService.upload(image: encodedImage, apiKey: credential).link
            case .imageKit:
                try await imageKitService.upload(image: encodedImage, privateKey: credential).url
            }
            lastUploadedURL = link
            return link
        } catch let error as NotinhasUploadEncodingError {
            if case .invalidImageData = error {
                lastErrorMessage = invalidImageMessage
            } else {
                lastErrorMessage = error.localizedDescription
            }
            return nil
        } catch {
            lastErrorMessage = error.localizedDescription
            return nil
        }
    }

    private var invalidImageMessage: String {
        NotinhasL10n.imgbbInvalidImageData
    }

    private func missingCredentialMessage(for provider: NotinhasUploadProvider) -> String {
        switch provider {
        case .imgbb: NotinhasL10n.imgbbMissingAPIKey
        case .imageKit: L10n.Notinhas.imageKitMissingPrivateKey
        }
    }
}
