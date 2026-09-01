//
//  AnnotateAnnotationToolType.swift
//  Notinhas
//
//  Enum defining all available annotation tools
//

import Foundation

/// Tool types available in annotation editor
nonisolated enum AnnotationToolType: String, CaseIterable, Identifiable {
    case selection
    case crop
    case rectangle
    case circle
    case arrow
    case line
    case magnify
    case text
    case highlighter
    case blur
    case spotlight
    case counter
    case cueNote = "notinhasNote"
    case watermark
    case pencil
    case mockup

    var id: String {
        rawValue
    }

    /// Annotation tools that create or edit drawable items on the image canvas.
    /// Shared by the full Annotate window and inline area-annotate overlay so the
    /// two surfaces stay in sync when tools are added.
    static let drawableTools: [AnnotationToolType] = [
        .rectangle, .circle, .arrow, .line, .magnify, .text, .highlighter,
        .blur, .spotlight, .cueNote, .watermark, .pencil,
    ]

    static let inlineAnnotateTools: [AnnotationToolType] = [.selection] + drawableTools

    private static let inlineShapeToolSet: Set<AnnotationToolType> = [
        .rectangle, .circle, .arrow, .line,
    ]

    static let inlineToolGroups: [[AnnotationToolType]] = [
        [.selection],
        drawableTools.filter { inlineShapeToolSet.contains($0) },
        drawableTools.filter { !inlineShapeToolSet.contains($0) },
    ]

    /// Tools that use the shared shape fill-style control.
    var supportsShapeFillStyle: Bool {
        switch self {
        case .rectangle, .circle:
            true
        default:
            false
        }
    }

    var icon: String {
        switch self {
        case .selection: "cursorarrow"
        case .crop: "crop"
        case .rectangle: "rectangle"
        case .circle: "circle"
        case .arrow: "arrow.up.right"
        case .line: "line.diagonal"
        case .magnify: "magnifyingglass"
        case .text: "character.textbox"
        case .highlighter: "highlighter"
        case .blur: "eye.slash"
        case .spotlight: "viewfinder"
        case .counter: "list.number"
        case .cueNote: "pin.circle.fill"
        case .watermark: "seal"
        case .pencil: "pencil"
        case .mockup: "cube.transparent"
        }
    }

    /// Default keyboard shortcut for this tool
    var defaultShortcut: Character {
        switch self {
        case .selection: "v"
        case .crop: "c"
        case .rectangle: "r"
        case .circle: "o"
        case .arrow: "a"
        case .line: "l"
        case .magnify: "g"
        case .text: "t"
        case .highlighter: "h"
        case .blur: "b"
        case .spotlight: "s"
        case .counter: "i"
        case .cueNote: "n"
        case .watermark: "w"
        case .pencil: "p"
        case .mockup: "m"
        }
    }

    /// Display name for the tool
    var displayName: String {
        switch self {
        case .selection: L10n.Annotate.selectionTool
        case .crop: L10n.Annotate.cropTool
        case .rectangle: L10n.Annotate.rectangleTool
        case .circle: L10n.Annotate.circleTool
        case .arrow: L10n.Annotate.arrowTool
        case .line: L10n.Annotate.lineTool
        case .magnify: L10n.Annotate.magnifyTool
        case .text: L10n.Annotate.textTool
        case .highlighter: L10n.Annotate.highlighterTool
        case .blur: L10n.Annotate.blurTool
        case .spotlight: L10n.Annotate.spotlightTool
        case .counter: L10n.Annotate.counterTool
        case .cueNote: CueL10n.noteTool
        case .watermark: L10n.Annotate.watermarkTool
        case .pencil: L10n.Annotate.pencilTool
        case .mockup: L10n.Annotate.mockupTool
        }
    }

    var supportsQuickPropertiesBar: Bool {
        switch self {
        case .rectangle, .circle, .arrow, .line, .magnify, .text, .highlighter,
             .blur, .spotlight, .counter,
             .cueNote, .watermark, .pencil:
            true
        case .selection, .crop, .mockup:
            false
        }
    }

    /// Drawable tools that should only commit a new blank-canvas item after a
    /// drag intent. Notinha stays click/drag-to-place, text keeps its click-to-edit
    /// flow, and freehand tools keep their existing path-count behavior.
    var requiresDragToCreateAnnotation: Bool {
        switch self {
        case .rectangle, .circle, .arrow, .line, .blur, .spotlight, .watermark:
            true
        case .selection, .crop, .text, .highlighter, .counter, .pencil, .mockup, .cueNote, .magnify:
            false
        }
    }

    var supportsQuickStrokeColor: Bool {
        switch self {
        case .rectangle, .circle, .arrow, .line, .magnify, .text, .highlighter,
             .counter, .watermark, .pencil,
             .cueNote:
            true
        case .selection, .crop, .blur, .spotlight, .mockup:
            false
        }
    }

    var supportsQuickFillColor: Bool {
        false
    }

    var supportsQuickStrokeWidth: Bool {
        switch self {
        case .rectangle, .circle, .arrow, .line, .magnify, .highlighter,
             .blur, .counter, .pencil, .cueNote:
            true
        case .selection, .crop, .text, .watermark, .spotlight, .mockup:
            false
        }
    }

    var supportsQuickMagnification: Bool {
        self == .magnify
    }

    var supportsQuickCornerRadius: Bool {
        switch self {
        case .rectangle, .text, .spotlight:
            true
        case .selection, .crop, .circle, .arrow, .line, .magnify, .highlighter,
             .blur, .counter, .watermark, .pencil, .mockup,
             .cueNote:
            false
        }
    }

    /// Maps legacy persisted tool ids onto current cases.
    static func migrating(fromRawValue rawValue: String) -> AnnotationToolType? {
        switch rawValue {
        case "filledRectangle":
            .rectangle
        case "oval":
            .circle
        default:
            AnnotationToolType(rawValue: rawValue)
        }
    }
}
