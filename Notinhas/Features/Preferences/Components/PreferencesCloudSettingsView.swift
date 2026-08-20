//
//  PreferencesCloudSettingsView.swift
//  Notinhas
//

import SwiftUI

struct CloudSettingsView: View {
    @ObservedObject private var credentialStore = NotinhasImgBBCredentialStore.shared
    @State private var apiKey = ""
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section(L10n.CloudSettings.providerSection) {
                Text(L10n.CloudSettings.imgbbDescription)
                    .foregroundStyle(.secondary)

                if credentialStore.isConfigured {
                    Text(credentialStore.maskedAPIKey)
                        .textSelection(.enabled)
                    HStack {
                        Button("Edit") { apiKey = credentialStore.apiKey ?? "" }
                        Button(L10n.CloudSettings.reset, role: .destructive) { credentialStore.clear() }
                    }
                } else {
                    SecureField(L10n.CloudSettings.imgbbAPIKeyTitle, text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                    Button(L10n.Common.save) { save() }
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
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    CloudSettingsView()
}
