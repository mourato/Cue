import Foundation

/// Data shown inside an overlay tooltip bubble.
struct OverlayTooltipContent: Equatable {
    /// Primary line, e.g. "Reload this page" or "Note".
    var title: String
    /// Keycap symbols shown as small pills, e.g. ["⌘", "R"]. Empty = text-only.
    var keys: [String] = []
    /// Optional secondary line under the title, e.g. a gesture hint.
    var secondary: String?
}

/// Which side of the anchor the tooltip prefers.
enum OverlayTooltipEdge: Equatable {
    case above
    case below
}
