//
//  HistoryMainView.swift
//  Notinhas
//
//  Root SwiftUI view for the capture history browser
//

import AppKit
import SwiftUI

struct HistoryMainView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var store: CaptureHistoryStore
    @AppStorage(PreferencesKeys.historyBackgroundStyle) private var backgroundStyle: HistoryBackgroundStyle =
        .defaultStyle
    @StateObject private var viewModel: HistorySearchViewModel
    @State private var selectedIds: Set<UUID> = []
    private let thumbnailOverrides: [UUID: NSImage]

    init(
        store: CaptureHistoryStore = .shared,
        thumbnailOverrides: [UUID: NSImage] = [:]
    ) {
        self.store = store
        self.thumbnailOverrides = thumbnailOverrides
        _viewModel = StateObject(wrappedValue: HistorySearchViewModel(store: store))
    }

    private var filteredRecords: [CaptureHistoryRecord] {
        viewModel.filteredRecords
    }

    private var filteredRecordIDs: [UUID] {
        filteredRecords.map(\.id)
    }

    var body: some View {
        ZStack {
            HistoryBackdropView(style: backgroundStyle)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                HistoryToolbar(
                    searchText: $viewModel.searchText,
                    selectedCount: selectedRecords.count,
                    canSelectAll: selectedRecords.count < filteredRecords.count,
                    onSelectAll: selectAllFilteredRecords,
                    onClearSelection: { selectedIds.removeAll() },
                    onDeleteSelection: deleteSelectedRecords
                )

                HistoryFilterBar(
                    selectedFilter: $viewModel.selectedFilter,
                    counts: filterCounts
                )

                if filteredRecords.isEmpty {
                    HistoryEmptyStateView(
                        filter: viewModel.selectedFilter,
                        hasSearch: !viewModel.searchText.isEmpty
                    )
                } else {
                    HistoryGridView(
                        records: filteredRecords,
                        selectedIds: $selectedIds,
                        thumbnailOverrides: thumbnailOverrides
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 20)
        }
        .preferredColorScheme(themeManager.systemAppearance)
        .onReceive(NotificationCenter.default.publisher(for: .historyCopySelection)) { notification in
            guard notification.object is HistoryWindow else { return }
            copySelectedRecords()
        }
        .onReceive(NotificationCenter.default.publisher(for: .historyDeleteSelection)) { notification in
            guard notification.object is HistoryWindow else { return }
            deleteSelectedRecords()
        }
        .onReceive(NotificationCenter.default.publisher(for: .historySelectAll)) { notification in
            guard notification.object is HistoryWindow else { return }
            selectAllFilteredRecords()
        }
        .onChange(of: filteredRecordIDs) { ids in
            selectedIds.formIntersection(Set(ids))
        }
    }

    private var filterCounts: [CaptureHistoryType?: Int] {
        var counts: [CaptureHistoryType?: Int] = [:]
        counts[nil] = store.records.count
        counts[.screenshot] = store.records.filter { $0.captureType == .screenshot }.count
        counts[.video] = store.records.filter { $0.captureType == .video }.count
        counts[.gif] = store.records.filter { $0.captureType == .gif }.count
        return counts
    }

    private var selectedRecords: [CaptureHistoryRecord] {
        filteredRecords.filter { selectedIds.contains($0.id) }
    }

    private func copySelectedRecords() {
        HistoryWindowController.shared.copyToClipboard(selectedRecords)
    }

    private func selectAllFilteredRecords() {
        selectedIds = Set(filteredRecords.map(\.id))
    }

    private func deleteSelectedRecords() {
        let deletedCount = HistoryWindowController.shared.deleteRecords(
            selectedRecords,
            asksConfirmation: true
        )
        guard deletedCount > 0 else { return }
        selectedIds.removeAll()
    }
}

struct HistoryBackdropView: View {
    let style: HistoryBackgroundStyle
    var cornerRadius: CGFloat = 0
    var compact = false

    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            if compact {
                switch style {
                case .hud:
                    Color(white: 0.15)
                case .solid:
                    Color(nsColor: WindowSurfacePalette.backgroundColor(for: themeManager.preferredAppearance))
                }
            } else {
                switch style {
                case .hud:
                    Rectangle().fill(.ultraThinMaterial)
                    Rectangle().fill(hudTint)
                    glow(
                        color: Color.white.opacity(colorScheme == .dark ? 0.06 : 0.38),
                        width: 220,
                        height: 220,
                        x: -170,
                        y: -120
                    )
                    glow(
                        color: Color.black.opacity(colorScheme == .dark ? 0.08 : 0.03),
                        width: 240,
                        height: 240,
                        x: 180,
                        y: 130
                    )
                case .solid:
                    Color(nsColor: WindowSurfacePalette.backgroundColor(for: themeManager.preferredAppearance))
                }

                if style == .hud {
                    Rectangle()
                        .fill(surfaceTint)
                }
            }

            if compact {
                compactPreviewOverlay
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var hudTint: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    Color.white.opacity(0.05),
                    Color.black.opacity(0.12),
                    Color.white.opacity(0.03)
                ]
                : [
                    Color.white.opacity(0.18),
                    Color.black.opacity(0.05),
                    Color.white.opacity(0.12)
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var surfaceTint: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(colorScheme == .dark ? 0.05 : 0.24),
                Color.clear,
                Color.black.opacity(colorScheme == .dark ? 0.1 : 0.03)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var compactPreviewOverlay: some View {
        VStack(spacing: 0) {
            // Header: traffic lights, miniature filter pills, and circular action button
            HStack(spacing: 0) {
                HStack(spacing: 3) {
                    Circle().fill(Color.red.opacity(0.9)).frame(width: 3.5, height: 3.5)
                    Circle().fill(Color.yellow.opacity(0.9)).frame(width: 3.5, height: 3.5)
                    Circle().fill(Color.green.opacity(0.9)).frame(width: 3.5, height: 3.5)
                }
                .padding(.leading, 6)

                Spacer()

                HStack(spacing: 3) {
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: 10, height: 5)
                    Capsule()
                        .fill(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08))
                        .frame(width: 10, height: 5)
                    Capsule()
                        .fill(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08))
                        .frame(width: 10, height: 5)
                }

                Spacer()

                Circle()
                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08))
                    .frame(width: 5, height: 5)
                    .padding(.trailing, 6)
            }
            .frame(height: 14)
            .background(previewToolbarFill)

            // Content area: Symmetrical grid of capture items (landscape screenshot cards)
            HStack(spacing: 6) {
                ForEach(0 ..< 3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(previewCardFill.opacity(index == 0 ? 1.0 : 0.68))
                        .frame(width: 16, height: 26)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .stroke(previewWindowStroke, lineWidth: 0.5)
                        )
                }
            }
            .padding(.horizontal, 6)
            .padding(.top, 6)

            Spacer(minLength: 0)
        }
    }

    private var previewCardFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.78)
    }

    private var previewWindowStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
    }

    private var previewToolbarFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04)
    }

    private func glow(color: Color, width: CGFloat, height: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Ellipse()
            .fill(color)
            .frame(width: width, height: height)
            .blur(radius: compact ? 18 : 90)
            .offset(x: x, y: y)
    }
}

enum HistoryPreviewFixtures {
    private static let samples: [(
        fileName: String,
        captureType: CaptureHistoryType,
        fileSize: Int64,
        age: TimeInterval,
        width: Int,
        height: Int,
        duration: TimeInterval?
    )] = [
        ("design-handoff.png", .screenshot, 1_572_864, 3600, 1440, 900, nil),
        ("product-demo.mov", .video, 24_117_248, 86400, 1920, 1080, 42),
        ("animation.gif", .gif, 4_718_592, 172_800, 1280, 720, 8),
        ("nav-bar-states.png", .screenshot, 892_416, 259_200, 1512, 982, nil),
        ("onboarding-flow.mov", .video, 31_457_280, 345_600, 1920, 1080, 67),
        ("button-press.gif", .gif, 2_097_152, 432_000, 800, 600, 3),
        ("settings-panel.png", .screenshot, 1_048_576, 518_400, 1280, 800, nil),
        ("export-walkthrough.mov", .video, 18_874_368, 604_800, 1680, 1050, 28),
        ("pin-placement.gif", .gif, 3_145_728, 691_200, 1100, 720, 5),
        ("empty-history.png", .screenshot, 654_336, 777_600, 980, 640, nil),
        ("toolbar-variants.png", .screenshot, 1_310_720, 864_000, 1440, 900, nil),
        ("clipboard-ready.gif", .gif, 5_242_880, 950_400, 1280, 720, 12)
    ]

    static func make() -> (records: [CaptureHistoryRecord], thumbnails: [UUID: NSImage]) {
        let now = Date()
        let records = samples.map { sample in
            CaptureHistoryRecord(
                id: UUID(),
                filePath: "/preview/\(sample.fileName)",
                fileName: sample.fileName,
                captureType: sample.captureType,
                fileSize: sample.fileSize,
                capturedAt: now.addingTimeInterval(-sample.age),
                width: sample.width,
                height: sample.height,
                duration: sample.duration,
                thumbnailPath: nil,
                isDeleted: false
            )
        }

        let thumbnails = Dictionary(uniqueKeysWithValues: records.map { record in
            let symbolName = switch record.captureType {
            case .screenshot: "photo.fill"
            case .video: "film.fill"
            case .gif: "photo.stack.fill"
            }
            let image = NSImage(
                systemSymbolName: symbolName,
                accessibilityDescription: record.fileName
            ) ?? NSImage(size: NSSize(width: 1, height: 1))
            return (record.id, image)
        })

        return (records, thumbnails)
    }
}

#Preview("History window") {
    let fixtures = HistoryPreviewFixtures.make()

    HistoryMainView(
        store: .preview(records: fixtures.records),
        thumbnailOverrides: fixtures.thumbnails
    )
    .frame(width: 980, height: 640)
}
