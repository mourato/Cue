#if NOTINHAS_VIDEO_MODULE
//
    //  VideoEditorOverlayRenderer.swift
    //  Notinhas
//
    //  Core Image overlay drawing shared by export compositor and preview math.
//

    import AppKit
    import CoreGraphics
    import CoreImage
    import CoreText

    enum VideoEditorOverlayRenderer {
        static func compositeOverlays(
            onto image: CIImage,
            canvasSize: CGSize,
            contentRect: CGRect,
            pointerFrame: VideoEditorPointerFrame?,
            pointerTimeline: VideoEditorPointerTimeline,
            showsSyntheticCursor: Bool,
            showsClickEffects: Bool,
            keystrokeFrame: VideoEditorKeystrokeCaptionFrame?,
            showsKeystrokes: Bool,
            keystrokePlacement: KeystrokeOverlayPosition,
            cursorScale: CGFloat = VideoEditorStylePreset.defaultCursorScale,
            zoomLevel: CGFloat = 1,
            zoomCenter: CGPoint = ZoomCalculator.neutralCenter,
        ) -> CIImage {
            var result = image
            let canvasHeight = canvasSize.height

            if showsClickEffects,
               let press = pointerFrame?.press {
                let center = VideoEditorOverlayPlacement.pointInCanvas(
                    press.location,
                    contentRect: contentRect,
                    canvasHeight: canvasHeight,
                    zoomLevel: zoomLevel,
                    zoomCenter: zoomCenter,
                )
                let geometry = VideoEditorPointerPressEffectStyle.geometry(
                    progress: press.progress,
                    referenceHeight: contentRect.height,
                    cursorScale: cursorScale,
                )
                if let clickImage = clickEffectImage(geometry: geometry, center: center) {
                    result = clickImage.composited(over: result)
                }
            }

            if showsSyntheticCursor,
               let pointerFrame,
               pointerFrame.opacity > 0.01 {
                let tip = VideoEditorOverlayPlacement.pointInCanvas(
                    pointerFrame.location,
                    contentRect: contentRect,
                    canvasHeight: canvasHeight,
                    zoomLevel: zoomLevel,
                    zoomCenter: zoomCenter,
                )
                if let cursorImage = pointerArtworkImage(
                    pointerFrame: pointerFrame,
                    timeline: pointerTimeline,
                    tip: tip,
                    referenceHeight: contentRect.height,
                    cursorScale: cursorScale,
                ) {
                    result = cursorImage.composited(over: result)
                }
            }

            if showsKeystrokes,
               let keystrokeFrame,
               let captionImage = keystrokeCaptionImage(
                   frame: keystrokeFrame,
                   cardRect: contentRect,
                   canvasSize: canvasSize,
                   placement: keystrokePlacement,
               ) {
                result = captionImage.composited(over: result)
            }

            return result
        }

        private static func pointerArtworkImage(
            pointerFrame: VideoEditorPointerFrame,
            timeline: VideoEditorPointerTimeline,
            tip: CGPoint,
            referenceHeight: CGFloat,
            cursorScale: CGFloat,
        ) -> CIImage? {
            let artwork = timeline.artwork(id: pointerFrame.artworkID)
            let height = referenceHeight
                * VideoEditorPointerArtworkMetrics.heightRatio
                * cursorScale
                * (artwork?.intrinsicScale ?? 1)
                * CGFloat(max(pointerFrame.magnification, 0.1))
            let width = height * (artwork?.aspectRatio ?? 1)
            let anchor = artwork?.normalizedAnchor ?? CGPoint(x: 0.1, y: 0.1)

            guard let cgImage = resolvedCGImage(for: artwork) else { return nil }
            let source = CIImage(cgImage: cgImage)
            let scaleX = width / max(source.extent.width, 1)
            let scaleY = height / max(source.extent.height, 1)
            let sized = source.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

            let drawOrigin = CGPoint(
                x: tip.x - anchor.x * width,
                y: tip.y - (1 - anchor.y) * height,
            )
            var transformed = sized
                .transformed(by: CGAffineTransform(translationX: drawOrigin.x, y: drawOrigin.y))
                .applyingFilter("CIColorMatrix", parameters: [
                    "inputAVector": CIVector(x: 0, y: 0, z: 0, w: pointerFrame.opacity),
                ])

            if pointerFrame.blurRadius > 0.01 {
                transformed = transformed
                    .clampedToExtent()
                    .applyingFilter("CIGaussianBlur", parameters: [
                        kCIInputRadiusKey: pointerFrame.blurRadius,
                    ])
                    .cropped(to: CGRect(
                        x: drawOrigin.x,
                        y: drawOrigin.y,
                        width: width,
                        height: height,
                    ))
            }

            if abs(pointerFrame.tiltDegrees) > 0.01 {
                let radians = CGFloat(-pointerFrame.tiltDegrees * .pi / 180)
                transformed = transformed
                    .transformed(by: CGAffineTransform(translationX: -tip.x, y: -tip.y))
                    .transformed(by: CGAffineTransform(rotationAngle: radians))
                    .transformed(by: CGAffineTransform(translationX: tip.x, y: tip.y))
            }

            return transformed
        }

        private static func resolvedCGImage(for artwork: RecordedPointerArtwork?) -> CGImage? {
            if let artwork, let image = VideoEditorPointerArtworkCache.cgImage(for: artwork) {
                return image
            }
            return NSCursor.arrow.image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        }

        private static func clickEffectImage(
            geometry: VideoEditorPointerPressEffectGeometry,
            center: CGPoint,
        ) -> CIImage? {
            let color = VideoEditorPointerPressEffectStyle.color
            var layers: [CIImage] = []

            if geometry.impactOpacity > 0.001 {
                if let impact = radialCircle(
                    center: center,
                    radius: geometry.impactRadius,
                    color: NSColor(
                        red: color.red,
                        green: color.green,
                        blue: color.blue,
                        alpha: geometry.impactOpacity,
                    ),
                ) {
                    layers.append(impact)
                }
            }

            if geometry.rippleOpacity > 0.001 {
                if let ripple = ring(
                    center: center,
                    radius: geometry.rippleRadius,
                    lineWidth: geometry.rippleLineWidth,
                    color: NSColor(
                        red: color.red,
                        green: color.green,
                        blue: color.blue,
                        alpha: geometry.rippleOpacity,
                    ),
                ) {
                    layers.append(ripple)
                }
            }

            return layers.reduce(nil as CIImage?) { partial, layer in
                partial.map { layer.composited(over: $0) } ?? layer
            }
        }

        private static func keystrokeCaptionImage(
            frame: VideoEditorKeystrokeCaptionFrame,
            cardRect: CGRect,
            canvasSize: CGSize,
            placement: KeystrokeOverlayPosition,
        ) -> CIImage? {
            let metrics = VideoEditorKeystrokeCaptionMetrics(cardHeight: cardRect.height)
            let textParts = VideoEditorKeystrokeCaptionMetrics.text(for: frame)
            let fullText = textParts.modifiers + textParts.key
            guard !fullText.isEmpty else { return nil }

            let font = NSFont.monospacedSystemFont(ofSize: metrics.fontSize * CGFloat(frame.scale), weight: .medium)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.white.withAlphaComponent(frame.opacity),
            ]
            let attributed = NSMutableAttributedString(string: fullText, attributes: attributes)
            if !textParts.modifiers.isEmpty {
                attributed.addAttributes(
                    [
                        .foregroundColor: NSColor.white.withAlphaComponent(
                            frame.opacity * VideoEditorKeystrokeCaptionMetrics.modifierAlpha,
                        ),
                    ],
                    range: NSRange(location: 0, length: textParts.modifiers.count),
                )
            }

            let textSize = attributed.size()
            let pillSize = CGSize(
                width: textSize.width + metrics.paddingHorizontal * 2,
                height: textSize.height + metrics.paddingVertical * 2,
            )
            let topLeftOrigin = metrics.pillOrigin(
                pillSize: pillSize,
                cardRect: cardRect,
                placement: placement,
            )
            let canvasHeight = canvasSize.height
            let ciOrigin = CGPoint(x: topLeftOrigin.x, y: canvasHeight - topLeftOrigin.y - pillSize.height)

            guard let context = CGContext(
                data: nil,
                width: Int(ceil(canvasSize.width)),
                height: Int(ceil(canvasSize.height)),
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
            ) else {
                return nil
            }

            context.clear(CGRect(origin: .zero, size: canvasSize))
            let pillRect = CGRect(origin: ciOrigin, size: pillSize)
            context.setFillColor(
                NSColor.black.withAlphaComponent(frame.opacity * VideoEditorKeystrokeCaptionMetrics.backgroundAlpha)
                    .cgColor,
            )
            let path = CGPath(
                roundedRect: pillRect,
                cornerWidth: metrics.cornerRadius,
                cornerHeight: metrics.cornerRadius,
                transform: nil,
            )
            context.addPath(path)
            context.fillPath()

            context.saveGState()
            context.textMatrix = .identity
            context.translateBy(x: 0, y: canvasSize.height)
            context.scaleBy(x: 1, y: -1)
            let drawPoint = CGPoint(
                x: pillRect.minX + metrics.paddingHorizontal,
                y: canvasSize.height - pillRect.maxY + metrics.paddingVertical,
            )
            let line = CTLineCreateWithAttributedString(attributed)
            context.textPosition = drawPoint
            CTLineDraw(line, context)
            context.restoreGState()

            guard let cgImage = context.makeImage() else { return nil }
            return CIImage(cgImage: cgImage)
        }

        private static func radialCircle(center: CGPoint, radius: CGFloat, color: NSColor) -> CIImage? {
            guard radius > 0 else { return nil }
            let rect = CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2,
            )
            guard let context = CGContext(
                data: nil,
                width: Int(ceil(rect.width)),
                height: Int(ceil(rect.height)),
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
            ) else {
                return nil
            }
            context.translateBy(x: -rect.minX, y: -rect.minY)
            context.setFillColor(color.cgColor)
            context.fillEllipse(in: rect)
            guard let cgImage = context.makeImage() else { return nil }
            return CIImage(cgImage: cgImage)
        }

        private static func ring(
            center: CGPoint,
            radius: CGFloat,
            lineWidth: CGFloat,
            color: NSColor,
        ) -> CIImage? {
            guard radius > 0 else { return nil }
            let rect = CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2,
            )
            guard let context = CGContext(
                data: nil,
                width: Int(ceil(rect.width + lineWidth)),
                height: Int(ceil(rect.height + lineWidth)),
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
            ) else {
                return nil
            }
            context.translateBy(x: -rect.minX + lineWidth / 2, y: -rect.minY + lineWidth / 2)
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(lineWidth)
            context.strokeEllipse(in: rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2))
            guard let cgImage = context.makeImage() else { return nil }
            return CIImage(cgImage: cgImage)
        }
    }
#endif
