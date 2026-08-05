//
//  AnnotateChromeItem.swift
//  Notinhas
//
//  Stable identifiers for Annotate toolbar and bottom-bar customization.
//

import Foundation

enum AnnotateChromeItem: String, CaseIterable, Identifiable, Codable, Hashable {
    // Always-on (runtime anchors; not stored as disableable)
    case undo
    case redo
    case selection
    case done

    // Top chrome (customizable)
    case crop
    case addBackground
    case rotateLeft
    case rotateRight
    case backgroundCutout
    case saveAs

    // Drawing tools (customizable)
    case rectangle
    case filledRectangle
    case oval
    case arrow
    case line
    case text
    case highlighter
    case blur
    case spotlight
    case notinhasNote
    case watermark
    case pencil

    // Bottom actions (customizable)
    case newWindow
    case share
    case uploadToImgBB
    case uploadToCloud
    case pin
    case copy
    case delete

    var id: String {
        rawValue
    }

    static let alwaysOnItems: Set<AnnotateChromeItem> = [.undo, .redo, .selection, .done]

    static let defaultToolbarOrder: [AnnotateChromeItem] = [
        .crop,
        .addBackground,
        .rotateLeft,
        .rotateRight,
        .rectangle,
        .filledRectangle,
        .oval,
        .arrow,
        .line,
        .text,
        .highlighter,
        .blur,
        .spotlight,
        .notinhasNote,
        .watermark,
        .pencil,
        .backgroundCutout,
        .saveAs,
    ]

    static let defaultBottomOrder: [AnnotateChromeItem] = [
        .newWindow,
        .share,
        .uploadToImgBB,
        .uploadToCloud,
        .pin,
        .copy,
        .delete,
    ]

    static let defaultEnabledItems: Set<AnnotateChromeItem> = Set(defaultToolbarOrder + defaultBottomOrder)

    enum ToolbarGroup {
        case captureChrome
        case drawingOrCutout
        case trailing
    }

    var isCustomizable: Bool {
        !Self.alwaysOnItems.contains(self)
    }

    var toolbarGroup: ToolbarGroup? {
        switch self {
        case .crop, .addBackground, .rotateLeft, .rotateRight:
            .captureChrome
        case .rectangle, .filledRectangle, .oval, .arrow, .line, .text, .highlighter,
             .blur, .spotlight, .notinhasNote, .watermark, .pencil, .backgroundCutout:
            .drawingOrCutout
        case .saveAs:
            .trailing
        case .undo, .redo, .selection, .done, .newWindow, .share, .uploadToImgBB, .uploadToCloud, .pin, .copy, .delete:
            nil
        }
    }

    var annotationToolType: AnnotationToolType? {
        switch self {
        case .selection: .selection
        case .crop: .crop
        case .rectangle: .rectangle
        case .filledRectangle: .filledRectangle
        case .oval: .oval
        case .arrow: .arrow
        case .line: .line
        case .text: .text
        case .highlighter: .highlighter
        case .blur: .blur
        case .spotlight: .spotlight
        case .notinhasNote: .notinhasNote
        case .watermark: .watermark
        case .pencil: .pencil
        case .undo, .redo, .done, .addBackground, .rotateLeft, .rotateRight, .backgroundCutout, .saveAs,
             .newWindow, .share, .uploadToImgBB, .uploadToCloud, .pin, .copy, .delete:
            nil
        }
    }

    init?(annotationTool: AnnotationToolType) {
        switch annotationTool {
        case .selection: self = .selection
        case .crop: self = .crop
        case .rectangle: self = .rectangle
        case .filledRectangle: self = .filledRectangle
        case .oval: self = .oval
        case .arrow: self = .arrow
        case .line: self = .line
        case .text: self = .text
        case .highlighter: self = .highlighter
        case .blur: self = .blur
        case .spotlight: self = .spotlight
        case .notinhasNote: self = .notinhasNote
        case .watermark: self = .watermark
        case .pencil: self = .pencil
        case .counter, .mockup:
            return nil
        }
    }

    var settingsTitle: String {
        switch self {
        case .undo: L10n.Common.undo
        case .redo: L10n.Common.redo
        case .selection: L10n.Annotate.selectionTool
        case .done: L10n.Common.done
        case .crop: L10n.Annotate.cropTool
        case .addBackground: L10n.AnnotateUI.toggleSidebar
        case .rotateLeft: L10n.AnnotateUI.rotateLeft
        case .rotateRight: L10n.AnnotateUI.rotateRight
        case .backgroundCutout: L10n.AnnotateUI.backgroundCutoutTitle
        case .saveAs: L10n.Common.saveAs
        case .rectangle: L10n.Annotate.rectangleTool
        case .filledRectangle: L10n.Annotate.filledRectangleTool
        case .oval: L10n.Annotate.ovalTool
        case .arrow: L10n.Annotate.arrowTool
        case .line: L10n.Annotate.lineTool
        case .text: L10n.Annotate.textTool
        case .highlighter: L10n.Annotate.highlighterTool
        case .blur: L10n.Annotate.blurTool
        case .spotlight: L10n.Annotate.spotlightTool
        case .notinhasNote: NotinhasL10n.noteTool
        case .watermark: L10n.Annotate.watermarkTool
        case .pencil: L10n.Annotate.pencilTool
        case .newWindow: L10n.AnnotateUI.newWindow
        case .share: L10n.Common.share
        case .uploadToImgBB: NotinhasL10n.uploadToImgBB
        case .uploadToCloud: L10n.AnnotateUI.uploadToCloud
        case .pin: L10n.AnnotateUI.pinWindow
        case .copy: L10n.AnnotateUI.copyToClipboard
        case .delete: L10n.Common.deleteAction
        }
    }

    var systemImage: String {
        switch self {
        case .undo: "arrow.uturn.backward"
        case .redo: "arrow.uturn.forward"
        case .selection: "cursorarrow"
        case .done: "checkmark.circle"
        case .crop: "crop"
        case .addBackground: "rectangle.on.rectangle"
        case .rotateLeft: "rotate.left"
        case .rotateRight: "rotate.right"
        case .backgroundCutout: "wand.and.stars"
        case .saveAs: "square.and.arrow.down"
        case .rectangle: "rectangle"
        case .filledRectangle: "rectangle.fill"
        case .oval: "circle"
        case .arrow: "arrow.up.right"
        case .line: "line.diagonal"
        case .text: "character.textbox"
        case .highlighter: "highlighter"
        case .blur: "eye.slash"
        case .spotlight: "viewfinder"
        case .notinhasNote: "pin.circle.fill"
        case .watermark: "seal"
        case .pencil: "pencil"
        case .newWindow: "plus.rectangle.on.rectangle"
        case .share: "square.and.arrow.up"
        case .uploadToImgBB: "icloud.and.arrow.up"
        case .uploadToCloud: "cloud"
        case .pin: "pin"
        case .copy: "doc.on.doc"
        case .delete: "trash"
        }
    }
}
