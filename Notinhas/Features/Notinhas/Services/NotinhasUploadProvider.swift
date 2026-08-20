import Combine
import Foundation

enum NotinhasUploadProvider: String, CaseIterable, Identifiable, Sendable {
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
}

@MainActor
final class NotinhasUploadConfigurationStore: ObservableObject {
    static let shared = NotinhasUploadConfigurationStore()

    @Published private(set) var provider: NotinhasUploadProvider
    @Published private(set) var revision = UUID()

    private let defaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()
    let imgbb: NotinhasImgBBCredentialStore
    let imageKit: NotinhasImageKitCredentialStore

    init(
        defaults: UserDefaults = .standard,
        imgbb: NotinhasImgBBCredentialStore = .shared,
        imageKit: NotinhasImageKitCredentialStore = .shared,
    ) {
        self.defaults = defaults
        self.imgbb = imgbb
        self.imageKit = imageKit
        provider = defaults.string(forKey: PreferencesKeys.uploadProvider)
            .flatMap(NotinhasUploadProvider.init(rawValue:)) ?? .imgbb
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

    func select(_ provider: NotinhasUploadProvider) {
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
