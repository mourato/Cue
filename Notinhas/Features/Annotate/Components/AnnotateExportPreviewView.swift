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
