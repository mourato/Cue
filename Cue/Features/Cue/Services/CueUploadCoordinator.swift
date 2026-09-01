import AppKit
import Combine
import Foundation

@MainActor
final class CueUploadCoordinator: ObservableObject {
    @Published private(set) var isUploading = false
    @Published private(set) var lastUploadedURL: String?
    @Published private(set) var lastErrorMessage: String?

    private let configuration: CueUploadConfigurationStore
    private let imgbbService: CueImgBBUploadService
    private let imageKitService: CueImageKitUploadService

    init(
        configuration: CueUploadConfigurationStore = .shared,
        imgbbService: CueImgBBUploadService = .shared,
        imageKitService: CueImageKitUploadService = .shared,
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

        let settings = CueUploadEncodingSettings.current()
        return await performUpload {
            try await Task.detached(priority: .userInitiated) {
                try CueUploadImageEncoder.encode(image: imageSnapshot, settings: settings)
            }.value
        }
    }

    func upload(fileURL: URL) async -> String? {
        let settings = CueUploadEncodingSettings.current()
        return await performUpload {
            try await Task.detached(priority: .userInitiated) {
                try CueUploadImageEncoder.encode(fileURL: fileURL, settings: settings)
            }.value
        }
    }

    private func performUpload(
        encoding: @escaping @Sendable () async throws -> CueEncodedImage,
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
        } catch let error as CueUploadEncodingError {
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
        L10n.Cue.invalidImageData
    }

    private func missingCredentialMessage(for provider: CueUploadProvider) -> String {
        switch provider {
        case .imgbb: CueL10n.imgbbMissingAPIKey
        case .imageKit: L10n.Cue.imageKitMissingPrivateKey
        }
    }
}
