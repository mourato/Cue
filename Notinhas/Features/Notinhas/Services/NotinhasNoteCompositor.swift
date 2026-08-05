import AppKit
import Foundation

enum NotinhasNoteCompositor {
    static func compose(
        image: NSImage,
        notes: [NotinhasVisualNote],
        includeNotes: Bool,
        panelSide: NotinhasNotesPanelSide = .default,
    ) -> NSImage {
        guard includeNotes else { return image }
        return NotinhasNotesComposer.compose(
            baseImage: image,
            notes: notes,
            panelSide: panelSide,
        )
    }

    static func compose(
        image: NSImage,
        notes: [NotinhasVisualNote],
        includeNotes: Bool,
        maxDimension: CGFloat,
        panelSide: NotinhasNotesPanelSide = .default,
    ) -> NSImage {
        let base = compose(
            image: image,
            notes: notes,
            includeNotes: includeNotes,
            panelSide: panelSide,
        )
        return downscaleIfNeeded(image: base, maxDimension: maxDimension)
    }

    private static func downscaleIfNeeded(image: NSImage, maxDimension: CGFloat) -> NSImage {
        let size = image.size
        let largest = max(size.width, size.height)
        guard largest > maxDimension, largest > 0 else { return image }

        let scale = maxDimension / largest
        let target = NSSize(width: size.width * scale, height: size.height * scale)
        let scaled = NSImage(size: target)
        scaled.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: target))
        scaled.unlockFocus()
        return scaled
    }
}
