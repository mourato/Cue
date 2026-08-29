#if NOTINHAS_VIDEO_MODULE
//
    //  VideoEditorClipTimelineTrack.swift
    //  Notinhas
//
    //  Compact clip lane for split/delete/speed editing (Plan 110 / Phase C).
//

    import SwiftUI

    struct VideoEditorClipTimelineTrack: View {
        @ObservedObject var state: VideoEditorState
        let timelineWidth: CGFloat

        private let trackHeight: CGFloat = 28

        private var editorDuration: TimeInterval {
            max(state.clipTimeline.duration, 0.001)
        }

        var body: some View {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black.opacity(0.15))
                    .frame(height: trackHeight)

                HStack(spacing: 4) {
                    Image(systemName: "film")
                        .font(.system(size: 9))
                    Text(L10n.VideoEditor.clips)
                        .font(.system(size: 9, weight: .medium))
                    Spacer()
                }
                .foregroundColor(.secondary)
                .padding(.leading, 6)
                .allowsHitTesting(false)

                ForEach(state.clipTimeline.segments) { segment in
                    clipBlock(for: segment)
                }
            }
            .frame(height: trackHeight)
            .contentShape(Rectangle())
            .onTapGesture { location in
                handleTap(at: location)
            }
            .contextMenu { trackContextMenu }
        }

        private func clipBlock(for segment: VideoEditorClipSegment) -> some View {
            let start = editorStart(for: segment)
            let width = max(24, (segment.editorDuration / editorDuration) * timelineWidth)
            let x = (start / editorDuration) * timelineWidth
            let isSelected = state.selectedClipId == segment.id

            return RoundedRectangle(cornerRadius: 5)
                .fill(isSelected ? Color.accentColor.opacity(0.85) : Color.accentColor.opacity(0.55))
                .overlay(
                    HStack(spacing: 4) {
                        if abs(segment.speed - 1) > 0.001, width >= 40 {
                            Text(speedLabel(segment.speed))
                                .font(.system(size: 9, weight: .semibold))
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 4),
                )
                .frame(width: width, height: 24)
                .offset(x: x)
                .allowsHitTesting(false)
        }

        private func editorStart(for segment: VideoEditorClipSegment) -> TimeInterval {
            var offset: TimeInterval = 0
            for candidate in state.clipTimeline.segments {
                if candidate.id == segment.id {
                    break
                }
                offset += candidate.editorDuration
            }
            return offset
        }

        private func handleTap(at location: CGPoint) {
            let time = (location.x / timelineWidth) * editorDuration
            if let location = state.clipTimeline.location(at: time) {
                state.selectClip(id: location.segmentID)
            }
        }

        @ViewBuilder
        private var trackContextMenu: some View {
            Button {
                state.splitClipAtPlayhead()
            } label: {
                Label(L10n.VideoEditor.splitClipAtPlayhead, systemImage: "scissors")
            }

            Button {
                state.deleteSelectedClip()
            } label: {
                Label(L10n.VideoEditor.deleteClip, systemImage: "trash")
            }
            .disabled(!state.canDeleteSelectedClip)

            if let selected = state.selectedClipSegment {
                Divider()
                Menu {
                    ForEach([1.0, 1.5, 2.0, 3.0, 4.0, 8.0], id: \.self) { preset in
                        Button {
                            state.setClipSpeed(preset, forClipID: selected.id)
                        } label: {
                            Text(speedLabel(preset))
                        }
                    }
                } label: {
                    Label(L10n.VideoEditor.clipSpeed, systemImage: "gauge.with.dots.needle.67percent")
                }
            }

            if state.hasClipEdits || state.clipTimeline.hasPerClipSpeed {
                Divider()
                Button {
                    state.resetClipTimeline()
                } label: {
                    Label(L10n.VideoEditor.resetClips, systemImage: "arrow.counterclockwise")
                }
            }
        }

        private func speedLabel(_ speed: Double) -> String {
            speed == floor(speed) ? String(format: "%.0fx", speed) : String(format: "%.2gx", speed)
        }
    }
#endif
