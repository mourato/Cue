import AppKit
import CoreGraphics

nonisolated enum AnnotationNumberedBadgeDrawer {
    static func draw(
        value: Int,
        in bounds: CGRect,
        fillColor: NSColor,
        in context: CGContext,
    ) {
        context.setFillColor(fillColor.cgColor)
        context.fillEllipse(in: bounds)

        let fontSize = min(max(bounds.height * 0.5, 11), 56)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: preferredTextColor(for: fillColor),
        ]
        let text = "\(value)" as NSString
        let textSize = text.size(withAttributes: attributes)
        let textPoint = CGPoint(
            x: bounds.midX - textSize.width / 2,
            y: bounds.midY - textSize.height / 2,
        )
        text.draw(at: textPoint, withAttributes: attributes)
    }

    static func preferredTextColor(for fillColor: NSColor) -> NSColor {
        guard let rgbColor = fillColor.usingColorSpace(.deviceRGB) else {
            return .white
        }

        let luminance = relativeLuminance(
            red: rgbColor.redComponent,
            green: rgbColor.greenComponent,
            blue: rgbColor.blueComponent,
        )
        let whiteContrast = 1.05 / (luminance + 0.05)
        let blackContrast = (luminance + 0.05) / 0.05

        return blackContrast >= whiteContrast ? .black : .white
    }

    private static func relativeLuminance(red: CGFloat, green: CGFloat, blue: CGFloat) -> CGFloat {
        func linearized(_ component: CGFloat) -> CGFloat {
            component <= 0.04045
                ? component / 12.92
                : pow((component + 0.055) / 1.055, 2.4)
        }

        return 0.2126 * linearized(red)
            + 0.7152 * linearized(green)
            + 0.0722 * linearized(blue)
    }
}
