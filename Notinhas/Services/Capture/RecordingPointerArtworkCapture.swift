#if NOTINHAS_VIDEO_MODULE
//
    //  RecordingPointerArtworkCapture.swift
    //  Notinhas
//
    //  Converts AppKit cursor images into recording metadata artwork entries.
//

    import AppKit
    import Foundation

    @MainActor
    enum RecordingPointerArtworkCapture {
        static func defaultArtwork() -> RecordedPointerArtwork? {
            capture(NSCursor.arrow, id: "pointer-default")
        }

        static func capture(_ cursor: NSCursor, id: String) -> RecordedPointerArtwork? {
            let image = cursor.image
            guard let tiffData = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData),
                  let imageData = bitmap.representation(using: .png, properties: [:]),
                  !imageData.isEmpty else {
                return nil
            }

            let imageSize = image.size
            let width = imageSize.width.isFinite && imageSize.width > 0
                ? imageSize.width
                : CGFloat(bitmap.pixelsWide)
            let height = imageSize.height.isFinite && imageSize.height > 0
                ? imageSize.height
                : CGFloat(bitmap.pixelsHigh)
            guard width > 0, height > 0 else { return nil }

            let hotSpot = cursor.hotSpot
            return RecordedPointerArtwork(
                artworkID: id,
                imageData: imageData,
                anchorPoint: RecordedPointerArtwork.Point(
                    x: min(max(hotSpot.x.isFinite ? hotSpot.x : 0, 0), width),
                    y: min(max(hotSpot.y.isFinite ? hotSpot.y : 0, 0), height),
                ),
                referenceSize: RecordedPointerArtwork.Size(
                    width: width,
                    height: height,
                ),
            )
        }
    }
#endif
