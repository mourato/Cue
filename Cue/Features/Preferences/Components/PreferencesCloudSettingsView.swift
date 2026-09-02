//
//  PreferencesCloudSettingsView.swift
//  Notinhas
//

import SwiftUI

struct CloudSettingsView: View {
    @ObservedObject private var uploadConfiguration = CueUploadConfigurationStore.shared
    @State private var credential = ""
    @State private var isEditing = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section(L10n.CloudSettings.providerSection) {
                Picker(L10n.CloudSettings.provider, selection: providerBinding) {
                    ForEach(CueUploadProvider.allCases) { provider in
                        Text(provider.name).tag(provider)
                    }
                }

                Text(description)
                    .foregroundStyle(.secondary)

                if uploadConfiguration.isConfigured, !isEditing {
                    Text(uploadConfiguration.maskedCredential)
                        .textSelection(.enabled)
                    HStack {
                        Button(L10n.CloudSettings.edit) {
                            credential = uploadConfiguration.credential ?? ""
                            isEditing = true
                        }
                        Button(L10n.CloudSettings.reset, role: .destructive) {
                            clearCredential()
                        }
                    }
                } else {
                    SecureField(credentialTitle, text: $credential)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button(L10n.Common.save) { save() }
                        if isEditing {
                            Button(L10n.Common.cancel) {
                                credential = ""
                                isEditing = false
                            }
                        }
                    }
                }
            }

            if uploadConfiguration.provider == .imageKit {
                Section(L10n.CloudSettings.imageKitVideoUploadSection) {
                    Picker(L10n.CloudSettings.imageKitVideoUploadPlan, selection: imageKitPlanBinding) {
                        ForEach(CueImageKitUploadPlan.allCases) { plan in
                            Text(imageKitPlanName(plan)).tag(plan)
                        }
                    }

                    if uploadConfiguration.imageKitPlan == .custom {
                        TextField(
                            L10n.CloudSettings.imageKitCustomVideoUploadLimit,
                            value: customVideoLimitBinding,
                            format: .number,
                        )
                        .textFieldStyle(.roundedBorder)
                    }

                    Text(L10n.CloudSettings.imageKitVideoUploadLimitDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .alert(L10n.CloudSettings.transferAlertTitle, isPresented: errorBinding) {
            Button(L10n.Common.ok, role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: {
                if !$0 {
                    errorMessage = nil
                }
            },
        )
    }

    private func save() {
        do {
            switch uploadConfiguration.provider {
            case .imgbb:
                try uploadConfiguration.imgbb.save(apiKey: credential)
            case .imageKit:
                try uploadConfiguration.imageKit.save(privateKey: credential)
            }
            credential = ""
            isEditing = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var providerBinding: Binding<CueUploadProvider> {
        Binding(
            get: { uploadConfiguration.provider },
            set: {
                uploadConfiguration.select($0)
                credential = ""
                isEditing = false
            },
        )
    }

    private var imageKitPlanBinding: Binding<CueImageKitUploadPlan> {
        Binding(
            get: { uploadConfiguration.imageKitPlan },
            set: { uploadConfiguration.selectImageKitPlan($0) },
        )
    }

    private var customVideoLimitBinding: Binding<Int> {
        Binding(
            get: { uploadConfiguration.imageKitCustomVideoLimitMB },
            set: { uploadConfiguration.setImageKitCustomVideoLimitMB($0) },
        )
    }

    private func imageKitPlanName(_ plan: CueImageKitUploadPlan) -> String {
        switch plan {
        case .free: L10n.CloudSettings.imageKitPlanFree
        case .lite: L10n.CloudSettings.imageKitPlanLite
        case .pro: L10n.CloudSettings.imageKitPlanPro
        case .custom: L10n.CloudSettings.imageKitPlanCustom
        }
    }

    private var description: String {
        switch uploadConfiguration.provider {
        case .imgbb: L10n.CloudSettings.imgbbDescription
        case .imageKit: L10n.CloudSettings.imageKitDescription
        }
    }

    private var credentialTitle: String {
        switch uploadConfiguration.provider {
        case .imgbb: L10n.CloudSettings.imgbbAPIKeyTitle
        case .imageKit: L10n.CloudSettings.imageKitPrivateKeyTitle
        }
    }

    private func clearCredential() {
        switch uploadConfiguration.provider {
        case .imgbb: uploadConfiguration.imgbb.clear()
        case .imageKit: uploadConfiguration.imageKit.clear()
        }
        credential = ""
    }
}

#Preview {
    CloudSettingsView()
}
