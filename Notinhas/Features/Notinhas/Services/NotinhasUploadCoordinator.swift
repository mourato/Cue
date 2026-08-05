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

    func upload(
        finalImage: NSImage,
        maxDimension: CGFloat,
        apiKey: String,
    ) async -> String? {
        isUploading = true
        lastErrorMessage = nil
        defer { isUploading = false }

        let preparedImage = downscaled(finalImage, maximumDimension: maxDimension)

        do {
            let result = try await uploadService.upload(image: preparedImage, apiKey: apiKey)
            lastUploadedURL = result.link
            return result.link
        } catch {
            lastErrorMessage = error.localizedDescription
            return nil
        }
    }

    private func downscaled(_ image: NSImage, maximumDimension: CGFloat) -> NSImage {
        let largestDimension = max(image.size.width, image.size.height)
        guard largestDimension > maximumDimension, largestDimension > 0 else { return image }

        let scale = maximumDimension / largestDimension
        let targetSize = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        let scaled = NSImage(size: targetSize)
        scaled.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: targetSize))
        scaled.unlockFocus()
        return scaled
    }
}
