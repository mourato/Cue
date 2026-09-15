import AppKit
import SwiftUI

/// Read-only export-parity preview shown in Annotate Preview mode when Notinhas notes exist.
struct AnnotateExportPreviewView: View {
    let image: NSImage

    var body: some View {
        ZStack {
            Color(nsColor: .textBackgroundColor)

            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .padding(16)
        }
        .allowsHitTesting(false)
    }
}

#Preview("Export preview") {
    let image = NSImage(
        size: NSSize(width: 640, height: 400),
        flipped: false,
        drawingHandler: { bounds in
            NSColor.windowBackgroundColor.setFill()
            bounds.fill()

            NSColor.controlAccentColor.withAlphaComponent(0.18).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 48, dy: 40), xRadius: 16, yRadius: 16).fill()

            NSColor.labelColor.setFill()
            NSBezierPath(ovalIn: NSRect(x: 100, y: 155, width: 96, height: 96)).fill()
            return true
        }
    )

    AnnotateExportPreviewView(image: image)
        .frame(width: 640, height: 400)
}
