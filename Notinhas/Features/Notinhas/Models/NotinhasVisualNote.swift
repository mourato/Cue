//
//  NotinhasVisualNote.swift
//  Notinhas
//
//  Stable model for a numbered Notinhas note on the canvas.
//

import Foundation

nonisolated struct NotinhasVisualNote: Codable, Equatable, Identifiable {
    static let legacyDefaultPinControlValue: CGFloat = 4
    static let defaultAreaStrokeWidth: CGFloat = 2
    static let areaStrokeWidthRange: ClosedRange<CGFloat> = 1 ... 8

    let id: UUID
    var text: String
    var target: NotinhasNoteTarget
    var color: RGBAColor
    var areaStyle: NotinhasAreaStyle
    /// Stroke width for rectangular area markings (points ignore this).
    var areaStrokeWidth: CGFloat
    /// Quick-bar Size control value; diameter via `AnnotationProperties.counterDiameter(for:)`.
    var pinControlValue: CGFloat
    let creationOrder: Int

    init(
        id: UUID = UUID(),
        text: String = "",
        target: NotinhasNoteTarget,
        color: RGBAColor,
        areaStyle: NotinhasAreaStyle = .outline,
        areaStrokeWidth: CGFloat = defaultAreaStrokeWidth,
        pinControlValue: CGFloat = legacyDefaultPinControlValue,
        creationOrder: Int,
    ) {
        self.id = id
        self.text = text
        self.target = target
        self.color = color
        self.areaStyle = areaStyle
        self.areaStrokeWidth = Self.clampedAreaStrokeWidth(areaStrokeWidth)
        self.pinControlValue = pinControlValue
        self.creationOrder = creationOrder
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        target = try container.decode(NotinhasNoteTarget.self, forKey: .target)
        color = try container.decode(RGBAColor.self, forKey: .color)
        areaStyle = try container.decodeIfPresent(NotinhasAreaStyle.self, forKey: .areaStyle) ?? .outline
        areaStrokeWidth = try Self.clampedAreaStrokeWidth(
            container.decodeIfPresent(CGFloat.self, forKey: .areaStrokeWidth) ?? Self.defaultAreaStrokeWidth,
        )
        pinControlValue = try container.decodeIfPresent(CGFloat.self, forKey: .pinControlValue)
            ?? Self.legacyDefaultPinControlValue
        creationOrder = try container.decode(Int.self, forKey: .creationOrder)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
        try container.encode(target, forKey: .target)
        try container.encode(color, forKey: .color)
        try container.encode(areaStyle, forKey: .areaStyle)
        try container.encode(areaStrokeWidth, forKey: .areaStrokeWidth)
        try container.encode(pinControlValue, forKey: .pinControlValue)
        try container.encode(creationOrder, forKey: .creationOrder)
    }

    var pinDiameter: CGFloat {
        AnnotationProperties.counterDiameter(for: pinControlValue)
    }

    var hasRenderableContent: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func clampedAreaStrokeWidth(_ value: CGFloat) -> CGFloat {
        min(max(value, areaStrokeWidthRange.lowerBound), areaStrokeWidthRange.upperBound)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case text
        case target
        case color
        case areaStyle
        case areaStrokeWidth
        case pinControlValue
        case creationOrder
    }
}
