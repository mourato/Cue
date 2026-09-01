import Foundation

nonisolated enum NotinhasNotesPanelSide: String, Codable, CaseIterable, Identifiable {
    case left
    case right

    var id: String {
        rawValue
    }

    static let `default` = NotinhasNotesPanelSide.left

    static func resolved(from rawValue: String?) -> NotinhasNotesPanelSide {
        guard let rawValue, let side = NotinhasNotesPanelSide(rawValue: rawValue) else {
            return .default
        }
        return side
    }
}
