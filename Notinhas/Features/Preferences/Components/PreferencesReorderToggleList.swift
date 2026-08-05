//
//  PreferencesReorderToggleList.swift
//  Notinhas
//
//  Shared drag-reorder + toggle list chrome for Preferences customization.
//

import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let preferencesReorder = UTType("com.mourato.notinhas.preferences-reorder") ?? .text
}

struct PreferencesReorderToggleList<
    Item: Identifiable & Hashable,
    Accessory: View,
    BodyDragPreview: View,
>: View {
    let items: [Item]
    let title: (Item) -> String
    let systemImage: (Item) -> String
    let isEnabled: (Item) -> Binding<Bool>
    let canReorder: (Item) -> Bool
    let canToggle: (Item) -> Bool
    let onMove: (IndexSet, Int) -> Void
    var resetTitle: String?
    var onReset: (() -> Void)?
    var reorderUTType: UTType = .preferencesReorder
    var reorderPayload: (Item) -> String
    @ViewBuilder var accessory: (Item) -> Accessory
    var bodyDragProvider: ((Item) -> NSItemProvider)?
    var onBodyDragBegan: (() -> Void)?
    var onReorderStateChanged: ((Bool) -> Void)?
    @ViewBuilder var bodyDragPreview: (Item) -> BodyDragPreview

    @State private var draggedItem: Item?
    @State private var activeDragID: UUID?
    @State private var mouseUpMonitor: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    PreferencesReorderToggleRow(
                        title: title(item),
                        systemImage: systemImage(item),
                        isEnabled: isEnabled(item),
                        canReorder: canReorder(item),
                        canToggle: canToggle(item),
                        isBeingReordered: draggedItem == item,
                        accessory: { accessory(item) },
                        reorderDragProvider: canReorder(item)
                            ? {
                                makeReorderDragProvider(for: item)
                            } : nil,
                        bodyDragProvider: bodyDragProvider.map { provider in
                            {
                                onBodyDragBegan?()
                                return provider(item)
                            }
                        },
                        bodyDragPreview: { bodyDragPreview(item) },
                        isReorderDragActive: draggedItem != nil,
                        dropTypes: [reorderUTType],
                        onDropEntered: {
                            guard let sourceItem = draggedItem,
                                  sourceItem != item,
                                  let sourceIndex = items.firstIndex(of: sourceItem) else { return }

                            if sourceIndex != index {
                                withAnimation(.default) {
                                    onMove(
                                        IndexSet(integer: sourceIndex),
                                        index > sourceIndex ? index + 1 : index,
                                    )
                                }
                            }
                        },
                        onDropPerformed: {
                            Task { @MainActor in
                                draggedItem = nil
                                onReorderStateChanged?(false)
                            }
                        },
                    )

                    if index < items.count - 1 {
                        Divider()
                    }
                }
            }
            .onAppear {
                mouseUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { event in
                    if draggedItem != nil {
                        draggedItem = nil
                        onReorderStateChanged?(false)
                    }
                    if activeDragID != nil {
                        activeDragID = nil
                    }
                    return event
                }
            }
            .onDisappear {
                if let monitor = mouseUpMonitor {
                    NSEvent.removeMonitor(monitor)
                    mouseUpMonitor = nil
                }
            }

            if let resetTitle, let onReset {
                HStack {
                    Spacer()
                    Button(resetTitle, action: onReset)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func makeReorderDragProvider(for item: Item) -> NSItemProvider {
        let dragID = UUID()
        activeDragID = dragID
        draggedItem = item
        onReorderStateChanged?(true)

        let provider = PreferencesReorderDragTrackingItemProvider()
        let data = reorderPayload(item).data(using: .utf8)
        if let data {
            provider.registerDataRepresentation(
                forTypeIdentifier: reorderUTType.identifier,
                visibility: .all,
            ) { completion in
                completion(data, nil)
                return nil
            }
        }

        provider.onDeinit = { [dragID] in
            Task { @MainActor in
                if activeDragID == dragID {
                    activeDragID = nil
                    draggedItem = nil
                    onReorderStateChanged?(false)
                }
            }
        }
        return provider
    }
}

extension PreferencesReorderToggleList where BodyDragPreview == EmptyView {
    init(
        items: [Item],
        title: @escaping (Item) -> String,
        systemImage: @escaping (Item) -> String,
        isEnabled: @escaping (Item) -> Binding<Bool>,
        canReorder: @escaping (Item) -> Bool,
        canToggle: @escaping (Item) -> Bool,
        onMove: @escaping (IndexSet, Int) -> Void,
        resetTitle: String? = nil,
        onReset: (() -> Void)? = nil,
        reorderUTType: UTType = .preferencesReorder,
        reorderPayload: @escaping (Item) -> String,
        @ViewBuilder accessory: @escaping (Item) -> Accessory,
    ) {
        self.items = items
        self.title = title
        self.systemImage = systemImage
        self.isEnabled = isEnabled
        self.canReorder = canReorder
        self.canToggle = canToggle
        self.onMove = onMove
        self.resetTitle = resetTitle
        self.onReset = onReset
        self.reorderUTType = reorderUTType
        self.reorderPayload = reorderPayload
        self.accessory = accessory
        bodyDragProvider = nil
        onBodyDragBegan = nil
        onReorderStateChanged = nil
        bodyDragPreview = { _ in EmptyView() }
    }
}

extension PreferencesReorderToggleList {
    init(
        items: [Item],
        title: @escaping (Item) -> String,
        systemImage: @escaping (Item) -> String,
        isEnabled: @escaping (Item) -> Binding<Bool>,
        canReorder: @escaping (Item) -> Bool,
        canToggle: @escaping (Item) -> Bool,
        onMove: @escaping (IndexSet, Int) -> Void,
        resetTitle: String? = nil,
        onReset: (() -> Void)? = nil,
        reorderUTType: UTType = .preferencesReorder,
        reorderPayload: @escaping (Item) -> String,
        @ViewBuilder accessory: @escaping (Item) -> Accessory,
        bodyDragProvider: @escaping (Item) -> NSItemProvider,
        onBodyDragBegan: (() -> Void)? = nil,
        onReorderStateChanged: ((Bool) -> Void)? = nil,
        @ViewBuilder bodyDragPreview: @escaping (Item) -> BodyDragPreview,
    ) {
        self.items = items
        self.title = title
        self.systemImage = systemImage
        self.isEnabled = isEnabled
        self.canReorder = canReorder
        self.canToggle = canToggle
        self.onMove = onMove
        self.resetTitle = resetTitle
        self.onReset = onReset
        self.reorderUTType = reorderUTType
        self.reorderPayload = reorderPayload
        self.accessory = accessory
        self.bodyDragProvider = bodyDragProvider
        self.onBodyDragBegan = onBodyDragBegan
        self.onReorderStateChanged = onReorderStateChanged
        self.bodyDragPreview = bodyDragPreview
    }
}

struct PreferencesReorderToggleRow<Accessory: View, BodyDragPreview: View>: View {
    let title: String
    let systemImage: String
    @Binding var isEnabled: Bool
    let canReorder: Bool
    let canToggle: Bool
    let isBeingReordered: Bool
    @ViewBuilder let accessory: () -> Accessory
    var reorderDragProvider: (() -> NSItemProvider)?
    var bodyDragProvider: (() -> NSItemProvider)?
    @ViewBuilder var bodyDragPreview: () -> BodyDragPreview
    var isReorderDragActive = false
    var dropTypes: [UTType] = []
    var onDropEntered: (() -> Void)?
    var onDropPerformed: (() -> Void)?

    @State private var isHandleHovered = false

    var body: some View {
        HStack(spacing: 6) {
            reorderHandle

            rowBody
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isBeingReordered ? Color(NSColor.selectedControlColor).opacity(0.15) : Color.clear)
        .opacity(isBeingReordered ? 0.35 : 1.0)
        .onDrop(
            of: dropTypes,
            delegate: PreferencesReorderDropDelegate(
                canAcceptDrop: { isReorderDragActive },
                onDropEntered: onDropEntered ?? {},
                onDropPerformed: onDropPerformed ?? {},
            ),
        )
    }

    @ViewBuilder
    private var reorderHandle: some View {
        if canReorder, let reorderDragProvider {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isHandleHovered ? .secondary : .quaternary)
                .frame(width: 14)
                .contentShape(Rectangle().inset(by: -4))
                .onHover { isHandleHovered = $0 }
                .onDrag {
                    reorderDragProvider()
                } preview: {
                    Color.clear.frame(width: 1, height: 1)
                }
        } else {
            Color.clear.frame(width: 14, height: 14)
        }
    }

    @ViewBuilder
    private var rowBody: some View {
        let label = HStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)

                Text(title)
                    .lineLimit(1)
            }

            Spacer()

            accessory()

            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .disabled(!canToggle)
        }

        if let bodyDragProvider {
            label
                .contentShape(Rectangle())
                .onDrag {
                    bodyDragProvider()
                } preview: {
                    bodyDragPreview()
                }
        } else {
            label
        }
    }
}

private struct PreferencesReorderDropDelegate: DropDelegate {
    let canAcceptDrop: () -> Bool
    let onDropEntered: () -> Void
    let onDropPerformed: () -> Void

    func validateDrop(info _: DropInfo) -> Bool {
        canAcceptDrop()
    }

    func dropEntered(info _: DropInfo) {
        onDropEntered()
    }

    func performDrop(info _: DropInfo) -> Bool {
        onDropPerformed()
        return true
    }

    func dropUpdated(info _: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

final class PreferencesReorderDragTrackingItemProvider: NSItemProvider {
    var onDeinit: (() -> Void)?

    deinit {
        onDeinit?()
    }
}
