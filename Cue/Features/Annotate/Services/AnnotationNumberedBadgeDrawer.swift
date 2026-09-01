import AppKit
import CoreGraphics

nonisolated enum AnnotationNumberedBadgeDrawer {
    static func draw(
        value: Int,
        in bounds: CGRect,
        fillColor: NSColor,
        in context: CGContext,
        textColor: NSColor = .white,
    ) {
        context.setFillColor(fillColor.cgColor)
        context.fillEllipse(in: bounds)

        let fontSize = min(max(bounds.height * 0.5, 11), 56)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: textColor,
        ]
        let text = "\(value)" as NSString
        let textSize = text.size(withAttributes: attributes)
        let textPoint = CGPoint(
            x: bounds.midX - textSize.width / 2,
            y: bounds.midY - textSize.height / 2,
        )
        text.draw(at: textPoint, withAttributes: attributes)
    }
}
