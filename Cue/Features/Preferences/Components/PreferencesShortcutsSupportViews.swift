//
//  PreferencesShortcutsSupportViews.swift
//  Cue
//
//  Shared rows and chrome used by Shortcuts preferences.
//

import AppKit
import Carbon.HIToolbox
import SwiftUI

struct ModeShortcutState: Equatable {
    var shortcut: CaptureOverlayShortcut?
}

struct CaptureOverlayShortcutRecorderRow: View {
    let label: String
    let description: String?
    @Binding var shortcut: CaptureOverlayShortcut?
    let defaultShortcut: CaptureOverlayShortcut?
    let isEnabled: Binding<Bool>
    let validationIssue: ShortcutValidationIssue?
    var allowsIndependent: Bool = true
    var isChild: Bool = false
    var isLastChild: Bool = false
    let onShortcutChanged: (CaptureOverlayShortcut?) -> Bool

    @State private var isRecording = false
    @State private var eventMonitor: Any?
    @State private var didSuspendGlobalShortcuts = false

    var body: some View {
        HStack(spacing: 8) {
            if isChild {
                GuideBranch(isLast: isLastChild)
                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                    .frame(width: 16)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.body)
                if let description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            shortcutRecorderButton

            ShortcutResetButton(
                isDisabled: !isEnabled.wrappedValue || isRecording || shortcut == defaultShortcut,
                action: resetToDefault,
            )

            toggleStatus
        }
        .padding(.vertical, 4)
        .opacity(rowOpacity)
        .onChange(of: isEnabled.wrappedValue) { newValue in
            if !newValue {
                stopRecording()
            }
        }
        .onDisappear {
            stopRecording()
        }
    }

    private var shortcutRecorderButton: some View {
        Button {
            startRecording()
        } label: {
            if isRecording {
                Text(L10n.ShortcutRecorder.pressKeys)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.accentColor)
                    .frame(minWidth: 100)
            } else if let shortcut {
                KeyCapGroupView(parts: shortcut.displayParts)
            } else {
                EmptyShortcutCTAView(title: L10n.PreferencesShortcuts.setKey, minWidth: 72)
            }
        }
        .buttonStyle(ShortcutKeycapButtonStyle(isRecording: isRecording))
        .shortcutValidationHighlight(issue: validationIssue)
        .disabled(!isEnabled.wrappedValue)
        .help(isEnabled.wrappedValue ? L10n.ShortcutRecorder.clickToRecord : L10n.ShortcutRecorder.turnOnToEdit)
    }

    private var toggleStatus: some View {
        HStack(spacing: 6) {
            Text(isEnabled.wrappedValue ? L10n.Common.on : L10n.Common.off)
                .font(.caption)
                .foregroundColor(.secondary)

            Toggle("", isOn: isEnabled)
                .labelsHidden()
                .accessibilityLabel(label)
        }
    }

    private var rowOpacity: Double {
        isEnabled.wrappedValue ? 1 : 0.62
    }

    private func resetToDefault() {
        if onShortcutChanged(defaultShortcut) {
            shortcut = defaultShortcut
        }
    }

    private func startRecording() {
        guard !isRecording, isEnabled.wrappedValue else { return }
        isRecording = true
        KeyboardShortcutManager.shared.beginTemporaryShortcutSuppression()
        didSuspendGlobalShortcuts = true

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) {
                stopRecording()
                return nil
            }

            if isClearShortcutEvent(event) {
                _ = onShortcutChanged(nil)
                stopRecording()
                return nil
            }

            let newShortcut = allowsIndependent
                ? CaptureOverlayShortcut(from: event)
                : CaptureOverlayShortcut(childKeyFrom: event)
            guard let newShortcut else {
                return nil
            }

            if onShortcutChanged(newShortcut) {
                shortcut = newShortcut
                stopRecording()
            }
            return nil
        }
    }

    private func isClearShortcutEvent(_ event: NSEvent) -> Bool {
        switch Int(event.keyCode) {
        case kVK_Delete, kVK_ForwardDelete:
            event.modifierFlags
                .intersection([.command, .control, .option, .shift])
                .isEmpty
        default:
            false
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        if didSuspendGlobalShortcuts {
            KeyboardShortcutManager.shared.endTemporaryShortcutSuppression()
            didSuspendGlobalShortcuts = false
        }
    }
}

// MARK: - Guide Step Component

struct PreferencesGuideStep: View {
    let step: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Text(step)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(FeedbackStyle(tone: .warning).iconColor)
                .frame(width: 18, height: 18)
                .background(
                    Circle()
                        .fill(FeedbackStyle(tone: .warning).iconColor.opacity(0.15)),
                )

            Text(.init(text)) // Supports **bold** markdown
                .font(.system(size: 12))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Read-Only Shortcut Row

struct ReadOnlyShortcutRow: View {
    let label: String
    let shortcut: String

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.body)
                .frame(minWidth: 100, alignment: .leading)

            Spacer()

            if shouldUseKeycaps {
                KeyCapGroupView(parts: shortcutParts)
            } else {
                Text(shortcut)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.1)),
                    )
            }
        }
        .padding(.vertical, 2)
    }

    /// Split the display string (e.g. "⌘ ⇧ Z" or "← → ↑ ↓") into individual parts
    private var shortcutParts: [String] {
        shortcut
            .split(separator: " ")
            .map(String.init)
    }

    private var shouldUseKeycaps: Bool {
        shortcutParts.filter { !modifierTokens.contains($0) }.count <= 1
    }

    private var modifierTokens: Set<String> {
        ["⌘", "⇧", "⌥", "⌃"]
    }
}

// MARK: - Guide Branch Shape

struct GuideBranch: Shape {
    let isLast: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.midY
        let rightX = rect.maxX
        let leftX = rect.minX

        path.move(to: CGPoint(x: leftX, y: midY))
        path.addLine(to: CGPoint(x: rightX, y: midY))

        if isLast {
            path.move(to: CGPoint(x: leftX, y: rect.minY))
            path.addLine(to: CGPoint(x: leftX, y: midY))
        } else {
            path.move(to: CGPoint(x: leftX, y: rect.minY))
            path.addLine(to: CGPoint(x: leftX, y: rect.maxY))
        }
        return path
    }
}
