import Foundation

nonisolated enum CueNotesPanelSide: String, Codable, CaseIterable, Identifiable {
    case left
    case right

    var id: String {
        rawValue
    }

    static let `default` = CueNotesPanelSide.left

    static func resolved(from rawValue: String?) -> CueNotesPanelSide {
        guard let rawValue, let side = CueNotesPanelSide(rawValue: rawValue) else {
            return .default
        }
        return side
    }
}
