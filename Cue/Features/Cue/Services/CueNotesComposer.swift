import AppKit
import CoreGraphics

enum CueNotesComposer {
    static let panelWidth: CGFloat = 320
    static let panelPadding: CGFloat = 24
    static let rowSpacing: CGFloat = 16
    static let circleDiameter: CGFloat = 24
    static let textColumnWidth: CGFloat = 248

    static func compose(
        baseImage: NSImage,
        notes: [CueVisualNote],
        panelSide: CueNotesPanelSide,
        displayScale _: CGFloat = 1,
    ) -> NSImage {
        let ordered = CueNoteGeometry.orderedRenderableNotes(notes)
        guard !ordered.isEmpty else { return baseImage }

        let baseSize = baseImage.size
        guard baseSize.width > 0, baseSize.height > 0 else { return baseImage }

        let panelHeight = max(baseSize.height, panelContentHeight(for: ordered))
        let outputSize = CGSize(
            width: baseSize.width + panelWidth,
            height: max(baseSize.height, panelHeight),
        )

        let output = NSImage(size: outputSize)
        output.lockFocus()
        defer { output.unlockFocus() }

        guard let context = NSGraphicsContext.current?.cgContext else { return baseImage }

        let imageRect: CGRect
        let panelRect: CGRect
        switch panelSide {
        case .left:
            panelRect = CGRect(x: 0, y: 0, width: panelWidth, height: outputSize.height)
            imageRect = CGRect(x: panelWidth, y: 0, width: baseSize.width, height: baseSize.height)
        case .right:
            imageRect = CGRect(x: 0, y: 0, width: baseSize.width, height: baseSize.height)
            panelRect = CGRect(x: baseSize.width, y: 0, width: panelWidth, height: outputSize.height)
        }

        baseImage.draw(in: imageRect)
        CueNoteRenderer.draw(
            notes: ordered,
            selectedNoteID: nil,
            in: context,
            imageBounds: imageRect,
        )

        drawPanel(notes: ordered, in: panelRect, context: context)
        return output
    }

    static func addPanelOnly(
        to baseImage: NSImage,
        notes: [CueVisualNote],
        panelSide: CueNotesPanelSide,
    ) -> NSImage {
        let ordered = CueNoteGeometry.orderedRenderableNotes(notes)
        guard !ordered.isEmpty else { return baseImage }

        let baseSize = baseImage.size
        let outputSize = CGSize(
            width: baseSize.width + panelWidth,
            height: max(baseSize.height, panelContentHeight(for: ordered)),
        )
        let output = NSImage(size: outputSize)
        output.lockFocus()
        defer { output.unlockFocus() }
        guard let context = NSGraphicsContext.current?.cgContext else { return baseImage }

        let imageRect: CGRect
        let panelRect: CGRect
        switch panelSide {
        case .left:
            panelRect = CGRect(x: 0, y: 0, width: panelWidth, height: outputSize.height)
            imageRect = CGRect(x: panelWidth, y: 0, width: baseSize.width, height: baseSize.height)
        case .right:
            imageRect = CGRect(x: 0, y: 0, width: baseSize.width, height: baseSize.height)
            panelRect = CGRect(x: baseSize.width, y: 0, width: panelWidth, height: outputSize.height)
        }

        baseImage.draw(in: imageRect)
        drawPanel(notes: ordered, in: panelRect, context: context)
        return output
    }

    private static func panelContentHeight(for notes: [CueVisualNote]) -> CGFloat {
        var height = panelPadding * 2 + headerHeight()
        for note in notes {
            height += rowHeight(for: note.text) + rowSpacing
        }
        return max(height, 200)
    }

    private static func headerHeight() -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 18)]
        return (CueL10n.sidePanelTitle as NSString).size(withAttributes: attributes).height + 12
    }

    private static func rowHeight(for text: String) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14),
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let bounds = attributed.boundingRect(
            with: CGSize(width: textColumnWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
        )
        return max(circleDiameter, ceil(bounds.height))
    }

    private static func drawPanel(
        notes: [CueVisualNote],
        in panelRect: CGRect,
        context: CGContext,
    ) {
        context.saveGState()
        context.setFillColor(CueNotesPanelStyle.background.cgColor)
        context.fill(panelRect)

        var cursorY = panelRect.maxY - panelPadding

        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 18),
            .foregroundColor: CueNotesPanelStyle.primaryText,
        ]
        let header = NSAttributedString(string: CueL10n.sidePanelTitle, attributes: headerAttributes)
        let headerSize = header.size()
        cursorY -= headerSize.height
        drawAttributedString(
            header,
            at: CGPoint(x: panelRect.minX + panelPadding, y: cursorY),
            maxWidth: textColumnWidth,
        )
        cursorY -= 12

        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: CueNotesPanelStyle.primaryText,
        ]

        for (index, note) in notes.enumerated() {
            let rowHeight = rowHeight(for: note.text)
            cursorY -= rowHeight

            let circleRect = CGRect(
                x: panelRect.minX + panelPadding,
                y: cursorY + (rowHeight - circleDiameter) / 2,
                width: circleDiameter,
                height: circleDiameter,
            )
            context.setFillColor(note.color.nsColor.cgColor)
            context.fillEllipse(in: circleRect)

            let numberAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: 12),
                .foregroundColor: NSColor.white,
            ]
            let number = NSAttributedString(string: "\(index + 1)", attributes: numberAttributes)
            let numberSize = number.size()
            drawAttributedString(
                number,
                at: CGPoint(
                    x: circleRect.midX - numberSize.width / 2,
                    y: circleRect.midY - numberSize.height / 2,
                ),
                maxWidth: circleRect.width,
            )

            let textX = circleRect.maxX + 12
            let text = NSAttributedString(string: note.text, attributes: textAttributes)
            drawAttributedString(text, at: CGPoint(x: textX, y: cursorY), maxWidth: textColumnWidth)

            cursorY -= rowSpacing
        }

        context.restoreGState()
    }

    private static func drawAttributedString(
        _ attributed: NSAttributedString,
        at origin: CGPoint,
        maxWidth: CGFloat? = nil,
    ) {
        let size = attributed.boundingRect(
            with: CGSize(width: maxWidth ?? .greatestFiniteMagnitude, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
        ).integral.size
        attributed.draw(
            with: CGRect(origin: origin, size: size),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
        )
    }
}
