import AppKit
import Combine
import Foundation

@MainActor
final class CueUploadCoordinator: ObservableObject {
    @Published private(set) var isUploading = false
    @Published private(set) var uploadProgress: Double?
    @Published private(set) var lastUploadedURL: String?
    @Published private(set) var lastErrorMessage: String?

    private let configuration: CueUploadConfigurationStore
    private let imgbbService: CueImgBBUploadService
    private let imageKitService: CueImageKitUploadService
    private let cloudflareService: CueCloudflareUploadService

    init(
        configuration: CueUploadConfigurationStore = .shared,
        imgbbService: CueImgBBUploadService = .shared,
        imageKitService: CueImageKitUploadService = .shared,
        cloudflareService: CueCloudflareUploadService = .shared,
    ) {
        self.configuration = configuration
        self.imgbbService = imgbbService
        self.imageKitService = imageKitService
        self.cloudflareService = cloudflareService
    }

    func upload(finalImage: NSImage) async -> String? {
        guard let imageSnapshot = finalImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            lastErrorMessage = invalidImageMessage
            return nil
        }

        let settings = CueUploadEncodingSettings.current()
        return await performUpload(mediaKind: .image) {
            try await Task.detached(priority: .userInitiated) {
                try CueUploadImageEncoder.encode(image: imageSnapshot, settings: settings)
            }.value
        }
    }

    func upload(fileURL: URL, videoSettings: CueVideoUploadSettings? = nil) async -> String? {
        let mediaKind = CueUploadMediaKind(fileExtension: fileURL.pathExtension)
        if mediaKind == .video {
            return await performVideoUpload(fileURL: fileURL, settings: videoSettings)
        }

        let settings = CueUploadEncodingSettings.current()
        return await performUpload(mediaKind: mediaKind) {
            try await Task.detached(priority: .userInitiated) {
                try CueUploadImageEncoder.encode(fileURL: fileURL, settings: settings)
            }.value
        }
    }

    private func performVideoUpload(fileURL: URL, settings: CueVideoUploadSettings?) async -> String? {
        let provider = configuration.provider
        guard provider.supports(.video) else {
            lastErrorMessage = L10n.QuickAccess.videoUploadRequiresProvider
            return nil
        }
        guard let credential = configuration.credential else {
            lastErrorMessage = missingCredentialMessage(for: provider)
            return nil
        }

        isUploading = true
        uploadProgress = provider == .cloudflare ? 0 : nil
        lastErrorMessage = nil
        defer {
            isUploading = false
            uploadProgress = nil
        }

        do {
            let prepared: CuePreparedUpload
            if let settings {
                prepared = try await CueVideoUploadTranscoder.prepare(
                    sourceURL: fileURL,
                    maximumBytes: provider == .cloudflare ? CueCloudflareConfiguration
                        .maximumUploadBytes : configuration.imageKitVideoUploadTargetBytes,
                    settings: settings,
                )
            } else {
                let fileSize = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                let maximumBytes = provider == .cloudflare ? CueCloudflareConfiguration
                    .maximumUploadBytes : configuration.imageKitVideoUploadTargetBytes
                guard Int64(fileSize) <= maximumBytes else {
                    throw CueUploadEncodingError.fileTooLarge
                }
                prepared = .original(fileURL)
            }
            defer { prepared.cleanup() }

            let link: String = switch provider {
            case .imageKit:
                try await imageKitService.upload(fileURL: prepared.url, privateKey: credential).url
            case .cloudflare:
                try await cloudflareService.upload(
                    fileURL: prepared.url,
                    workerURL: configuration.cloudflareWorkerURL,
                    token: credential,
                    progress: { [weak self] value in
                        Task { @MainActor in self?.uploadProgress = value }
                    },
                ).url
            case .imgbb:
                throw CueCloudflareUploadError.rejected
            }
            lastUploadedURL = link
            return link
        } catch is CancellationError {
            return nil
        } catch let error as CueUploadEncodingError {
            switch error {
            case .fileTooLarge:
                lastErrorMessage = L10n.QuickAccess.uploadFileTooLarge
            case .videoTranscodingFailed, .videoCouldNotFitLimit:
                lastErrorMessage = L10n.QuickAccess.videoUploadOptimizationFailed
            default:
                lastErrorMessage = error.localizedDescription
            }
            return nil
        } catch {
            lastErrorMessage = error.localizedDescription
            return nil
        }
    }

    private func performUpload(
        mediaKind: CueUploadMediaKind,
        encoding: @escaping @Sendable () async throws -> CueEncodedImage,
    ) async -> String? {
        let provider = configuration.provider
        guard provider.supports(mediaKind) else {
            lastErrorMessage = L10n.QuickAccess.videoUploadRequiresProvider
            return nil
        }
        guard let credential = configuration.credential else {
            lastErrorMessage = missingCredentialMessage(for: provider)
            return nil
        }
        isUploading = true
        uploadProgress = provider == .cloudflare ? 0 : nil
        lastErrorMessage = nil
        defer {
            isUploading = false
            uploadProgress = nil
        }

        do {
            let encodedImage = try await encoding()
            let link: String = switch provider {
            case .imgbb:
                try await imgbbService.upload(image: encodedImage, apiKey: credential).link
            case .imageKit:
                try await imageKitService.upload(image: encodedImage, privateKey: credential).url
            case .cloudflare:
                try await uploadCloudflareImage(encodedImage, token: credential) { [weak self] value in
                    Task { @MainActor in self?.uploadProgress = value }
                }.url
            }
            lastUploadedURL = link
            return link
        } catch let error as CueUploadEncodingError {
            if case .invalidImageData = error {
                lastErrorMessage = invalidImageMessage
            } else if case .fileTooLarge = error {
                lastErrorMessage = L10n.QuickAccess.uploadFileTooLarge
            } else {
                lastErrorMessage = error.localizedDescription
            }
            return nil
        } catch is CancellationError {
            return nil
        } catch {
            lastErrorMessage = error.localizedDescription
            return nil
        }
    }

    private func uploadCloudflareImage(_ image: CueEncodedImage,
                                       token: String,
                                       progress: (@Sendable (Double) -> Void)? = nil) async throws
        -> CueCloudflareUploadResult {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "CueCloudflareUpload-\(UUID().uuidString)",
            isDirectory: true,
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("upload.\(image.fileExtension)")
        defer { try? FileManager.default.removeItem(at: directory) }
        try image.data.write(to: fileURL, options: .atomic)
        return try await cloudflareService.upload(
            fileURL: fileURL,
            workerURL: configuration.cloudflareWorkerURL,
            token: token,
            progress: progress,
        )
    }

    private var invalidImageMessage: String {
        L10n.Cue.invalidImageData
    }

    private func missingCredentialMessage(for provider: CueUploadProvider) -> String {
        switch provider {
        case .imgbb: CueL10n.imgbbMissingAPIKey
        case .imageKit: L10n.Cue.imageKitMissingPrivateKey
        case .cloudflare: CueL10n.cloudflareMissingToken
        }
    }
}
