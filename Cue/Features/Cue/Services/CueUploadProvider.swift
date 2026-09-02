import Combine
import Foundation

enum CueUploadProvider: String, CaseIterable, Identifiable, Sendable {
    case imgbb
    case imageKit

    var id: String {
        rawValue
    }

    var name: String {
        switch self {
        case .imgbb: "ImgBB"
        case .imageKit: "ImageKit"
        }
    }

    func supports(_ mediaKind: CueUploadMediaKind) -> Bool {
        switch self {
        case .imgbb:
            mediaKind != .video
        case .imageKit:
            true
        }
    }
}

@MainActor
final class CueUploadConfigurationStore: ObservableObject {
    static let shared = CueUploadConfigurationStore()

    @Published private(set) var provider: CueUploadProvider
    @Published private(set) var revision = UUID()

    private let defaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()
    let imgbb: CueImgBBCredentialStore
    let imageKit: CueImageKitCredentialStore

    init(
        defaults: UserDefaults = .standard,
        imgbb: CueImgBBCredentialStore = .shared,
        imageKit: CueImageKitCredentialStore = .shared,
    ) {
        self.defaults = defaults
        self.imgbb = imgbb
        self.imageKit = imageKit
        provider = defaults.string(forKey: PreferencesKeys.uploadProvider)
            .flatMap(CueUploadProvider.init(rawValue:)) ?? .imgbb
        imgbb.$isConfigured
            .combineLatest(imageKit.$isConfigured)
            .sink { [weak self] _, _ in self?.revision = UUID() }
            .store(in: &cancellables)
    }

    var isConfigured: Bool {
        switch provider {
        case .imgbb: imgbb.isConfigured
        case .imageKit: imageKit.isConfigured
        }
    }

    var maskedCredential: String {
        switch provider {
        case .imgbb: imgbb.maskedAPIKey
        case .imageKit: imageKit.maskedPrivateKey
        }
    }

    var credential: String? {
        switch provider {
        case .imgbb: imgbb.apiKey
        case .imageKit: imageKit.privateKey
        }
    }

    func select(_ provider: CueUploadProvider) {
        guard self.provider != provider else { return }
        self.provider = provider
        defaults.set(provider.rawValue, forKey: PreferencesKeys.uploadProvider)
        revision = UUID()
    }

    func reload() {
        imgbb.reload()
        imageKit.reload()
        revision = UUID()
    }
}
