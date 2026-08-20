//
//  PreferencesCloudSettingsView.swift
//  Notinhas
//

import SwiftUI

struct CloudSettingsView: View {
    @ObservedObject private var credentialStore = NotinhasImgBBCredentialStore.shared
    @State private var apiKey = ""
    @State private var isEditing = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section(L10n.CloudSettings.providerSection) {
                Text(L10n.CloudSettings.imgbbDescription)
                    .foregroundStyle(.secondary)

                if credentialStore.isConfigured, !isEditing {
                    Text(credentialStore.maskedAPIKey)
                        .textSelection(.enabled)
                    HStack {
                        Button(L10n.CloudSettings.edit) {
                            apiKey = credentialStore.apiKey ?? ""
                            isEditing = true
                        }
                        Button(L10n.CloudSettings.reset, role: .destructive) {
                            credentialStore.clear()
                            apiKey = ""
                        }
                    }
                } else {
                    SecureField(L10n.CloudSettings.imgbbAPIKeyTitle, text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button(L10n.Common.save) { save() }
                        if isEditing {
                            Button(L10n.Common.cancel) {
                                apiKey = ""
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
            try credentialStore.save(apiKey: apiKey)
            apiKey = ""
            isEditing = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    CloudSettingsView()
}
