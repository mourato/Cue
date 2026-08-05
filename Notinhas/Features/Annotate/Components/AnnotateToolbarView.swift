//
//  AnnotateToolbarView.swift
//  Notinhas
//
//  Top toolbar with annotation tools and actions
//

import SwiftUI

private enum AnnotateToolbarActionRegistration: Equatable {
    case annotateDefault
    case crop
}

/// Top toolbar containing all annotation tools
struct AnnotateToolbarView: View {
    @ObservedObject var state: AnnotateState
    @ObservedObject private var annotateShortcutManager = AnnotateShortcutManager.shared
    @ObservedObject private var chromeStore = AnnotateChromeConfigurationStore.shared
    @AppStorage(PreferencesKeys.backgroundCutoutAutoCropEnabled) private var backgroundCutoutAutoCropEnabled = true

    var body: some View {
        HStack(spacing: WindowSpacingConfiguration.default.toolbarItemSpacing) {
            // Add spacer for traffic lights
            Spacer().frame(width: 0)

            // Undo/Redo
            undoRedoGroup

            ToolbarDivider()

            // Left group: Capture tools
            captureToolsGroup

            ToolbarDivider()

            // Center group: Annotation tools
            annotationToolsGroup

            if state.isCombineMode {
                ToolbarDivider()

                ToolbarButton(icon: "photo.badge.plus", isSelected: false) {
                    guard let window = NSApp.keyWindow else { return }
                    NotificationCenter.default.post(name: .annotateAddImage, object: window)
                }
                .help(L10n.Combine.pickerTitle)

                ToolbarDivider()
            }

            Spacer()

            registeredActionButtons
        }
        .windowTrafficLightsInset()
        .windowToolbarPadding()
        .animation(.easeInOut(duration: 0.16), value: activeActionRegistration)
        .onAppear(perform: ensureValidSelectedTool)
        .onChange(of: chromeStore.toolbarItemOrder) { _ in ensureValidSelectedTool() }
        .onChange(of: chromeStore.enabledItems) { _ in ensureValidSelectedTool() }
        .alert(
            L10n.AnnotateUI.backgroundCutoutTitle,
            isPresented: Binding(
                get: { state.cutoutErrorMessage != nil },
                set: {
                    if !$0 {
                        state.cutoutErrorMessage = nil
                    }
                },
            ),
        ) {
            Button(L10n.Common.ok, role: .cancel) {}
        } message: {
            Text(state.cutoutErrorMessage ?? L10n.AnnotateUI.unableToRemoveBackground)
        }
    }

    // MARK: - Tool Groups

    private var captureToolsGroup: some View {
        let items = chromeStore.orderedToolbarItems(in: .captureChrome)
        return HStack(spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if item == .rotateLeft, index > 0 {
                    ToolbarDivider()
                }
                captureChromeButton(for: item)
            }
        }
    }

    @ViewBuilder
    private func captureChromeButton(for item: AnnotateChromeItem) -> some View {
        switch item {
        case .crop:
            let cropTitle = L10n.AnnotateUI.crop
            let cropKeys = AnnotateOverlayTooltipKeys.toolKeys(for: .crop, manager: annotateShortcutManager)
            ToolbarButton(
                icon: "crop",
                isSelected: state.selectedTool == .crop,
            ) {
                state.beginCropInteraction()
            }
            .overlayTooltip(cropTitle, keys: cropKeys, edge: .below)
            .accessibilityLabel(accessibilityTitle(cropTitle, keys: cropKeys))

        case .addBackground:
            let sidebarTitle = L10n.AnnotateUI.toggleSidebar
            let sidebarKeys = AnnotateOverlayTooltipKeys.actionKeys(
                for: .toggleSidebar,
                manager: annotateShortcutManager,
            )
            ToolbarButton(
                icon: "rectangle.on.rectangle",
                isSelected: state.leftDock == .background,
                highlightColor: .blue,
            ) {
                state.toggleSidebarVisibility()
            }
            .overlayTooltip(sidebarTitle, keys: sidebarKeys, edge: .below)
            .accessibilityLabel(accessibilityTitle(sidebarTitle, keys: sidebarKeys))

        case .rotateLeft:
            ToolbarButton(icon: "rotate.left", isSelected: false) {
                state.rotateImage(clockwise: false)
            }
            .help(L10n.AnnotateUI.rotateLeft)
            .disabled(!state.canRotateImage)
            .opacity(state.canRotateImage ? 1 : 0.4)

        case .rotateRight:
            ToolbarButton(icon: "rotate.right", isSelected: false) {
                state.rotateImage(clockwise: true)
            }
            .help(L10n.AnnotateUI.rotateRight)
            .disabled(!state.canRotateImage)
            .opacity(state.canRotateImage ? 1 : 0.4)

        default:
            EmptyView()
        }
    }

    private var annotationToolsGroup: some View {
        let items = chromeStore.orderedToolbarItems(in: .drawingOrCutout)
        return HStack(spacing: 4) {
            annotationToolButton(for: .selection)

            ForEach(items, id: \.id) { item in
                if let tool = item.annotationToolType {
                    annotationToolButton(for: tool, help: toolHelp(for: tool))
                } else if item == .backgroundCutout {
                    backgroundCutoutButton
                        .padding(.leading, 2)
                }
            }
        }
    }

    private func toolHelp(for tool: AnnotationToolType) -> String? {
        guard tool == .notinhasNote else { return nil }
        return NotinhasL10n.noteTool
    }

    private var backgroundCutoutButton: some View {
        ToolbarButton(
            icon: state.isCutoutProcessing ? "hourglass" : "wand.and.stars",
            isSelected: state.isCutoutApplied,
            highlightColor: .blue,
        ) {
            state.toggleBackgroundCutout()
        }
        .disabled(!state.canUseBackgroundCutout || !state.hasImage || state.isCutoutProcessing)
        .opacity((!state.canUseBackgroundCutout || !state.hasImage) ? 0.4 : 1)
        .help(
            state.canUseBackgroundCutout
                ? (state.isCutoutApplied
                    ? L10n.AnnotateUI.backgroundRemovedClickToRestore
                    : (backgroundCutoutAutoCropEnabled
                        ? L10n.AnnotateUI.removeBackgroundAutoCropsWhenSafe
                        : L10n.AnnotateUI.removeBackgroundAutoCropDisabledInSettings))
                : L10n.AnnotateUI.requiresMacOS14OrLater,
        )
    }

    private func annotationToolButton(for tool: AnnotationToolType, help: String? = nil) -> some View {
        let title = help ?? tool.displayName
        let keys = AnnotateOverlayTooltipKeys.toolKeys(for: tool, manager: annotateShortcutManager)
        let accessibilityLabel = accessibilityLabel(for: tool, title: title, keys: keys)
        return ToolbarButton(
            icon: tool.icon,
            isSelected: state.selectedTool == tool,
        ) {
            state.activateTool(tool)
        }
        .overlayTooltip(
            title,
            keys: keys,
            secondary: tool == .notinhasNote ? NotinhasL10n.noteToolGestureHint : nil,
            edge: .below,
        )
        .accessibilityLabel(accessibilityLabel)
        .disabled(state.editorMode == .mockup && tool != .selection)
        .opacity(state.editorMode == .mockup && tool != .selection ? 0.4 : 1)
    }

    private func accessibilityLabel(for tool: AnnotationToolType, title: String, keys: [String]) -> String {
        guard tool == .notinhasNote else {
            return accessibilityTitle(title, keys: keys)
        }
        let spokenTitle = keys.isEmpty ? title : L10n.Common.withShortcut(title, keys.joined())
        return NotinhasL10n.noteToolTooltip(title: spokenTitle)
    }

    private var undoRedoGroup: some View {
        let undoKeys = ["⌘", "Z"]
        let redoKeys = ["⌘", "⇧", "Z"]

        return HStack(spacing: 4) {
            ToolbarButton(icon: "arrow.uturn.backward", isSelected: false) {
                state.undo()
            }
            .overlayTooltip(L10n.Common.undo, keys: undoKeys, edge: .below)
            .accessibilityLabel(accessibilityTitle(L10n.Common.undo, keys: undoKeys))
            .disabled(!state.canUndo)
            .opacity(state.canUndo ? 1 : 0.4)

            ToolbarButton(icon: "arrow.uturn.forward", isSelected: false) {
                state.redo()
            }
            .overlayTooltip(L10n.Common.redo, keys: redoKeys, edge: .below)
            .accessibilityLabel(accessibilityTitle(L10n.Common.redo, keys: redoKeys))
            .disabled(!state.canRedo)
            .opacity(state.canRedo ? 1 : 0.4)
        }
    }

    private var activeActionRegistration: AnnotateToolbarActionRegistration {
        if state.selectedTool == .crop, state.isCropActive {
            return .crop
        }

        return .annotateDefault
    }

    @ViewBuilder
    private var registeredActionButtons: some View {
        switch activeActionRegistration {
        case .annotateDefault:
            annotateActionButtons
                .transition(.opacity.combined(with: .move(edge: .trailing)))
        case .crop:
            cropActionButtons
                .transition(.opacity.combined(with: .move(edge: .trailing)))
        }
    }

    private var annotateActionButtons: some View {
        let saveAsKeys = ["⌘", "⇧", "S"]
        let doneKeys = ["⌘", "S"]

        return HStack(spacing: 8) {
            if chromeStore.isEnabled(.saveAs) {
                Button(L10n.Common.saveAs) {
                    saveAs()
                }
                .buttonStyle(.bordered)
                .overlayTooltip(L10n.Common.saveAs, keys: saveAsKeys, edge: .below)
                .accessibilityLabel(accessibilityTitle(L10n.Common.saveAs, keys: saveAsKeys))
            }

            Button(L10n.Common.done) {
                done()
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .overlayTooltip(L10n.Common.done, keys: doneKeys, edge: .below)
            .accessibilityLabel(accessibilityTitle(L10n.Common.done, keys: doneKeys))
        }
    }

    private var cropActionButtons: some View {
        let restoreTitle = "\(L10n.Common.restore) \(L10n.Common.original)"
        let cancelKeys = ["esc"]
        let applyKeys = ["⏎"]

        return HStack(spacing: 8) {
            Button(restoreTitle) {
                state.revertCropToOriginalBounds()
            }
            .buttonStyle(.bordered)
            .overlayTooltip(restoreTitle, edge: .below)

            Button(L10n.Common.cancel) {
                state.cancelCrop()
            }
            .buttonStyle(.bordered)
            .overlayTooltip(L10n.Common.cancel, keys: cancelKeys, edge: .below)
            .accessibilityLabel(accessibilityTitle(L10n.Common.cancel, keys: cancelKeys))

            Button(L10n.Common.apply) {
                state.confirmCropInteraction()
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .overlayTooltip(L10n.Common.apply, keys: applyKeys, edge: .below)
            .accessibilityLabel(accessibilityTitle(L10n.Common.apply, keys: applyKeys))
        }
    }

    // MARK: - Actions

    private func ensureValidSelectedTool() {
        state.reconcileChromeToolAvailability(isEnabled: chromeStore.isEnabled)
    }

    private func accessibilityTitle(_ title: String, keys: [String]) -> String {
        guard !keys.isEmpty else { return title }
        let shortcut = keys.joined(separator: "")
        return L10n.Common.withShortcut(title, shortcut)
    }

    private func saveAs() {
        if state.isCombineMode {
            guard let window = NSApp.keyWindow else { return }
            NotificationCenter.default.post(name: .annotateSave, object: window)
        } else {
            AnnotateExporter.saveAs(state: state, closeWindow: true)
        }
    }

    private func done() {
        // Post save notification — controller handles silent save + cache + QA refresh + close
        guard let window = NSApp.keyWindow else { return }
        NotificationCenter.default.post(name: .annotateSave, object: window)
    }
}
