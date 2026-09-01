//
//  AllInOneCaptureModeConfigurationStore.swift
//  Notinhas
//
//  UserDefaults-backed All-In-One mode order and visibility.
//

import Combine
import Foundation

@MainActor
final class AllInOneCaptureModeConfigurationStore: ObservableObject {
    static let shared = AllInOneCaptureModeConfigurationStore()

    @Published private(set) var modeOrder: [AllInOneCaptureMode]
    @Published private(set) var enabledModes: Set<AllInOneCaptureMode>

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        modeOrder = Self.normalizedOrder(from: defaults.stringArray(forKey: PreferencesKeys.captureAllInOneModeOrder))
        enabledModes = Self.normalizedEnabledModes(
            from: defaults.stringArray(forKey: PreferencesKeys.captureAllInOneEnabledModes),
        )
        save()
    }

    func orderedModes(videoEnabled: Bool, includeDisabled: Bool) -> [AllInOneCaptureMode] {
        modeOrder.filter { mode in
            (videoEnabled || mode != .recording) && (includeDisabled || enabledModes.contains(mode))
        }
    }

    func isEnabled(_ mode: AllInOneCaptureMode) -> Bool {
        enabledModes.contains(mode)
    }

    func canToggle(_ mode: AllInOneCaptureMode) -> Bool {
        mode == .recording || !enabledModes.contains(mode) || enabledModes.count(where: { $0 != .recording }) > 1
    }

    func setEnabled(_ mode: AllInOneCaptureMode, enabled: Bool) {
        guard enabled || canToggle(mode) else { return }
        if enabled {
            enabledModes.insert(mode)
        } else {
            enabledModes.remove(mode)
        }
        save()
    }

    func moveMode(from source: IndexSet, to destination: Int, videoEnabled: Bool) {
        let visible = orderedModes(videoEnabled: videoEnabled, includeDisabled: true)
        guard !source.isEmpty,
              source.allSatisfy({ $0 < visible.count }) else { return }

        var reordered = visible
        let movingModes = source.sorted().map { reordered[$0] }
        for index in source.sorted(by: >) {
            reordered.remove(at: index)
        }
        let removedBeforeDestination = source.filter { $0 < destination }.count
        let insertionIndex = max(0, min(destination - removedBeforeDestination, reordered.count))
        reordered.insert(contentsOf: movingModes, at: insertionIndex)

        var updatedOrder = modeOrder
        let availableIndices = modeOrder.indices.filter { index in
            videoEnabled || modeOrder[index] != .recording
        }
        guard availableIndices.count == reordered.count else { return }
        for (index, mode) in zip(availableIndices, reordered) {
            updatedOrder[index] = mode
        }
        modeOrder = Self.normalizedOrder(from: updatedOrder.map(\.rawValue))
        save()
    }

    func resetToDefaults() {
        modeOrder = AllInOneCaptureMode.defaultOrder
        enabledModes = AllInOneCaptureMode.defaultEnabledModes
        save()
    }

    private func save() {
        defaults.set(modeOrder.map(\.rawValue), forKey: PreferencesKeys.captureAllInOneModeOrder)
        defaults.set(enabledModes.map(\.rawValue).sorted(), forKey: PreferencesKeys.captureAllInOneEnabledModes)
    }

    private static func normalizedOrder(from rawIDs: [String]?) -> [AllInOneCaptureMode] {
        var seen = Set<AllInOneCaptureMode>()
        var order: [AllInOneCaptureMode] = []
        for rawID in rawIDs ?? [] {
            guard let mode = AllInOneCaptureMode(rawValue: rawID), seen.insert(mode).inserted else { continue }
            order.append(mode)
        }
        for mode in AllInOneCaptureMode.defaultOrder where seen.insert(mode).inserted {
            order.append(mode)
        }
        return order
    }

    private static func normalizedEnabledModes(from rawIDs: [String]?) -> Set<AllInOneCaptureMode> {
        var enabled = rawIDs.map { Set($0.compactMap(AllInOneCaptureMode.init(rawValue:))) }
            ?? AllInOneCaptureMode.defaultEnabledModes
        if !enabled.contains(where: { $0 != .recording }) {
            enabled.insert(AllInOneCaptureMode.defaultOrder.first { $0 != .recording }!)
        }
        return enabled
    }
}
