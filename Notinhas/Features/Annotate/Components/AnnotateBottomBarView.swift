//
//  AnnotateBottomBarView.swift
//  Notinhas
//
//  Bottom bar with zoom, drag handle, and action buttons
//

import SwiftUI

private enum AnnotateBottomActionRegistration: Equatable {
    case annotateDefault
    case crop
}

private enum AnnotateBottomBarMeasuredSide: Hashable {
    case left
    case right
}

private struct AnnotateBottomBarWidthPreferenceKey: PreferenceKey {
    static let defaultValue: [AnnotateBottomBarMeasuredSide: CGFloat] = [:]

    static func reduce(
        value: inout [AnnotateBottomBarMeasuredSide: CGFloat],
        nextValue: () -> [AnnotateBottomBarMeasuredSide: CGFloat],
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, newValue in newValue })
    }
}

private extension View {
    func measuredBottomBarWidth(_ side: AnnotateBottomBarMeasuredSide) -> some View {
        background(
            GeometryReader { geometry in
                Color.clear.preference(
                    key: AnnotateBottomBarWidthPreferenceKey.self,
                    value: [side: geometry.size.width],
                )
            },
        )
    }
}

/// Bottom bar containing zoom controls and action buttons
struct AnnotateBottomBarView: View {
    @ObservedObject var state: AnnotateState
    @ObservedObject private var preferencesManager = PreferencesManager.shared
    @ObservedObject private var annotateShortcutManager = AnnotateShortcutManager.shared
    @ObservedObject private var chromeStore = AnnotateChromeConfigurationStore.shared

    @State private var isUploading = false
    @ObservedObject private var uploadConfiguration = NotinhasUploadConfigurationStore.shared
    private let uploadCoordinator = NotinhasUploadCoordinator()
    @State private var measuredLeftWidth: CGFloat = 0
    @State private var measuredRightWidth: CGFloat = 0

    private let centeredDragFullWidth: CGFloat = 160
    private let centeredDragCompactWidth: CGFloat = 44
    private let centeredDragHeight: CGFloat = 32
    private let centeredDragSideGap: CGFloat = 12

    var body: some View {
        VStack(spacing: 0) {
            // Mockup preset bar (shown when mockup mode is active)
            if state.editorMode == .mockup {
                MockupPresetBarInline(state: state)
                Divider()
            }

            bottomBarContent
                .windowBottomBarPadding()
                .animation(.easeInOut(duration: 0.16), value: activeActionRegistration)
                .onPreferenceChange(AnnotateBottomBarWidthPreferenceKey.self) { widths in
                    measuredLeftWidth = widths[.left] ?? 0
                    measuredRightWidth = widths[.right] ?? 0
                }
                .onAppear(perform: ensureValidSelectedTool)
                .onChange(of: chromeStore.bottomActionOrder) { _ in ensureValidSelectedTool() }
                .onChange(of: chromeStore.enabledItems) { _ in ensureValidSelectedTool() }
        }
    }

    // MARK: - Left Section

    private var bottomBarContent: some View {
        GeometryReader { geometry in
            let dragWidth = centeredDragWidth(for: geometry.size.width)

            ZStack {
                HStack(spacing: 0) {
                    // Left section: zoom + mode toggle
                    leftSection
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .captureFloatingToolbarMaterial()
                        .shadow(color: .black.opacity(0.14), radius: 10, y: 3)
                        .fixedSize(horizontal: true, vertical: false)
                        .measuredBottomBarWidth(.left)

                    Spacer(minLength: 0)

                    // Right section: registered action surface
                    registeredActionSurface
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .captureFloatingToolbarMaterial()
                        .shadow(color: .black.opacity(0.14), radius: 10, y: 3)
                        .fixedSize(horizontal: true, vertical: false)
                        .measuredBottomBarWidth(.right)
                }

                // Center: Drag handle pinned to true bar center. If the bar gets too
                // tight, it compacts before hiding so side controls stay clickable.
                if state.hasImage, activeActionRegistration == .annotateDefault, dragWidth > 0 {
                    dragHandle(
                        width: dragWidth,
                        isCompact: dragWidth < centeredDragFullWidth,
                    )
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }
            }
        }
        .frame(height: centeredDragHeight)
    }

    private var leftSection: some View {
        HStack(spacing: 10) {
            zoomPicker
            canvasPanButton
            modeToggle
        }
    }

    private func centeredDragWidth(for contentWidth: CGFloat) -> CGFloat {
        guard contentWidth > 0 else { return centeredDragFullWidth }

        let halfWidth = contentWidth / 2
        let leftClearance = halfWidth - measuredLeftWidth - centeredDragSideGap
        let rightClearance = halfWidth - measuredRightWidth - centeredDragSideGap
        let availableCenteredWidth = max(0, min(leftClearance, rightClearance) * 2)

        if availableCenteredWidth >= centeredDragFullWidth {
            return centeredDragFullWidth
        }

        if availableCenteredWidth >= centeredDragCompactWidth {
            return centeredDragCompactWidth
        }

        return 0
    }

    // MARK: - Zoom Picker

    private var canvasPanButton: some View {
        Button {
            state.isCanvasPanningMode.toggle()
        } label: {
            Image(systemName: state.isCanvasPanningMode ? "hand.draw.fill" : "hand.draw")
                .font(.system(size: 13, weight: .medium))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .foregroundColor(state.isCanvasPanningMode ? .accentColor : .secondary)
        .background(state.isCanvasPanningMode ? Color.accentColor.opacity(0.16) : Color.primary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .help(L10n.AnnotateUI.moveCanvas)
        .accessibilityLabel(L10n.AnnotateUI.moveCanvas)
        .accessibilityValue(state.isCanvasPanningMode ? L10n.Common.enabled : L10n.Common.disabled)
        .disabled(!state.canPanInteractively)
    }

    private var zoomPicker: some View {
        Menu {
            ForEach(state.zoomMenuPresetPercents, id: \.self) { percent in
                Button("\(percent)%") {
                    withAnimation(.easeOut(duration: 0.15)) {
                        state.zoomLevel = state.zoomLevel(forDisplayedPercent: percent)
                    }
                }
            }

            Divider()

            Button("1:1") {
                withAnimation(.easeOut(duration: 0.15)) {
                    state.zoomLevel = state.actualPixelZoomLevel
                }
            }

            Button(L10n.AnnotateUI.fitWithShortcut("⌘0")) {
                withAnimation(.easeOut(duration: 0.15)) {
                    state.zoomLevel = 1.0
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text("\(state.currentDisplayedZoomPercent)%")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.1))
            .cornerRadius(6)
        }
        .menuStyle(.borderlessButton)
        .fixedSize(horizontal: true, vertical: false)
    }

    // MARK: - Mode Toggle

    /// Check if any mockup transforms have been applied
    private var hasMockupTransforms: Bool {
        state.mockupRotationX != 0 ||
            state.mockupRotationY != 0 ||
            state.mockupRotationZ != 0
    }

    private var modeToggle: some View {
        Picker("", selection: $state.editorMode) {
            Label(L10n.AnnotateUI.modeAnnotate, systemImage: "pencil.and.outline")
                .tag(AnnotateState.EditorMode.annotate)
            Label(L10n.AnnotateUI.modePreview, systemImage: "eye")
                .tag(AnnotateState.EditorMode.preview)
            Label(L10n.AnnotateUI.modeMockup, systemImage: "cube.transparent")
                .tag(AnnotateState.EditorMode.mockup)
        }
        .pickerStyle(.segmented)
        .frame(width: 220)
    }

    // MARK: - Drag Handle (CleanShot-style)

    @State private var isDragHovering = false

    private func dragHandle(width: CGFloat, isCompact: Bool) -> some View {
        let dragState = state.dragToAppPreparationState

        return AnnotateDragHandleView(state: state)
            .frame(width: width, height: centeredDragHeight)
            .overlay(
                HStack(spacing: isCompact ? 0 : 6) {
                    if dragState == .preparing {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.7)
                            .tint(isDragHovering ? .primary : .secondary)
                    } else {
                        Image(systemName: "hand.draw")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(isDragHovering ? .primary : .secondary)
                    }

                    if !isCompact {
                        Text(L10n.AnnotateUI.dragToApp)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(dragLabelColor(for: dragState))
                    }
                }
                .allowsHitTesting(false),
            )
            .background(
                Capsule()
                    .fill(dragBackgroundColor(for: dragState)),
            )
            .overlay(
                Capsule()
                    .strokeBorder(dragBorderColor(for: dragState), lineWidth: 1),
            )
            .onHover { isDragHovering = $0 }
            .animation(.easeInOut(duration: 0.15), value: isDragHovering)
            .animation(.easeInOut(duration: 0.15), value: dragState)
            .help(L10n.AnnotateUI.dragToAppHelp)
    }

    private func dragLabelColor(for state: AnnotateState.DragToAppPreparationState) -> Color {
        switch state {
        case .ready:
            isDragHovering ? .primary : .secondary
        case .preparing:
            .primary
        case .unavailable:
            .secondary.opacity(0.6)
        }
    }

    private func dragBackgroundColor(for state: AnnotateState.DragToAppPreparationState) -> Color {
        switch state {
        case .ready:
            isDragHovering ? Color.primary.opacity(0.12) : Color.primary.opacity(0.06)
        case .preparing:
            Color.accentColor.opacity(isDragHovering ? 0.12 : 0.08)
        case .unavailable:
            Color.primary.opacity(0.04)
        }
    }

    private func dragBorderColor(for state: AnnotateState.DragToAppPreparationState) -> Color {
        switch state {
        case .ready:
            Color.primary.opacity(isDragHovering ? 0.2 : 0.1)
        case .preparing:
            Color.accentColor.opacity(isDragHovering ? 0.35 : 0.22)
        case .unavailable:
            Color.primary.opacity(0.08)
        }
    }

    // MARK: - Action Buttons

    private var activeActionRegistration: AnnotateBottomActionRegistration {
        // Specialized tools can register a replacement for the default Annotate actions here.
        if state.selectedTool == .crop, state.isCropActive {
            return .crop
        }

        return .annotateDefault
    }

    @ViewBuilder
    private var registeredActionSurface: some View {
        switch activeActionRegistration {
        case .annotateDefault:
            annotateActionButtons
                .transition(.opacity.combined(with: .move(edge: .trailing)))
        case .crop:
            CropToolbarView(state: state)
                .transition(.opacity.combined(with: .move(edge: .trailing)))
        }
    }

    private var isUploadConfigured: Bool {
        _ = uploadConfiguration.revision
        return uploadConfiguration.isConfigured
    }

    private var annotateActionButtons: some View {
        HStack(spacing: 12) {
            ForEach(chromeStore.orderedBottomActions(), id: \.id) { item in
                bottomActionButton(for: item)
            }
        }
    }

    @ViewBuilder
    private func bottomActionButton(for item: AnnotateChromeItem) -> some View {
        switch item {
        case .newWindow:
            BottomBarButton(
                icon: "plus.rectangle.on.rectangle",
                tooltipTitle: L10n.AnnotateUI.newWindow,
            ) {
                AnnotateManager.shared.openEmptyAnnotation()
            }

        case .share:
            BottomBarButton(icon: "square.and.arrow.up", tooltipTitle: L10n.Common.share) {
                share()
            }

        case .uploadToImgBB:
            BottomBarButton(
                icon: isUploading ? "hourglass" : "icloud.and.arrow.up",
                tooltipTitle: isUploadConfigured ? uploadActionTitle : missingCredentialMessage,
            ) {
                handleUpload()
            }
            .disabled(isUploading || !isUploadConfigured)
            .opacity(isUploadConfigured ? 1 : 0.5)

        case .pin:
            let pinKeys = AnnotateOverlayTooltipKeys.actionKeys(for: .togglePin, manager: annotateShortcutManager)
            BottomBarButton(
                icon: state.isPinned ? "pin.fill" : "pin",
                tooltipTitle: state.isPinned ? L10n.AnnotateUI.unpinWindow : L10n.AnnotateUI.pinWindow,
                tooltipKeys: pinKeys,
            ) {
                pin()
            }

        case .copy:
            let copyKeys = AnnotateOverlayTooltipKeys.actionKeys(for: .copyAndClose, manager: annotateShortcutManager)
            BottomBarButton(
                icon: "doc.on.doc",
                tooltipTitle: L10n.AnnotateUI.copyToClipboard,
                tooltipKeys: copyKeys,
            ) {
                copyToClipboard()
            }

        case .delete:
            BottomBarButton(icon: "trash", tooltipTitle: L10n.Common.deleteAction) {
                confirmAndDeleteImage()
            }
            .disabled(state.sourceURL == nil)
            .opacity(state.sourceURL == nil ? 0.5 : 1)

        default:
            EmptyView()
        }
    }

    private func ensureValidSelectedTool() {
        state.reconcileChromeToolAvailability(isEnabled: chromeStore.isEnabled)
    }

    // MARK: - Actions

    private func share() {
        guard let window = NSApp.keyWindow, let contentView = window.contentView else { return }
        AnnotateExporter.share(state: state, from: contentView)
    }

    private func pin() {
        if let window = NSApp.keyWindow {
            let newPinned = !state.isPinned
            if let annotateWindow = window as? AnnotateWindow {
                annotateWindow.setRestingLevel(newPinned ? .floating : .normal)
            } else {
                window.level = newPinned ? .floating : .normal
            }
            state.isPinned = newPinned
        }
    }

    private func copyToClipboard() {
        guard let window = NSApp.keyWindow else { return }
        // Post notification so the controller handles save + cache + copy
        NotificationCenter.default.post(name: .annotateCopyAndClose, object: window)
    }

    private func confirmAndDeleteImage() {
        guard let sourceURL = state.sourceURL,
              let window = NSApp.keyWindow else { return }

        let alert = NSAlert()
        alert.messageText = L10n.AnnotateUI.deleteScreenshotTitle
        alert.informativeText = L10n.AnnotateUI.deleteScreenshotMessage(sourceURL.lastPathComponent)
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.Common.deleteAction)
        alert.addButton(withTitle: L10n.Common.cancel)

        alert.beginSheetModal(for: window) { [state] response in
            guard response == .alertFirstButtonReturn else { return }

            // Clear matching history record FIRST so the user does not see a stale
            // "file missing" entry after the underlying file is trashed.
            CaptureHistoryStore.shared.removeByFilePath(sourceURL.path)
            AnnotationSessionStore.shared.deleteSession(for: sourceURL)

            // Remove QuickAccess card if it exists
            if let itemId = state.quickAccessItemId {
                QuickAccessManager.shared.removeItem(id: itemId)
            }

            // Trash the file
            let fileAccessManager = SandboxFileAccessManager.shared
            let fileAccess = fileAccessManager.beginAccessingURL(sourceURL)
            let directoryAccess = fileAccessManager.beginAccessingURL(sourceURL.deletingLastPathComponent())
            defer {
                fileAccess.stop()
                directoryAccess.stop()
            }

            try? FileManager.default.trashItem(at: sourceURL, resultingItemURL: nil)

            // Close the annotate window (captured before alert)
            state.hasUnsavedChanges = false
            window.close()
        }
    }

    private func handleUpload() {
        guard isUploadConfigured else {
            AppToastManager.shared.show(message: missingCredentialMessage, style: .warning)
            return
        }
        guard let renderedImage = AnnotateExporter.renderFinalImage(state: state) else {
            AppToastManager.shared.show(message: NotinhasL10n.imgbbInvalidImageData, style: .error)
            return
        }

        isUploading = true
        // Long upload: one toast handle with spinner, then update to terminal success/error.
        let progressToast = AppToastManager.shared.show(
            message: uploadingMessage,
            style: .info,
            duration: nil,
            iconMode: .spinner,
        )

        Task { @MainActor in
            defer { isUploading = false }
            let link = await uploadCoordinator.upload(
                finalImage: renderedImage,
            )
            if let link {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(link, forType: .string)
                SoundManager.play("Pop")
                if let progressToast {
                    AppToastManager.shared.update(
                        progressToast,
                        message: uploadedMessage,
                        style: .success,
                    )
                } else {
                    AppToastManager.shared.show(message: uploadedMessage, style: .success)
                }
            } else {
                let message = uploadCoordinator.lastErrorMessage ?? uploadFailedMessage
                if let progressToast {
                    AppToastManager.shared.update(progressToast, message: message, style: .error)
                } else {
                    AppToastManager.shared.show(message: message, style: .error)
                }
            }
        }
    }

    private var uploadActionTitle: String {
        "Upload to \(uploadConfiguration.provider.name)"
    }

    private var missingCredentialMessage: String {
        switch uploadConfiguration.provider {
        case .imgbb: NotinhasL10n.imgbbMissingAPIKey
        case .imageKit: NotinhasL10n.imageKitMissingPrivateKey
        }
    }

    private var uploadFailedMessage: String {
        switch uploadConfiguration.provider {
        case .imgbb: NotinhasL10n.imgbbUploadFailed
        case .imageKit: NotinhasL10n.imageKitUploadFailed
        }
    }

    private var uploadingMessage: String {
        L10n.Notinhas.uploadingTo(provider: uploadConfiguration.provider.name)
    }

    private var uploadedMessage: String {
        L10n.Notinhas.uploadedAndCopied(provider: uploadConfiguration.provider.name)
    }
}

// MARK: - Bottom Bar Button

struct BottomBarButton: View {
    let icon: String
    let tooltipTitle: String
    var tooltipKeys: [String] = []
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovering ? Color.primary.opacity(0.15) : Color.clear),
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .overlayTooltip(tooltipTitle, keys: tooltipKeys, edge: .above)
        .accessibilityLabel(
            tooltipKeys.isEmpty
                ? tooltipTitle
                : L10n.Common.withShortcut(tooltipTitle, tooltipKeys.joined(separator: "")),
        )
    }
}
