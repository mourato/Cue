//
//  PreferencesCloudSettingsView.swift
//  Notinhas
//

import SwiftUI

struct CloudSettingsView: View {
    @ObservedObject private var uploadConfiguration = NotinhasUploadConfigurationStore.shared
    @State private var credential = ""
    @State private var isEditing = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section(L10n.CloudSettings.providerSection) {
                Picker(L10n.CloudSettings.provider, selection: providerBinding) {
                    ForEach(NotinhasUploadProvider.allCases) { provider in
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

    private var providerBinding: Binding<NotinhasUploadProvider> {
        Binding(
            get: { uploadConfiguration.provider },
            set: {
                uploadConfiguration.select($0)
                credential = ""
                isEditing = false
            },
        )
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
