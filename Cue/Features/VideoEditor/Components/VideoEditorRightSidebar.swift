#if CUE_VIDEO_MODULE
//
    //  VideoEditorRightSidebar.swift
    //  Notinhas
//
    //  Sidebars for video editor background controls and zoom configuration
//

    import SwiftUI

    /// Left sidebar for background and canvas settings, matching the Annotate window pattern.
    struct VideoEditorLeftSidebar: View {
        @ObservedObject var state: VideoEditorState

        var body: some View {
            VideoBackgroundSidebarView(state: state)
                .frame(width: 240)
                .frame(maxHeight: .infinity)
        }
    }

    /// Right sidebar for zoom configuration and future item-specific properties.
    struct VideoEditorRightSidebar: View {
        @ObservedObject var state: VideoEditorState
        let previewImage: NSImage?

        var body: some View {
            ZoomSettingsContent(state: state, previewImage: previewImage)
                .frame(width: 320)
                .frame(maxHeight: .infinity)
        }
    }

    struct ZoomSettingsContent: View {
        @ObservedObject var state: VideoEditorState
        let previewImage: NSImage?

        @State private var localZoomLevel: CGFloat = ZoomSegment.defaultZoomLevel
        @State private var localCenter: CGPoint = .init(x: 0.5, y: 0.5)
        @State private var localAnchorMode: ZoomAnchorMode = .pointer
        @AppStorage(PreferencesKeys.videoEditorAutoGenerateZoomOnOpen)
        private var autoGenerateZoomOnOpen = true

        private struct LocalStateSnapshot: Equatable {
            let id: UUID
            let zoomType: ZoomType
            let zoomLevel: CGFloat
            let zoomCenter: CGPoint
            let anchorMode: ZoomAnchorMode
        }

        private var selectedSegment: ZoomSegment? {
            state.selectedZoomSegment
        }

        private var localStateSnapshot: LocalStateSnapshot? {
            guard let segment = selectedSegment else { return nil }
            return LocalStateSnapshot(
                id: segment.id,
                zoomType: segment.zoomType,
                zoomLevel: segment.zoomLevel,
                zoomCenter: segment.zoomCenter,
                anchorMode: segment.anchorMode,
            )
        }

        var body: some View {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {
                    if state.cameraMetadataWasInvalid {
                        Label(L10n.VideoEditor.cameraMetadataInvalid, systemImage: "exclamationmark.triangle")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isStaticText)
                    }
                    if state.recordingMetadata != nil {
                        recordingInteractionSection
                        Divider()
                        cursorSection
                        Divider()
                    }
                    if state.hasCameraTrack {
                        cameraOverlaySection
                        Divider()
                    }
                    if let segment = selectedSegment {
                        modeSection(for: segment)

                        Divider()

                        zoomLevelSection

                        if localAnchorMode == .pinned {
                            centerPickerSection
                        }

                        Divider()

                        actionsSection
                    } else {
                        emptyState
                    }

                    Spacer(minLength: 20)
                }
                .padding(12)
            }
            .frame(maxHeight: .infinity)
            .onAppear {
                syncLocalState()
            }
            .onChange(of: localStateSnapshot) {
                syncLocalState()
            }
        }

        private var recordingInteractionSection: some View {
            VStack(alignment: .leading, spacing: 10) {
                Label(L10n.VideoEditor.zoomEffects, systemImage: "cursorarrow.click")
                    .font(.system(size: 12, weight: .semibold))

                HStack {
                    Text(L10n.VideoEditor.recordedClicks)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(state.recordedClickCount)")
                        .font(.system(size: 11, weight: .medium))
                }

                HStack {
                    Text(L10n.VideoEditor.implicitZoomSegments)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(state.implicitZoomSegmentCount)")
                        .font(.system(size: 11, weight: .medium))
                }

                Toggle(isOn: $autoGenerateZoomOnOpen) {
                    Text(L10n.VideoEditor.autoGenerateZoomOnOpen)
                        .font(.system(size: 11))
                }
                .help(L10n.VideoEditor.autoGenerateZoomOnOpenHelp)

                Button(L10n.VideoEditor.resynthesizeImplicitZooms) {
                    state.resynthesizeImplicitZoomSegments()
                }
                .disabled(!state.canResynthesizeImplicitZoomSegments)
                .help(L10n.VideoEditor.resynthesizeImplicitZoomsHelp)
            }
            .accessibilityElement(children: .contain)
        }

        private var cursorSection: some View {
            VStack(alignment: .leading, spacing: 8) {
                Label(L10n.VideoEditor.cursor, systemImage: "cursorarrow")
                    .font(.system(size: 12, weight: .semibold))

                if state.canShowSyntheticCursor {
                    Toggle(isOn: $state.showsSyntheticCursor) {
                        Text(L10n.VideoEditor.showsSyntheticCursor)
                            .font(.system(size: 11))
                    }
                    .help(L10n.VideoEditor.showsSyntheticCursorHelp)

                    VideoSliderRow(
                        label: L10n.VideoEditor.cursorScale,
                        value: $state.cursorScale,
                        range: 1 ... 3,
                    )

                    Picker(L10n.VideoEditor.cursorSmoothing, selection: $state.cursorSmoothingPreset) {
                        Text(L10n.VideoEditor.cursorSmoothingOriginal)
                            .tag(VideoEditorCursorSmoothingPreset.original)
                        Text(L10n.VideoEditor.cursorSmoothingSmooth)
                            .tag(VideoEditorCursorSmoothingPreset.smooth)
                        Text(L10n.VideoEditor.cursorSmoothingFast)
                            .tag(VideoEditorCursorSmoothingPreset.fast)
                    }
                    .pickerStyle(.segmented)
                    .help(L10n.VideoEditor.cursorSmoothingHelp)
                } else if state.usesSyntheticPointer {
                    Text(L10n.VideoEditor.cursorDataUnavailable)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(L10n.VideoEditor.cursorBakedDescription)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if state.hasMouseTrackingData {
                    Divider()

                    Text(L10n.VideoEditor.syntheticOverlays)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)

                    Toggle(isOn: $state.showsClickEffects) {
                        Text(L10n.VideoEditor.showsClickEffects)
                            .font(.system(size: 11))
                    }

                    Toggle(isOn: $state.showsKeystrokes) {
                        Text(L10n.VideoEditor.showsKeystrokes)
                            .font(.system(size: 11))
                    }
                    .disabled(!state.hasRecordedKeystrokes)
                }
            }
            .accessibilityElement(children: .contain)
        }

        private var cameraOverlaySection: some View {
            VStack(alignment: .leading, spacing: 10) {
                Label(L10n.VideoEditor.cameraOverlay, systemImage: "video.fill")
                    .font(.system(size: 12, weight: .semibold))
                Toggle(L10n.VideoEditor.showCamera, isOn: $state.cameraOverlayLayout.isVisible)
                    .accessibilityValue(state.cameraOverlayLayout.isVisible ? L10n.Common.on : L10n.Common.off)
                if state.cameraOverlayLayout.isVisible {
                    Toggle(L10n.VideoEditor.cameraReactsToZoom, isOn: $state.cameraOverlayLayout.reactsToZoom)
                        .accessibilityValue(state.cameraOverlayLayout.reactsToZoom ? L10n.Common.on : L10n.Common.off)
                    Picker(L10n.VideoEditor.cameraPosition, selection: $state.cameraOverlayLayout.position) {
                        Text(L10n.VideoEditor.topLeading).tag(VideoEditorCameraOverlayPosition.topLeading)
                        Text(L10n.VideoEditor.topTrailing).tag(VideoEditorCameraOverlayPosition.topTrailing)
                        Text(L10n.VideoEditor.bottomLeading).tag(VideoEditorCameraOverlayPosition.bottomLeading)
                        Text(L10n.VideoEditor.bottomTrailing).tag(VideoEditorCameraOverlayPosition.bottomTrailing)
                    }
                    Picker(L10n.VideoEditor.cameraSize, selection: $state.cameraOverlayLayout.size) {
                        Text(L10n.VideoEditor.small).tag(VideoEditorCameraOverlaySize.small)
                        Text(L10n.VideoEditor.medium).tag(VideoEditorCameraOverlaySize.medium)
                        Text(L10n.VideoEditor.large).tag(VideoEditorCameraOverlaySize.large)
                    }
                }
            }
            .accessibilityElement(children: .contain)
        }

        private func modeSection(for segment: ZoomSegment) -> some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(L10n.VideoEditor.zoomItem, systemImage: "plus.magnifyingglass")
                        .font(.system(size: 12, weight: .semibold))

                    Spacer()

                    Text(segment.anchorMode.displayName)
                        .font(.system(size: 9, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background((segment.anchorMode == .pinned ? ZoomColors.primary : Color.green).opacity(0.18))
                        .foregroundColor(segment.anchorMode == .pinned ? ZoomColors.primary : .green)
                        .cornerRadius(4)
                }

                Picker(L10n.VideoEditor.anchorMode, selection: $localAnchorMode) {
                    Text(L10n.VideoEditor.anchorPointer)
                        .tag(ZoomAnchorMode.pointer)
                        .disabled(!state.hasMouseTrackingData)
                    Text(L10n.VideoEditor.anchorSmart)
                        .tag(ZoomAnchorMode.smart)
                        .disabled(!state.hasMouseTrackingData)
                    Text(L10n.VideoEditor.anchorPinned)
                        .tag(ZoomAnchorMode.pinned)
                }
                .pickerStyle(.segmented)
                .onChange(of: localAnchorMode) {
                    applyCameraBehavior()
                }

                if localAnchorMode == .pinned {
                    Text(L10n.VideoEditor.manualModeDescription)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                } else if state.hasMouseTrackingData {
                    Text(L10n.VideoEditor.followMouseActiveDescription)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    availabilityWarning
                }
            }
        }

        private var availabilityWarning: some View {
            VStack(alignment: .leading, spacing: 6) {
                Label(L10n.VideoEditor.mouseTrackingDataUnavailable, systemImage: "cursorarrow.slash")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                Text(L10n.VideoEditor.followMouseOnlyWorksWithCue)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.06))
            .cornerRadius(8)
        }

        private var emptyState: some View {
            VStack(spacing: 12) {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary.opacity(0.5))

                Text(L10n.VideoEditor.noZoomSelected)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)

                Text(L10n.VideoEditor.pressZToAddZoom)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        }

        private var zoomLevelSection: some View {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(L10n.VideoEditor.zoomLevel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(zoomDisplayValue(for: localZoomLevel))
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                }

                HStack(spacing: 8) {
                    Text("1x")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)

                    Slider(
                        value: $localZoomLevel.stepped(
                            by: 0.1,
                            in: ZoomSegment.minZoomLevel ... ZoomSegment.maxZoomLevel,
                        ),
                        in: ZoomSegment.minZoomLevel ... ZoomSegment.maxZoomLevel,
                    ) { isEditing in
                        if !isEditing {
                            applyZoomLevel()
                        }
                    }

                    Text("4x")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 4) {
                    ForEach([1.5, 2.0, 2.5, 3.0], id: \.self) { level in
                        Button {
                            localZoomLevel = level
                            applyZoomLevel()
                        } label: {
                            Text("\(String(format: "%.1f", level))x")
                                .font(.system(size: 9, weight: .medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    abs(localZoomLevel - level) < 0.05
                                        ? ZoomColors.primary.opacity(0.3)
                                        : Color.white.opacity(0.1),
                                )
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }

        private var centerPickerSection: some View {
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.VideoEditor.zoomCenter)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                ZoomCenterPicker(
                    center: $localCenter,
                    previewImage: previewImage,
                )
                .onChange(of: localCenter) {
                    applyCenter(localCenter)
                }

                HStack(spacing: 4) {
                    ForEach(centerPresets, id: \.name) { preset in
                        Button {
                            localCenter = preset.point
                            applyCenter(preset.point)
                        } label: {
                            Image(systemName: preset.icon)
                                .font(.system(size: 10))
                                .frame(width: 24, height: 24)
                                .background(
                                    isNearPreset(localCenter, preset.point)
                                        ? ZoomColors.primary.opacity(0.3)
                                        : Color.white.opacity(0.1),
                                )
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        .help(preset.name)
                    }
                }

                Text(L10n.VideoEditor.manualCameraControlOnlyInManualMode)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.8))
            }
        }

        private var actionsSection: some View {
            HStack(spacing: 8) {
                Button {
                    if let id = state.selectedZoomId {
                        state.toggleZoomEnabled(id: id)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: selectedSegment?.isEnabled == true ? "eye" : "eye.slash")
                        Text(selectedSegment?.isEnabled == true ? L10n.Common.enabled : L10n.Common.disabled)
                    }
                    .font(.system(size: 10))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(role: .destructive) {
                    if let id = state.selectedZoomId {
                        state.removeZoom(id: id)
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                        .padding(6)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
        }

        private struct CenterPreset {
            let name: String
            let icon: String
            let point: CGPoint
        }

        private var centerPresets: [CenterPreset] {
            [
                CenterPreset(name: L10n.VideoEditor.topLeft, icon: "arrow.up.left", point: CGPoint(x: 0.25, y: 0.25)),
                CenterPreset(name: L10n.VideoEditor.topRight, icon: "arrow.up.right", point: CGPoint(x: 0.75, y: 0.25)),
                CenterPreset(name: L10n.VideoEditor.center, icon: "circle", point: CGPoint(x: 0.5, y: 0.5)),
                CenterPreset(
                    name: L10n.VideoEditor.bottomLeft,
                    icon: "arrow.down.left",
                    point: CGPoint(x: 0.25, y: 0.75),
                ),
                CenterPreset(
                    name: L10n.VideoEditor.bottomRight,
                    icon: "arrow.down.right",
                    point: CGPoint(x: 0.75, y: 0.75),
                ),
            ]
        }

        private func isNearPreset(_ point: CGPoint, _ preset: CGPoint) -> Bool {
            abs(point.x - preset.x) < 0.1 && abs(point.y - preset.y) < 0.1
        }

        private func syncLocalState() {
            guard let segment = selectedSegment else { return }
            localZoomLevel = segment.zoomLevel
            localCenter = segment.zoomCenter
            localAnchorMode = segment.anchorMode
        }

        private func applyCameraBehavior() {
            guard let id = state.selectedZoomId else { return }
            switch localAnchorMode {
            case .pinned:
                state.updateZoom(id: id, zoomType: .manual, anchorMode: .pinned)
            case .pointer, .smart:
                guard state.hasMouseTrackingData else { return }
                state.updateZoom(id: id, zoomType: .auto, anchorMode: localAnchorMode)
            }
        }

        private func applyZoomLevel() {
            guard let id = state.selectedZoomId else { return }
            state.updateZoom(id: id, zoomLevel: localZoomLevel)
        }

        private func applyCenter(_ center: CGPoint) {
            guard let id = state.selectedZoomId else { return }
            state.updateZoom(id: id, zoomCenter: center)
        }

        private func zoomDisplayValue(for level: CGFloat) -> String {
            if level == floor(level) {
                return String(format: "%.0fx", level)
            }
            return String(format: "%.1fx", level)
        }
    }
#endif
