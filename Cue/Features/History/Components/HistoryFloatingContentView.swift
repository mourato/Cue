//
//  HistoryFloatingContentView.swift
//  Notinhas
//
//  SwiftUI content for the floating history panel
//

import AppKit
import Combine
import SwiftUI

struct HistoryFloatingContentView: View {
    @ObservedObject var manager: HistoryFloatingManager
    @ObservedObject private var themeManager = ThemeManager.shared
    @AppStorage(PreferencesKeys.historyBackgroundStyle) private var backgroundStyle: HistoryBackgroundStyle =
        .defaultStyle
    @Environment(\.colorScheme) private var colorScheme

    @State private var expandedSelectedIds: Set<UUID> = []
    @State private var expandedLastSelectedId: UUID?
    @State private var rowScrollOffset: CGFloat = 0
    @State private var selectionRevealTrigger = 0
    @State private var dragTranslation: CGFloat = 0
    @State private var isHoveringRow = false
    @State private var isDraggingRow = false
    @State private var isRowReady = false
    @State private var rowWarmupTask: Task<Void, Never>?
    @StateObject private var searchViewModel: HistorySearchViewModel

    init(manager: HistoryFloatingManager) {
        self.manager = manager
        _searchViewModel = StateObject(wrappedValue: HistorySearchViewModel(
            searchTextPublisher: manager.$searchText.eraseToAnyPublisher(),
            selectedFilterPublisher: manager.$expandedFilter.eraseToAnyPublisher(),
            selectedTimeFilterPublisher: manager.$expandedTimeFilter.eraseToAnyPublisher(),
        ))
    }

    private var expandedRecords: [CaptureHistoryRecord] {
        searchViewModel.filteredRecords
    }

    private var expandedRecordIDs: [UUID] {
        expandedRecords.map(\.id)
    }

    private var expandedSelectedRecords: [CaptureHistoryRecord] {
        expandedRecords.filter { expandedSelectedIds.contains($0.id) }
    }

    private var panelSize: CGSize {
        HistoryFloatingLayout.panelSize(on: ScreenUtility.activeScreen())
    }

    var body: some View {
        expandedContent
            .frame(width: panelSize.width, height: panelSize.height)
            .background(HistoryBackdropView(style: backgroundStyle))
            .overlay(panelBorder)
            .preferredColorScheme(themeManager.systemAppearance)
            .onAppear {
                syncRowPresentation()
            }
            .onDisappear {
                rowWarmupTask?.cancel()
            }
            .onChange(of: expandedRecordIDs) { _ in
                pruneExpandedSelection()
                prefetchThumbnailsIfNeeded()
            }
            .onReceive(NotificationCenter.default.publisher(for: .historyCopySelection)) { notification in
                guard notification.object is HistoryFloatingPanel else { return }
                copySelectedRecord()
            }
            .onReceive(NotificationCenter.default.publisher(for: .historyActivateSelection)) { notification in
                guard notification.object is HistoryFloatingPanel else { return }
                openSelectedRecord()
            }
            .onReceive(NotificationCenter.default.publisher(for: .historyDeleteSelection)) { notification in
                guard notification.object is HistoryFloatingPanel else { return }
                deleteSelectedRecords()
            }
            .onReceive(NotificationCenter.default.publisher(for: .historySelectAll)) { notification in
                guard notification.object is HistoryFloatingPanel else { return }
                selectAllExpandedRecords()
            }
    }

    private var panelShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: HistoryFloatingLayout.baseCornerRadius,
            style: .continuous,
        )
    }

    private var panelBorder: some View {
        panelShape
            .strokeBorder(
                colorScheme == .dark
                    ? Color.white.opacity(0.1)
                    : Color.white.opacity(0.72),
                lineWidth: 1,
            )
    }

    // MARK: - Expanded

    private var expandedContent: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 18) {
                expandedHeader

                if expandedRecords.isEmpty {
                    expandedEmptyState
                } else if isRowReady {
                    historyRow
                } else {
                    historyRowPlaceholder
                }

                Spacer(minLength: 0)
            }

            if !expandedSelectedRecords.isEmpty {
                expandedSelectionBar
            }
        }
        .padding(.horizontal, HistoryFloatingLayout.contentHorizontalPadding)
        .padding(.top, 18)
        .padding(.bottom, 20)
    }

    private var expandedHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            expandedTypeFilters
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

            expandedSearchBar

            expandedTrailingControls
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var expandedTypeFilters: some View {
        HStack(spacing: 8) {
            ForEach(Array(captureTypeFilters.enumerated()), id: \.offset) { _, filter in
                selectionPill(
                    title: filter.title,
                    isSelected: manager.expandedFilter == filter.type,
                    horizontalPadding: 12,
                    verticalPadding: 8,
                    fontSize: 11,
                    minWidth: expandedTypeFilterMinWidth(for: filter.type),
                    action: {
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
                            manager.expandedFilter = filter.type
                        }
                    },
                )
            }
        }
    }

    private var expandedSearchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.9))

            TextField("Search captures", text: $manager.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .medium))

            if !manager.searchText.isEmpty {
                Button(action: { manager.searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .frame(width: 238)
        .background(chromeSurfaceFill, in: Capsule())
        .overlay(
            Capsule()
                .stroke(chromeSurfaceBorder, lineWidth: 1),
        )
        .shadow(color: chromeSurfaceShadow, radius: 7, x: 0, y: 3)
    }

    private var expandedTimeFilters: some View {
        HStack(spacing: 8) {
            ForEach(HistoryFloatingTimeFilter.allCases) { filter in
                selectionPill(
                    title: filter.title,
                    isSelected: manager.expandedTimeFilter == filter,
                    horizontalPadding: 12,
                    verticalPadding: 8,
                    fontSize: 11,
                    minWidth: expandedTimeFilterMinWidth(for: filter),
                    action: {
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
                            manager.expandedTimeFilter = filter
                        }
                    },
                )
            }
        }
    }

    private var expandedTrailingControls: some View {
        HStack(spacing: 8) {
            expandedTimeFilters

            controlButton(
                systemName: "xmark",
                help: L10n.Common.close,
                size: 34,
                action: manager.hide,
            )
        }
    }

    private var expandedSelectionBar: some View {
        HStack(spacing: 10) {
            Label(
                L10n.PreferencesHistory.selectedCaptures(expandedSelectedRecords.count),
                systemImage: "checkmark.circle.fill",
            )
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.primary.opacity(0.84))

            if expandedSelectedRecords.count < expandedRecords.count {
                selectionControlButton(
                    title: L10n.PreferencesHistory.selectAll,
                    systemName: "checkmark.circle",
                    action: selectAllExpandedRecords,
                )
            }

            selectionControlButton(
                title: L10n.PreferencesHistory.clearSelection,
                systemName: "xmark.circle",
                action: clearExpandedSelection,
            )

            selectionControlButton(
                title: L10n.Common.deleteAction,
                systemName: "trash",
                isDestructive: true,
                action: deleteSelectedRecords,
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial, in: Capsule())
        .background(selectionBarTint, in: Capsule())
        .overlay(
            Capsule()
                .stroke(selectionBarBorder, lineWidth: 1),
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.32 : 0.14), radius: 18, x: 0, y: 8)
        .fixedSize(horizontal: true, vertical: false)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.bottom, 4)
        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)))
    }

    // MARK: - Single horizontal row

    private var historyRow: some View {
        GeometryReader { geometry in
            let metrics = RowMetrics(
                viewportWidth: geometry.size.width,
                contentWidth: rowContentWidth,
            )
            let visibleOffset = clampedRowOffset(rowScrollOffset - dragTranslation, metrics: metrics)
            let centeredOffset = max((metrics.viewportWidth - metrics.contentWidth) / 2, 0)

            LazyHStack(spacing: HistoryFloatingLayout.cardSpacing) {
                ForEach(expandedRecords) { record in
                    HistoryExpandedCaptureCardView(
                        record: record,
                        isSelected: expandedSelectedIds.contains(record.id),
                        backgroundStyle: backgroundStyle,
                        onTap: {
                            selectExpandedRecord(record)
                        },
                    )
                    .equatable()
                    .frame(width: HistoryFloatingLayout.cardWidth)
                    .contextMenu {
                        HistoryContextMenu(record: record)
                    }
                }
            }
            .padding(.horizontal, HistoryFloatingLayout.rowHorizontalPadding)
            .padding(.vertical, 6)
            .offset(x: metrics.isScrollable ? -visibleOffset : centeredOffset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .contentShape(Rectangle())
            .simultaneousGesture(rowDragGesture(metrics: metrics))
            .background(
                HistoryRowTrackpadScrollObserver(isEnabled: metrics.isScrollable) { delta in
                    rowScrollOffset = clampedRowOffset(rowScrollOffset - delta, metrics: metrics)
                },
            )
            .clipped()
            .onAppear {
                clampRowScrollOffsetIfNeeded(metrics: metrics)
                updateRowCursor(for: metrics)
            }
            .onDisappear {
                isDraggingRow = false
                isHoveringRow = false
                dragTranslation = 0
                NSCursor.arrow.set()
            }
            .onHover { hovering in
                isHoveringRow = hovering
                updateRowCursor(for: metrics)
            }
            .onChange(of: metrics.viewportWidth) { _ in
                clampRowScrollOffsetIfNeeded(metrics: metrics)
                updateRowCursor(for: metrics)
            }
            .onChange(of: metrics.contentWidth) { _ in
                clampRowScrollOffsetIfNeeded(metrics: metrics)
                updateRowCursor(for: metrics)
            }
            .onChange(of: expandedRecordIDs) { _ in
                clampRowScrollOffsetIfNeeded(metrics: metrics)
            }
            .onChange(of: selectionRevealTrigger) { _ in
                revealSelectedRecordIfNeeded(metrics: metrics)
            }
        }
    }

    private var historyRowPlaceholder: some View {
        HStack(spacing: HistoryFloatingLayout.cardSpacing) {
            ForEach(0 ..< 6, id: \.self) { _ in
                VStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(placeholderFill)
                        .aspectRatio(16 / 10, contentMode: .fit)

                    VStack(alignment: .leading, spacing: 7) {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(placeholderFill)
                            .frame(height: 12)

                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(placeholderFill)
                                .frame(width: 96, height: 10)
                        }
                    }
                }
                .padding(10)
                .background(placeholderCardFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(placeholderStroke, lineWidth: 1),
                )
                .frame(width: HistoryFloatingLayout.cardWidth)
                .redacted(reason: .placeholder)
            }
        }
        .padding(.horizontal, HistoryFloatingLayout.rowHorizontalPadding)
        .padding(.vertical, 6)
    }

    private var expandedEmptyState: some View {
        HistoryEmptyStateView(
            filter: manager.expandedFilter,
            hasSearch: !manager.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        )
        .padding(.horizontal, 160)
        .padding(.bottom, 6)
    }

    // MARK: - Row scrolling

    private var rowContentWidth: CGFloat {
        guard !expandedRecords.isEmpty else { return 0 }
        let cardCount = CGFloat(expandedRecords.count)
        let spacingCount = CGFloat(max(expandedRecords.count - 1, 0))
        return (cardCount * HistoryFloatingLayout.cardWidth)
            + (spacingCount * HistoryFloatingLayout.cardSpacing)
            + (HistoryFloatingLayout.rowHorizontalPadding * 2)
    }

    private func rowDragGesture(metrics: RowMetrics) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                guard metrics.isScrollable else { return }
                dragTranslation = value.translation.width
                isDraggingRow = true
                updateRowCursor(for: metrics)
            }
            .onEnded { value in
                guard metrics.isScrollable else {
                    dragTranslation = 0
                    isDraggingRow = false
                    updateRowCursor(for: metrics)
                    return
                }

                rowScrollOffset = clampedRowOffset(rowScrollOffset - value.translation.width, metrics: metrics)
                dragTranslation = 0
                isDraggingRow = false
                updateRowCursor(for: metrics)
            }
    }

    private func revealSelectedRecordIfNeeded(metrics: RowMetrics) {
        guard metrics.isScrollable else {
            rowScrollOffset = 0
            return
        }

        guard let selectedId = expandedLastSelectedId,
              let selectedIndex = expandedRecords.firstIndex(where: { $0.id == selectedId })
        else {
            rowScrollOffset = clampedRowOffset(rowScrollOffset, metrics: metrics)
            return
        }

        let selectedLeading = HistoryFloatingLayout.rowHorizontalPadding
            + (CGFloat(selectedIndex) * (HistoryFloatingLayout.cardWidth + HistoryFloatingLayout.cardSpacing))
        let selectedTrailing = selectedLeading + HistoryFloatingLayout.cardWidth
        let visibleLeading = rowScrollOffset
        let visibleTrailing = rowScrollOffset + metrics.viewportWidth

        if selectedLeading < visibleLeading {
            rowScrollOffset = clampedRowOffset(selectedLeading, metrics: metrics)
        } else if selectedTrailing > visibleTrailing {
            rowScrollOffset = clampedRowOffset(selectedTrailing - metrics.viewportWidth, metrics: metrics)
        } else {
            rowScrollOffset = clampedRowOffset(rowScrollOffset, metrics: metrics)
        }
    }

    private func clampRowScrollOffsetIfNeeded(metrics: RowMetrics) {
        guard metrics.isScrollable else {
            rowScrollOffset = 0
            return
        }

        rowScrollOffset = clampedRowOffset(rowScrollOffset, metrics: metrics)
    }

    private func clampedRowOffset(_ offset: CGFloat, metrics: RowMetrics) -> CGFloat {
        min(max(offset, 0), metrics.maxScrollOffset)
    }

    private func updateRowCursor(for metrics: RowMetrics) {
        guard metrics.isScrollable else {
            NSCursor.arrow.set()
            return
        }

        if isDraggingRow {
            NSCursor.closedHand.set()
        } else if isHoveringRow {
            NSCursor.openHand.set()
        } else {
            NSCursor.arrow.set()
        }
    }

    // MARK: - Styling

    private var captureTypeFilters: [(title: String, type: CaptureHistoryType?)] {
        [
            ("All", nil),
            ("Screenshots", .screenshot),
            ("Videos", .video),
            ("GIFs", .gif),
        ]
    }

    private var selectedFilterBackground: AnyShapeStyle {
        AnyShapeStyle(
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(colorScheme == .dark ? 0.95 : 0.98),
                    Color.accentColor.opacity(colorScheme == .dark ? 0.82 : 0.9),
                ],
                startPoint: .top,
                endPoint: .bottom,
            ),
        )
    }

    private var chromeSurfaceFill: AnyShapeStyle {
        if backgroundStyle == .solid {
            return colorScheme == .dark
                ? AnyShapeStyle(Color.white.opacity(0.07))
                : AnyShapeStyle(Color.white.opacity(0.76))
        }

        return colorScheme == .dark
            ? AnyShapeStyle(Color.white.opacity(0.07))
            : AnyShapeStyle(Color.white.opacity(0.52))
    }

    private var chromeSurfaceBorder: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.64)
    }

    private var chromeSurfaceShadow: Color {
        Color.black.opacity(colorScheme == .dark ? 0.18 : 0.07)
    }

    private var selectionBarTint: Color {
        colorScheme == .dark ? Color.black.opacity(0.18) : Color.white.opacity(0.42)
    }

    private var selectionBarBorder: Color {
        colorScheme == .dark ? Color.white.opacity(0.16) : Color.white.opacity(0.7)
    }

    private var unselectedPillBackground: AnyShapeStyle {
        colorScheme == .dark
            ? AnyShapeStyle(Color.white.opacity(0.08))
            : AnyShapeStyle(Color.black.opacity(0.05))
    }

    private var controlButtonBackground: AnyShapeStyle {
        colorScheme == .dark
            ? AnyShapeStyle(Color.white.opacity(0.08))
            : AnyShapeStyle(Color.white.opacity(0.72))
    }

    private var placeholderFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
    }

    private var placeholderCardFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white.opacity(0.64)
    }

    private var placeholderStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.05)
    }

    // MARK: - Helpers

    private func selectionPill(
        title: String,
        isSelected: Bool,
        horizontalPadding: CGFloat = 12,
        verticalPadding: CGFloat = 7,
        fontSize: CGFloat = 12,
        minWidth: CGFloat? = nil,
        action: @escaping () -> Void,
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: fontSize, weight: .semibold))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .foregroundColor(isSelected ? .white : .primary.opacity(0.82))
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .frame(minWidth: minWidth)
                .background(isSelected ? selectedFilterBackground : unselectedPillBackground)
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected
                                ? Color.white.opacity(0.08)
                                : chromeSurfaceBorder.opacity(colorScheme == .dark ? 0.45 : 0.7),
                            lineWidth: 1,
                        ),
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func controlButton(
        systemName: String,
        help: String,
        size: CGFloat = 30,
        action: @escaping () -> Void,
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size <= 34 ? 10.5 : 11, weight: .semibold))
                .frame(width: size, height: size)
                .background(controlButtonBackground)
                .foregroundColor(.primary.opacity(0.86))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func selectionControlButton(
        title: String,
        systemName: String,
        isDestructive: Bool = false,
        action: @escaping () -> Void,
    ) -> some View {
        Button(role: isDestructive ? .destructive : nil, action: action) {
            Label(title, systemImage: systemName)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(.plain)
        .foregroundColor(isDestructive ? .red : .primary.opacity(0.82))
    }

    private func selectExpandedRecord(_ record: CaptureHistoryRecord) {
        let flags = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if flags.contains(.shift) {
            if let expandedLastSelectedId,
               let startIndex = expandedRecords.firstIndex(where: { $0.id == expandedLastSelectedId }),
               let endIndex = expandedRecords.firstIndex(where: { $0.id == record.id }) {
                let range = min(startIndex, endIndex) ... max(startIndex, endIndex)
                expandedSelectedIds.formUnion(expandedRecords[range].map(\.id))
            } else {
                expandedSelectedIds.insert(record.id)
                expandedLastSelectedId = record.id
            }
        } else if flags.contains(.command) {
            if expandedSelectedIds.contains(record.id) {
                expandedSelectedIds.remove(record.id)
            } else {
                expandedSelectedIds.insert(record.id)
            }
            expandedLastSelectedId = record.id
        } else {
            expandedSelectedIds = [record.id]
            expandedLastSelectedId = record.id
        }

        selectionRevealTrigger += 1
        manager.focusPanel()
    }

    private func selectAllExpandedRecords() {
        expandedSelectedIds = Set(expandedRecords.map(\.id))
        expandedLastSelectedId = expandedRecords.last?.id
    }

    private func clearExpandedSelection() {
        expandedSelectedIds.removeAll()
        expandedLastSelectedId = nil
    }

    private func pruneExpandedSelection() {
        let visibleIds = Set(expandedRecordIDs)
        expandedSelectedIds.formIntersection(visibleIds)

        if let expandedLastSelectedId, !visibleIds.contains(expandedLastSelectedId) {
            self.expandedLastSelectedId = expandedSelectedIds.first
        }
    }

    private func copySelectedRecord() {
        let records = expandedSelectedRecords
        guard !records.isEmpty else { return }
        HistoryWindowController.shared.copyToClipboard(records)
    }

    private func openSelectedRecord() {
        if expandedSelectedRecords.count == 1, let record = expandedSelectedRecords.first {
            HistoryWindowController.shared.openItem(record)
        }
    }

    private func deleteSelectedRecords() {
        let deletedCount = HistoryWindowController.shared.deleteRecords(
            expandedSelectedRecords,
            asksConfirmation: true,
        )
        guard deletedCount > 0 else { return }

        clearExpandedSelection()
    }

    private func expandedTypeFilterMinWidth(for filter: CaptureHistoryType?) -> CGFloat {
        switch filter {
        case .screenshot:
            108
        case .video:
            78
        case .gif:
            70
        case nil:
            62
        }
    }

    private func expandedTimeFilterMinWidth(for filter: HistoryFloatingTimeFilter) -> CGFloat {
        switch filter {
        case .all:
            84
        case .last24Hours:
            58
        case .last7Days, .last30Days:
            54
        }
    }

    private func prefetchThumbnailsIfNeeded() {
        guard !expandedRecords.isEmpty else { return }
        HistoryThumbnailGenerator.shared.preloadThumbnails(for: Array(expandedRecords.prefix(10)))
    }

    private func syncRowPresentation() {
        rowWarmupTask?.cancel()

        prefetchThumbnailsIfNeeded()

        guard !expandedRecords.isEmpty else {
            isRowReady = true
            return
        }

        isRowReady = false
        rowWarmupTask = Task {
            try? await Task.sleep(nanoseconds: 140_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                isRowReady = true
            }
        }
    }
}

private struct RowMetrics: Equatable {
    let viewportWidth: CGFloat
    let contentWidth: CGFloat

    var maxScrollOffset: CGFloat {
        max(contentWidth - viewportWidth, 0)
    }

    var isScrollable: Bool {
        maxScrollOffset > 1
    }
}

private struct HistoryRowTrackpadScrollObserver: NSViewRepresentable {
    let isEnabled: Bool
    let onScroll: (CGFloat) -> Void

    func makeNSView(context _: Context) -> HistoryRowTrackpadScrollView {
        let view = HistoryRowTrackpadScrollView()
        view.isEnabled = isEnabled
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: HistoryRowTrackpadScrollView, context _: Context) {
        nsView.isEnabled = isEnabled
        nsView.onScroll = onScroll
    }

    static func dismantleNSView(_ nsView: HistoryRowTrackpadScrollView, coordinator _: ()) {
        nsView.cleanup()
    }
}

private final class HistoryRowTrackpadScrollView: NSView {
    var isEnabled = false
    var onScroll: ((CGFloat) -> Void)?

    private var monitor: Any?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        installMonitorIfNeeded()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func cleanup() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    private func installMonitorIfNeeded() {
        guard monitor == nil else { return }

        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self else { return event }
            return handleScrollEvent(event) ? nil : event
        }
    }

    private func handleScrollEvent(_ event: NSEvent) -> Bool {
        guard isEnabled, let window, event.window === window else { return false }
        guard !event.modifierFlags.contains(.command) else { return false }

        let location = convert(event.locationInWindow, from: nil)
        guard bounds.contains(location) else { return false }

        let multiplier: CGFloat = event.hasPreciseScrollingDeltas ? 1 : 18
        let dominantDelta = abs(event.scrollingDeltaX) > 0.5
            ? CGFloat(event.scrollingDeltaX)
            : CGFloat(event.scrollingDeltaY)
        let delta = dominantDelta * multiplier

        guard abs(delta) > 0.5 else { return false }
        onScroll?(delta)
        return true
    }
}
