//
//  PreferencesAnnotateSettingsView.swift
//  Notinhas
//
//  Annotate preferences tab for editor behavior settings.
//

import SwiftUI

struct AnnotateSettingsView: View {
    @AppStorage(PreferencesKeys.annotateClipboardImageOpenBehavior)
    private var annotateClipboardImageOpenBehavior = AnnotateClipboardImageBehavior.ask.rawValue
    @AppStorage(PreferencesKeys.annotateCloseAfterDrag) private var annotateCloseAfterDrag = true
    @AppStorage(PreferencesKeys.annotateBringForwardAfterDrag)
    private var annotateBringForwardAfterDrag = false
    @AppStorage(PreferencesKeys.annotateQuickPropertiesSyncEnabled)
    private var annotateQuickPropertiesSyncEnabled = true
    @AppStorage(PreferencesKeys.annotateCombineSaveAsEdit)
    private var annotateCombineSaveAsEdit = true

    var body: some View {
        Form {
            AnnotateChromeCustomizationView()

            Section(L10n.PreferencesAnnotate.behaviorSection) {
                SettingRow(
                    icon: "slider.horizontal.3",
                    title: L10n.PreferencesAnnotate.quickPropertiesSyncTitle,
                    description: L10n.PreferencesAnnotate.quickPropertiesSyncDescription,
                ) {
                    Toggle("", isOn: $annotateQuickPropertiesSyncEnabled)
                        .labelsHidden()
                        .accessibilityLabel(L10n.PreferencesAnnotate.quickPropertiesSyncTitle)
                }

                SettingRow(
                    icon: "rectangle.stack",
                    title: L10n.PreferencesAnnotate.combineSaveAsEditTitle,
                    description: L10n.PreferencesAnnotate.combineSaveAsEditDescription,
                ) {
                    Toggle("", isOn: $annotateCombineSaveAsEdit)
                        .labelsHidden()
                        .accessibilityLabel(L10n.PreferencesAnnotate.combineSaveAsEditTitle)
                }

                SettingRow(
                    icon: "doc.on.clipboard",
                    title: L10n.PreferencesAnnotate.clipboardTitle,
                    description: L10n.PreferencesAnnotate.clipboardDescription,
                ) {
                    Picker("", selection: $annotateClipboardImageOpenBehavior) {
                        ForEach(AnnotateClipboardImageBehavior.allCases) { behavior in
                            Text(behavior.displayName).tag(behavior.rawValue)
                        }
                    }
                    .labelsHidden()
                    .accessibilityLabel(L10n.PreferencesAnnotate.clipboardTitle)
                    .pickerStyle(.menu)
                    .fixedSize()
                    .frame(width: 180, alignment: .trailing)
                }

                SettingRow(
                    icon: "arrow.up.forward.app",
                    title: L10n.PreferencesAnnotate.closeAfterDragTitle,
                    description: L10n.PreferencesAnnotate.closeAfterDragDescription,
                ) {
                    Toggle("", isOn: $annotateCloseAfterDrag)
                        .labelsHidden()
                        .accessibilityLabel(L10n.PreferencesAnnotate.closeAfterDragTitle)
                }

                SettingRow(
                    icon: "macwindow",
                    title: L10n.PreferencesAnnotate.bringForwardAfterDragTitle,
                    description: L10n.PreferencesAnnotate.bringForwardAfterDragDescription,
                ) {
                    Toggle("", isOn: $annotateBringForwardAfterDrag)
                        .labelsHidden()
                        .accessibilityLabel(L10n.PreferencesAnnotate.bringForwardAfterDragTitle)
                }
                .disabled(annotateCloseAfterDrag)
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    AnnotateSettingsView()
        .frame(width: 600, height: 550)
}
