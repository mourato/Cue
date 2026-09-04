//
//  AllInOneCaptureMode.swift
//  Notinhas
//
//  Capture modes available in the All-In-One session toolbar.
//

import Foundation

enum AllInOneCaptureMode: String, CaseIterable, Identifiable, Equatable {
    case area
    case fullscreen
    case window
    case activeWindow
    case annotate
    case scrolling
    case timer
    case ocr
    case objectCutout
    case smartElement
    case recording

    var id: String {
        rawValue
    }

    static let defaultOrder: [AllInOneCaptureMode] = [
        .area, .fullscreen, .window, .activeWindow, .annotate, .scrolling, .timer, .ocr,
        .objectCutout, .smartElement, .recording,
    ]

    static let defaultEnabledModes: Set<AllInOneCaptureMode> = Set(defaultOrder)

    static func availableModes(videoEnabled: Bool) -> [AllInOneCaptureMode] {
        defaultOrder.filter { videoEnabled || $0 != .recording }
    }

    var systemImage: String {
        switch self {
        case .area: "rectangle.dashed"
        case .fullscreen: "rectangle.inset.filled"
        case .window: "macwindow"
        case .activeWindow: "macwindow.on.rectangle"
        case .annotate: "pencil.and.scribble"
        case .scrolling: "arrow.up.and.down"
        case .timer: "timer"
        case .ocr: "text.viewfinder"
        case .objectCutout: "person.crop.rectangle"
        case .smartElement: "dot.viewfinder"
        case .recording: "record.circle"
        }
    }

    var title: String {
        compactTitle
    }

    var compactTitle: String {
        switch self {
        case .area: L10n.AllInOne.modeArea
        case .fullscreen: L10n.AllInOne.modeFullscreen
        case .window: L10n.AllInOne.windowMode
        case .activeWindow: L10n.AllInOne.modeActiveWindow
        case .annotate: L10n.AllInOne.modeAnnotate
        case .scrolling: L10n.AllInOne.modeScrolling
        case .timer: L10n.AllInOne.modeTimer
        case .ocr: L10n.AllInOne.modeOCR
        case .objectCutout: L10n.AllInOne.modeObjectCutout
        case .smartElement: L10n.AllInOne.modeSmartElement
        case .recording: L10n.AllInOne.modeRecording
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .area: L10n.AllInOne.modeAreaAccessibility
        case .fullscreen: L10n.AllInOne.modeFullscreenAccessibility
        case .window: L10n.AllInOne.modeWindowAccessibility
        case .activeWindow: L10n.AllInOne.modeActiveWindowAccessibility
        case .annotate: L10n.AllInOne.modeAnnotateAccessibility
        case .scrolling: L10n.AllInOne.modeScrollingAccessibility
        case .timer: L10n.AllInOne.modeTimerAccessibility
        case .ocr: L10n.AllInOne.modeOCRAccessibility
        case .objectCutout: L10n.AllInOne.modeObjectCutoutAccessibility
        case .smartElement: L10n.AllInOne.modeSmartElementAccessibility
        case .recording: L10n.AllInOne.modeRecordingAccessibility
        }
    }

    var preservesSelectionRect: Bool {
        switch self {
        case .area, .annotate, .scrolling, .timer, .ocr, .recording:
            true
        case .fullscreen, .window, .activeWindow, .objectCutout, .smartElement:
            false
        }
    }

    var showsDimensionsBar: Bool {
        preservesSelectionRect
    }
}

enum AllInOneCaptureCommand: Equatable {
    case area(CGRect?)
    case fullscreen
    case window
    case activeWindow
    case annotate(CGRect?)
    case scrolling(CGRect?)
    case timer(CGRect?)
    case ocr(CGRect?)
    case objectCutout
    case smartElement
    case recording(CGRect?)

    static func make(for mode: AllInOneCaptureMode, rect: CGRect?) -> AllInOneCaptureCommand {
        switch mode {
        case .area: .area(rect)
        case .fullscreen: .fullscreen
        case .window: .window
        case .activeWindow: .activeWindow
        case .annotate: .annotate(rect)
        case .scrolling: .scrolling(rect)
        case .timer: .timer(rect)
        case .ocr: .ocr(rect)
        case .objectCutout: .objectCutout
        case .smartElement: .smartElement
        case .recording: .recording(rect)
        }
    }
}
