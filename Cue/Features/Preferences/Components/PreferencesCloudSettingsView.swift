//
//  PreferencesCloudSettingsView.swift
//  Notinhas
//

import AppKit
import SwiftUI

struct CloudSettingsView: View {
    @ObservedObject private var uploadConfiguration = CueUploadConfigurationStore.shared
    @State private var credential = ""
    @State private var isEditing = false
    @State private var errorMessage: String?
    @State private var revealToken = false

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
                    if uploadConfiguration.provider == .cloudflare, revealToken {
                        Text(verbatim: uploadConfiguration.credential ?? "")
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .accessibilityLabel(credentialTitle)
                    } else {
                        Text(verbatim: uploadConfiguration.maskedCredential)
                            .textSelection(.enabled)
                    }
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
                    if uploadConfiguration.provider == .cloudflare, revealToken {
                        TextField(credentialTitle, text: $credential)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField(credentialTitle, text: $credential)
                            .textFieldStyle(.roundedBorder)
                    }
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

            if uploadConfiguration.provider == .cloudflare {
                Section(L10n.CloudSettings.cloudflareSection) {
                    TextField(L10n.CloudSettings.cloudflareWorkerURL, text: Binding(
                        get: { uploadConfiguration.cloudflareWorkerURL },
                        set: { uploadConfiguration.setCloudflareWorkerURL($0) },
                    ))
                    .textFieldStyle(.roundedBorder)
                    HStack {
                        Button(L10n.CloudSettings.cloudflareGenerateToken) {
                            credential = CueCloudflareCredentialStore.generatedToken()
                            revealToken = true
                            isEditing = true
                        }
                        Button(revealToken ? L10n.CloudSettings.cloudflareHideToken : L10n.CloudSettings
                            .cloudflareRevealToken) {
                                revealToken.toggle()
                            }
                        Button(L10n.CloudSettings.cloudflareCopyToken) {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(
                                credential.isEmpty ? (uploadConfiguration.cloudflare.token ?? "") : credential,
                                forType: .string,
                            )
                        }
                    }
                    HStack {
                        Link(
                            L10n.CloudSettings.cloudflareDocs,
                            destination: URL(
                                string: "https://developers.cloudflare.com/workers/get-started/guide/",
                            )!,
                        )
                        Button(L10n.CloudSettings.cloudflareVerify) {
                            Task { await uploadConfiguration.verifyCloudflareConnection() }
                        }
                        .disabled(uploadConfiguration.cloudflareConnectionState == .verifying)
                    }
                    Text(connectionStatus)
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
            case .cloudflare:
                try uploadConfiguration.cloudflare.save(token: credential)
            }
            credential = ""
            isEditing = false
            revealToken = false
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
                revealToken = false
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
        case .cloudflare: L10n.CloudSettings.cloudflareDescription
        }
    }

    private var credentialTitle: String {
        switch uploadConfiguration.provider {
        case .imgbb: L10n.CloudSettings.imgbbAPIKeyTitle
        case .imageKit: L10n.CloudSettings.imageKitPrivateKeyTitle
        case .cloudflare: L10n.CloudSettings.cloudflareToken
        }
    }

    private func clearCredential() {
        switch uploadConfiguration.provider {
        case .imgbb: uploadConfiguration.imgbb.clear()
        case .imageKit: uploadConfiguration.imageKit.clear()
        case .cloudflare: uploadConfiguration.cloudflare.clear()
        }
        credential = ""
        revealToken = false
    }

    private var connectionStatus: String {
        switch uploadConfiguration.cloudflareConnectionState {
        case .unconfigured: L10n.CloudSettings.cloudflareNotConfigured
        case .verifying: L10n.CloudSettings.cloudflareVerifying
        case .connected: L10n.CloudSettings.cloudflareConnected
        case .error: L10n.CloudSettings.cloudflareConnectionError
        }
    }
}

#Preview {
    CloudSettingsView()
}
