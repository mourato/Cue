//
//  HistoryFloatingManager.swift
//  Notinhas
//
//  State management for the floating history panel
//

import AppKit
import Combine
import Foundation
import SwiftUI

/// Manages the floating history panel settings and display state
@MainActor
final class HistoryFloatingManager: ObservableObject {
    static let shared = HistoryFloatingManager()

    // MARK: - Published State

    @Published var position: HistoryPanelPosition = .topCenter {
        didSet {
            UserDefaults.standard.set(position.rawValue, forKey: Keys.position)
            panelController.updatePosition(position)
        }
    }

    @Published var isEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Keys.enabled)
            if !isEnabled {
                hide()
            }
        }
    }

    @Published var defaultFilter: CaptureHistoryType? = nil {
        didSet {
            if let filter = defaultFilter {
                UserDefaults.standard.set(filter.rawValue, forKey: Keys.defaultFilter)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.defaultFilter)
            }
        }
    }

    @Published var autoClearDays: Int = 0 {
        didSet {
            UserDefaults.standard.set(autoClearDays, forKey: Keys.autoClearDays)
        }
    }

    @Published var expandedFilter: CaptureHistoryType? = nil
    @Published var expandedTimeFilter: HistoryFloatingTimeFilter = .all
    @Published var searchText: String = ""

    // MARK: - Private

    private let panelController = HistoryFloatingPanelController()
    private lazy var panelContentView = HistoryFloatingContentView(manager: self)
    private var localEscapeMonitor: Any?
    private var globalEscapeMonitor: Any?
    private var modalInteractionSuppressionCount = 0
    private var isModalInteractionActive: Bool {
        modalInteractionSuppressionCount > 0
    }

    private enum Keys {
        static let enabled = "history.floating.enabled"
        static let position = "history.floating.position"
        static let defaultFilter = "history.floating.defaultFilter"
        static let autoClearDays = "history.floating.autoClearDays"
    }

    // MARK: - Init

    private init() {
        panelController.onPanelDidResignKey = { [weak self] in
            self?.handlePanelDidResignKey()
        }
        loadSettings()
    }

    private func loadSettings() {
        isEnabled = UserDefaults.standard.object(forKey: Keys.enabled) as? Bool ?? true

        if let positionRaw = UserDefaults.standard.string(forKey: Keys.position),
           let savedPosition = HistoryPanelPosition(rawValue: positionRaw) {
            position = savedPosition
        }

        if let filterRaw = UserDefaults.standard.string(forKey: Keys.defaultFilter),
           let filter = CaptureHistoryType(rawValue: filterRaw) {
            defaultFilter = filter
        }

        autoClearDays = UserDefaults.standard.object(forKey: Keys.autoClearDays) as? Int ?? 0
        expandedFilter = defaultFilter
        DiagnosticLogger.shared.log(
            .debug,
            .history,
            "Floating history settings loaded",
            context: [
                "enabled": isEnabled ? "true" : "false",
                "position": position.rawValue,
            ],
        )
    }

    // MARK: - Public Methods

    /// Toggle the floating history panel visibility
    func toggle() {
        DiagnosticLogger.shared.log(
            .info,
            .history,
            "Floating history toggled",
            context: [
                "isPresenting": panelController.isPresenting ? "true" : "false",
            ],
        )
        if panelController.isPresenting {
            hide()
        } else {
            showExpanded()
        }
    }

    /// Hide the floating history panel
    func hide() {
        removeEscapeMonitors()
        panelController.hide()
        DiagnosticLogger.shared.log(.debug, .history, "Floating history hidden")
    }

    func showExpanded(initialFilter: CaptureHistoryType? = nil) {
        resetState(initialFilter: initialFilter ?? expandedFilter ?? defaultFilter)
        DiagnosticLogger.shared.log(
            .info,
            .history,
            "Floating history expanded",
            context: ["filter": (initialFilter ?? expandedFilter ?? defaultFilter)?.rawValue ?? "all"],
        )
        presentPanel()
    }

    /// Refresh panel content if visible
    func refreshPanel() {
        guard panelController.isVisible else { return }
        DiagnosticLogger.shared.log(.debug, .history, "Floating history refreshed")
        presentPanel()
    }

    /// Check if panel is currently visible
    var isVisible: Bool {
        panelController.isVisible
    }

    func focusPanel() {
        panelController.focusPanel()
        DiagnosticLogger.shared.log(.debug, .history, "Floating history focused")
    }

    func performModalInteraction<Result>(_ action: () -> Result) -> Result {
        modalInteractionSuppressionCount += 1
        DiagnosticLogger.shared.log(
            .debug,
            .history,
            "Floating history modal interaction began",
            context: ["depth": "\(modalInteractionSuppressionCount)"],
        )
        let result = action()

        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.modalInteractionSuppressionCount = max(0, self.modalInteractionSuppressionCount - 1)
                DiagnosticLogger.shared.log(
                    .debug,
                    .history,
                    "Floating history modal interaction ended",
                    context: ["depth": "\(self.modalInteractionSuppressionCount)"],
                )
                if self.panelController.isPresenting {
                    self.focusPanel()
                }
            }
        }

        return result
    }

    private var preferredPanelSize: CGSize {
        HistoryFloatingLayout.panelSize(on: ScreenUtility.activeScreen())
    }

    private var preferredPosition: HistoryPanelPosition {
        position
    }

    private var preferredCornerRadius: CGFloat {
        HistoryFloatingLayout.baseCornerRadius
    }

    private func presentPanel() {
        panelController.show(
            panelContentView,
            size: preferredPanelSize,
            position: preferredPosition,
            cornerRadius: preferredCornerRadius,
        )
        setupEscapeMonitors()
        DiagnosticLogger.shared.log(
            .debug,
            .history,
            "Floating history presented",
            context: ["position": preferredPosition.rawValue],
        )
    }

    private func handlePanelDidResignKey() {
        guard !isModalInteractionActive else {
            DiagnosticLogger.shared.log(
                .debug,
                .history,
                "Floating history resign-key ignored during modal interaction",
            )
            return
        }
        hide()
    }

    private func resetState(initialFilter: CaptureHistoryType? = nil) {
        expandedFilter = initialFilter ?? defaultFilter
        expandedTimeFilter = .all
        searchText = ""
    }

    private func setupEscapeMonitors() {
        removeEscapeMonitors()

        localEscapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }
            guard self?.isModalInteractionActive == false else { return event }
            self?.hide()
            return nil
        }

        globalEscapeMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return }
            Task { @MainActor [weak self] in
                guard self?.isModalInteractionActive == false else { return }
                self?.hide()
            }
        }
    }

    private func removeEscapeMonitors() {
        if let localEscapeMonitor {
            NSEvent.removeMonitor(localEscapeMonitor)
            self.localEscapeMonitor = nil
        }

        if let globalEscapeMonitor {
            NSEvent.removeMonitor(globalEscapeMonitor)
            self.globalEscapeMonitor = nil
        }
    }
}

enum HistoryFloatingLayout {
    static let basePanelSize = CGSize(width: 1280, height: 360)
    static let baseCornerRadius: CGFloat = 32
    static let cardWidth: CGFloat = 232
    static let cardSpacing: CGFloat = 12
    static let contentHorizontalPadding: CGFloat = 20
    static let rowHorizontalPadding: CGFloat = 6

    /// Fixed panel size, clamped to fit small displays.
    static func panelSize(on screen: NSScreen = ScreenUtility.activeScreen()) -> CGSize {
        let safeFrame = screen.visibleFrame.insetBy(dx: 20, dy: 20)
        return CGSize(
            width: min(basePanelSize.width, safeFrame.width),
            height: min(basePanelSize.height, safeFrame.height),
        )
    }
}

enum HistoryFloatingTimeFilter: String, CaseIterable, Identifiable, Equatable {
    case all
    case last24Hours
    case last7Days
    case last30Days

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .all: "Any Time"
        case .last24Hours: "24H"
        case .last7Days: "7D"
        case .last30Days: "30D"
        }
    }

    func includes(_ date: Date, relativeTo now: Date = Date()) -> Bool {
        switch self {
        case .all:
            true
        case .last24Hours:
            date >= now.addingTimeInterval(-86_400)
        case .last7Days:
            date >= now.addingTimeInterval(-604_800)
        case .last30Days:
            date >= now.addingTimeInterval(-2_592_000)
        }
    }
}
