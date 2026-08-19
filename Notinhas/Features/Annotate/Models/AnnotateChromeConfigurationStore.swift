//
//  AnnotateChromeConfigurationStore.swift
//  Notinhas
//
//  UserDefaults-backed Annotate toolbar and bottom-bar order and visibility.
//

import Combine
import Foundation

@MainActor
final class AnnotateChromeConfigurationStore: ObservableObject {
    static let shared = AnnotateChromeConfigurationStore()

    @Published private(set) var toolbarItemOrder: [AnnotateChromeItem]
    @Published private(set) var bottomActionOrder: [AnnotateChromeItem]
    @Published private(set) var enabledItems: Set<AnnotateChromeItem>

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        toolbarItemOrder = Self.normalizedToolbarOrder(
            from: defaults.stringArray(forKey: PreferencesKeys.annotateChromeToolbarOrder),
        )
        bottomActionOrder = Self.normalizedBottomOrder(
            from: defaults.stringArray(forKey: PreferencesKeys.annotateChromeBottomOrder),
        )
        enabledItems = Self.normalizedEnabledItems(
            from: defaults.stringArray(forKey: PreferencesKeys.annotateChromeEnabledItems),
        )
    }

    func isEnabled(_ item: AnnotateChromeItem) -> Bool {
        if AnnotateChromeItem.alwaysOnItems.contains(item) {
            return true
        }
        return enabledItems.contains(item)
    }

    func orderedToolbarItems(in group: AnnotateChromeItem.ToolbarGroup,
                             includeDisabled: Bool = false) -> [AnnotateChromeItem] {
        toolbarItemOrder.filter { item in
            item.toolbarGroup == group && (includeDisabled || isEnabled(item))
        }
    }

    func orderedBottomActions(includeDisabled: Bool = false) -> [AnnotateChromeItem] {
        guard includeDisabled else {
            return bottomActionOrder.filter { isEnabled($0) }
        }
        return bottomActionOrder
    }

    func effectiveDrawableTools() -> [AnnotationToolType] {
        toolbarItemOrder
            .filter { $0.toolbarGroup == .drawingOrCutout && isEnabled($0) }
            .compactMap(\.annotationToolType)
    }

    func inlineToolGroups() -> [[AnnotationToolType]] {
        let drawable = effectiveDrawableTools()
        guard !drawable.isEmpty else {
            return [[.selection]]
        }
        return [[.selection], drawable]
    }

    func setEnabled(_ item: AnnotateChromeItem, enabled: Bool) {
        guard item.isCustomizable else { return }

        var updated = enabledItems
        if enabled {
            updated.insert(item)
        } else {
            updated.remove(item)
        }
        enabledItems = Self.normalizedEnabledItems(from: updated.map(\.rawValue))
        save()
    }

    func moveToolbarItem(from source: IndexSet, to destination: Int) {
        moveItems(
            in: &toolbarItemOrder,
            customizableOrder: AnnotateChromeItem.defaultToolbarOrder,
            from: source,
            to: destination,
        )
        toolbarItemOrder = Self.normalizedToolbarOrder(from: toolbarItemOrder.map(\.rawValue))
        save()
    }

    func moveBottomAction(from source: IndexSet, to destination: Int) {
        moveItems(
            in: &bottomActionOrder,
            customizableOrder: AnnotateChromeItem.defaultBottomOrder,
            from: source,
            to: destination,
        )
        bottomActionOrder = Self.normalizedBottomOrder(from: bottomActionOrder.map(\.rawValue))
        save()
    }

    func resetToDefaults() {
        toolbarItemOrder = AnnotateChromeItem.defaultToolbarOrder
        bottomActionOrder = AnnotateChromeItem.defaultBottomOrder
        enabledItems = AnnotateChromeItem.defaultEnabledItems
        save()
    }

    func applyConfiguration(
        toolbarOrder: [AnnotateChromeItem]?,
        bottomOrder: [AnnotateChromeItem]?,
        enabledItems: Set<AnnotateChromeItem>?,
    ) {
        if let toolbarOrder {
            toolbarItemOrder = Self.normalizedToolbarOrder(from: toolbarOrder.map(\.rawValue))
        }
        if let bottomOrder {
            bottomActionOrder = Self.normalizedBottomOrder(from: bottomOrder.map(\.rawValue))
        }
        if let enabledItems {
            self.enabledItems = Self.normalizedEnabledItems(from: enabledItems.map(\.rawValue))
        }
        save()
    }

    func isToolEnabled(_ tool: AnnotationToolType) -> Bool {
        guard let item = AnnotateChromeItem(annotationTool: tool) else { return true }
        return isEnabled(item)
    }

    private func moveItems(
        in order: inout [AnnotateChromeItem],
        customizableOrder _: [AnnotateChromeItem],
        from source: IndexSet,
        to destination: Int,
    ) {
        guard !source.isEmpty else { return }

        let movingItems = source.sorted().map { order[$0] }
        var updatedOrder = order
        for index in source.sorted(by: >) {
            updatedOrder.remove(at: index)
        }

        let removedBeforeDestination = source.filter { $0 < destination }.count
        let insertionIndex = max(0, min(destination - removedBeforeDestination, updatedOrder.count))
        updatedOrder.insert(contentsOf: movingItems, at: insertionIndex)
        order = updatedOrder
    }

    private func save() {
        defaults.set(toolbarItemOrder.map(\.rawValue), forKey: PreferencesKeys.annotateChromeToolbarOrder)
        defaults.set(bottomActionOrder.map(\.rawValue), forKey: PreferencesKeys.annotateChromeBottomOrder)
        defaults.set(
            (toolbarItemOrder + bottomActionOrder).filter { enabledItems.contains($0) }.map(\.rawValue),
            forKey: PreferencesKeys.annotateChromeEnabledItems,
        )
    }

    private static func normalizedToolbarOrder(from rawIDs: [String]?) -> [AnnotateChromeItem] {
        normalizedOrder(from: rawIDs, defaults: AnnotateChromeItem.defaultToolbarOrder) {
            AnnotateChromeItem.defaultToolbarOrder.contains($0)
        }
    }

    private static func normalizedBottomOrder(from rawIDs: [String]?) -> [AnnotateChromeItem] {
        normalizedOrder(from: rawIDs, defaults: AnnotateChromeItem.defaultBottomOrder) {
            AnnotateChromeItem.defaultBottomOrder.contains($0)
        }
    }

    private static func normalizedOrder(
        from rawIDs: [String]?,
        defaults defaultOrder: [AnnotateChromeItem],
        isAllowed: (AnnotateChromeItem) -> Bool,
    ) -> [AnnotateChromeItem] {
        var seen = Set<AnnotateChromeItem>()
        var ordered: [AnnotateChromeItem] = []

        for rawID in rawIDs ?? [] {
            guard let item = AnnotateChromeItem.migrating(fromRawValue: rawID),
                  isAllowed(item),
                  !seen.contains(item) else { continue }
            ordered.append(item)
            seen.insert(item)
        }

        for item in defaultOrder where !seen.contains(item) {
            ordered.append(item)
            seen.insert(item)
        }

        return ordered
    }

    private static func normalizedEnabledItems(from rawIDs: [String]?) -> Set<AnnotateChromeItem> {
        guard let rawIDs else {
            return AnnotateChromeItem.defaultEnabledItems
        }

        var enabled = Set(rawIDs.compactMap(AnnotateChromeItem.migrating(fromRawValue:)))
        enabled.formUnion(AnnotateChromeItem.alwaysOnItems)
        return enabled
    }
}
