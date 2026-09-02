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
    @Published private(set) var imageKitPlan: CueImageKitUploadPlan
    @Published private(set) var imageKitCustomVideoLimitMB: Int
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
        imageKitPlan = defaults.string(forKey: PreferencesKeys.uploadImageKitPlan)
            .flatMap(CueImageKitUploadPlan.init(rawValue:)) ?? .free
        imageKitCustomVideoLimitMB = min(
            max(
                defaults.integer(forKey: PreferencesKeys.uploadImageKitCustomVideoLimitMB),
                CueImageKitUploadPlan.minimumCustomLimitMB,
            ),
            CueImageKitUploadPlan.maximumCustomLimitMB,
        )
        if defaults.object(forKey: PreferencesKeys.uploadImageKitCustomVideoLimitMB) == nil {
            imageKitCustomVideoLimitMB = 100
        }
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

    var imageKitVideoUploadLimitBytes: Int64 {
        imageKitPlan.videoLimitBytes(customLimitMB: imageKitCustomVideoLimitMB)
    }

    /// Leaves room for multipart overhead and provider-side boundary differences.
    var imageKitVideoUploadTargetBytes: Int64 {
        max(1, imageKitVideoUploadLimitBytes * 95 / 100)
    }

    func select(_ provider: CueUploadProvider) {
        guard self.provider != provider else { return }
        self.provider = provider
        defaults.set(provider.rawValue, forKey: PreferencesKeys.uploadProvider)
        revision = UUID()
    }

    func selectImageKitPlan(_ plan: CueImageKitUploadPlan) {
        guard imageKitPlan != plan else { return }
        imageKitPlan = plan
        defaults.set(plan.rawValue, forKey: PreferencesKeys.uploadImageKitPlan)
        revision = UUID()
    }

    func setImageKitCustomVideoLimitMB(_ megabytes: Int) {
        let value = min(
            max(megabytes, CueImageKitUploadPlan.minimumCustomLimitMB),
            CueImageKitUploadPlan.maximumCustomLimitMB,
        )
        guard imageKitCustomVideoLimitMB != value else { return }
        imageKitCustomVideoLimitMB = value
        defaults.set(value, forKey: PreferencesKeys.uploadImageKitCustomVideoLimitMB)
        revision = UUID()
    }

    func reload() {
        imgbb.reload()
        imageKit.reload()
        revision = UUID()
    }
}
