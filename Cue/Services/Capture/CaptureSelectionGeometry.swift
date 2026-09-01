//
//  CaptureSelectionGeometry.swift
//  Notinhas
//
//  Pure resize, aspect-lock, and normalization helpers for All-In-One capture selection.
//

import CoreGraphics

// MARK: - CaptureSelectionResizeHandle

/// Resize handle positions mirroring `RecordingResizeHandle` without importing AppKit.
enum CaptureSelectionResizeHandle: CaseIterable, Equatable {
    case topLeft, top, topRight
    case left, right
    case bottomLeft, bottom, bottomRight
}

// MARK: - CaptureSelectionGeometry

enum CaptureSelectionGeometry {
    static let defaultMinSize: CGFloat = 1
    static let confirmedMinimumSize = CaptureSelectionChromeMetrics.confirmedMinimumSize
    static let creationMinimumSize = CaptureSelectionChromeMetrics.creationMinimumSize

    // MARK: - Normalization

    static func normalized(_ rect: CGRect, minSize: CGFloat = defaultMinSize) -> CGRect {
        var result = rect.standardized
        let clampedMin = max(minSize, .leastNonzeroMagnitude)

        if result.width < clampedMin {
            result.size.width = clampedMin
        }
        if result.height < clampedMin {
            result.size.height = clampedMin
        }

        return result
    }

    // MARK: - Aspect Ratio

    static func aspectRatio(of rect: CGRect) -> CGFloat? {
        let normalizedRect = rect.standardized
        guard normalizedRect.width > 0, normalizedRect.height > 0 else { return nil }
        return normalizedRect.width / normalizedRect.height
    }

    // MARK: - Resize

    static func resizedRect(
        original: CGRect,
        handle: CaptureSelectionResizeHandle,
        translation: CGPoint,
        aspectLocked: Bool,
        aspectRatio: CGFloat?,
        minSize: CGFloat = defaultMinSize,
    ) -> CGRect {
        var rect = freeResizedRect(
            original: original,
            handle: handle,
            translation: translation,
            minSize: minSize,
        )

        if aspectLocked, let ratio = aspectRatio, ratio > 0 {
            rect = aspectLockedRect(
                rect,
                handle: handle,
                anchorRect: original,
                aspectRatio: ratio,
                minSize: minSize,
            )
        }

        return normalized(rect, minSize: minSize)
    }

    // MARK: - Dimension Edits

    static func rectBySettingWidth(
        _ rect: CGRect,
        width: CGFloat,
        aspectLocked: Bool,
        aspectRatio: CGFloat?,
        minSize: CGFloat = defaultMinSize,
    ) -> CGRect {
        let clampedWidth = max(minSize, width)
        let center = CGPoint(x: rect.midX, y: rect.midY)

        if aspectLocked, let ratio = aspectRatio, ratio > 0 {
            let height = max(minSize, clampedWidth / ratio)
            return normalized(
                CGRect(
                    x: center.x - clampedWidth / 2,
                    y: center.y - height / 2,
                    width: clampedWidth,
                    height: height,
                ),
                minSize: minSize,
            )
        }

        return normalized(
            CGRect(
                x: center.x - clampedWidth / 2,
                y: rect.minY,
                width: clampedWidth,
                height: rect.height,
            ),
            minSize: minSize,
        )
    }

    static func rectBySettingHeight(
        _ rect: CGRect,
        height: CGFloat,
        aspectLocked: Bool,
        aspectRatio: CGFloat?,
        minSize: CGFloat = defaultMinSize,
    ) -> CGRect {
        let clampedHeight = max(minSize, height)
        let center = CGPoint(x: rect.midX, y: rect.midY)

        if aspectLocked, let ratio = aspectRatio, ratio > 0 {
            let width = max(minSize, clampedHeight * ratio)
            return normalized(
                CGRect(
                    x: center.x - width / 2,
                    y: center.y - clampedHeight / 2,
                    width: width,
                    height: clampedHeight,
                ),
                minSize: minSize,
            )
        }

        return normalized(
            CGRect(
                x: rect.minX,
                y: center.y - clampedHeight / 2,
                width: rect.width,
                height: clampedHeight,
            ),
            minSize: minSize,
        )
    }

    static func rectByLockingAspectRatio(
        _ rect: CGRect,
        aspectRatio: CGFloat,
        minSize: CGFloat = defaultMinSize,
    ) -> CGRect {
        guard aspectRatio > 0 else { return normalized(rect, minSize: minSize) }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let width = max(minSize, rect.width)
        let height = max(minSize, width / aspectRatio)

        return normalized(
            CGRect(
                x: center.x - width / 2,
                y: center.y - height / 2,
                width: width,
                height: height,
            ),
            minSize: minSize,
        )
    }

    // MARK: - Private

    private static func freeResizedRect(
        original: CGRect,
        handle: CaptureSelectionResizeHandle,
        translation: CGPoint,
        minSize: CGFloat,
    ) -> CGRect {
        var rect = original

        switch handle {
        case .topLeft:
            rect.origin.x += translation.x
            rect.size.width -= translation.x
            rect.size.height += translation.y
        case .top:
            rect.size.height += translation.y
        case .topRight:
            rect.size.width += translation.x
            rect.size.height += translation.y
        case .left:
            rect.origin.x += translation.x
            rect.size.width -= translation.x
        case .right:
            rect.size.width += translation.x
        case .bottomLeft:
            rect.origin.x += translation.x
            rect.origin.y += translation.y
            rect.size.width -= translation.x
            rect.size.height -= translation.y
        case .bottom:
            rect.origin.y += translation.y
            rect.size.height -= translation.y
        case .bottomRight:
            rect.origin.y += translation.y
            rect.size.width += translation.x
            rect.size.height -= translation.y
        }

        return enforceMinimumSize(rect, handle: handle, reference: original, minSize: minSize)
    }

    private static func enforceMinimumSize(
        _ rect: CGRect,
        handle: CaptureSelectionResizeHandle,
        reference: CGRect,
        minSize: CGFloat,
    ) -> CGRect {
        var result = rect

        if result.width < minSize {
            if handle == .left || handle == .topLeft || handle == .bottomLeft {
                result.origin.x = reference.maxX - minSize
            }
            result.size.width = minSize
        }

        if result.height < minSize {
            if handle == .bottom || handle == .bottomLeft || handle == .bottomRight {
                result.origin.y = reference.maxY - minSize
            }
            result.size.height = minSize
        }

        return result
    }

    private static func aspectLockedRect(
        _ rect: CGRect,
        handle: CaptureSelectionResizeHandle,
        anchorRect: CGRect,
        aspectRatio: CGFloat,
        minSize: CGFloat,
    ) -> CGRect {
        switch handle {
        case .topLeft:
            return anchoredSize(
                width: rect.width,
                fixedCorner: CGPoint(x: anchorRect.maxX, y: anchorRect.minY),
                fixedCornerKind: .bottomRight,
                aspectRatio: aspectRatio,
                minSize: minSize,
            )
        case .top:
            let height = max(minSize, rect.height)
            let width = max(minSize, height * aspectRatio)
            return CGRect(
                x: anchorRect.midX - width / 2,
                y: anchorRect.minY,
                width: width,
                height: height,
            )
        case .topRight:
            return anchoredSize(
                width: rect.width,
                fixedCorner: CGPoint(x: anchorRect.minX, y: anchorRect.minY),
                fixedCornerKind: .bottomLeft,
                aspectRatio: aspectRatio,
                minSize: minSize,
            )
        case .left:
            return centeredVerticalSize(
                width: rect.width,
                center: CGPoint(x: anchorRect.maxX, y: anchorRect.midY),
                aspectRatio: aspectRatio,
                minSize: minSize,
            )
        case .right:
            return centeredVerticalSize(
                width: rect.width,
                center: CGPoint(x: anchorRect.minX, y: anchorRect.midY),
                aspectRatio: aspectRatio,
                minSize: minSize,
            )
        case .bottomLeft:
            return anchoredSize(
                width: rect.width,
                fixedCorner: CGPoint(x: anchorRect.maxX, y: anchorRect.maxY),
                fixedCornerKind: .topRight,
                aspectRatio: aspectRatio,
                minSize: minSize,
            )
        case .bottom:
            let height = max(minSize, rect.height)
            let width = max(minSize, height * aspectRatio)
            return CGRect(
                x: anchorRect.midX - width / 2,
                y: anchorRect.maxY - height,
                width: width,
                height: height,
            )
        case .bottomRight:
            return anchoredSize(
                width: rect.width,
                fixedCorner: CGPoint(x: anchorRect.minX, y: anchorRect.maxY),
                fixedCornerKind: .topLeft,
                aspectRatio: aspectRatio,
                minSize: minSize,
            )
        }
    }

    private enum FixedCornerKind {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
    }

    private static func anchoredSize(
        width: CGFloat,
        fixedCorner: CGPoint,
        fixedCornerKind: FixedCornerKind,
        aspectRatio: CGFloat,
        minSize: CGFloat,
    ) -> CGRect {
        let clampedWidth = max(minSize, width)
        let height = max(minSize, clampedWidth / aspectRatio)

        switch fixedCornerKind {
        case .topLeft:
            return CGRect(x: fixedCorner.x, y: fixedCorner.y - height, width: clampedWidth, height: height)
        case .topRight:
            return CGRect(
                x: fixedCorner.x - clampedWidth,
                y: fixedCorner.y - height,
                width: clampedWidth,
                height: height,
            )
        case .bottomLeft:
            return CGRect(x: fixedCorner.x, y: fixedCorner.y, width: clampedWidth, height: height)
        case .bottomRight:
            return CGRect(x: fixedCorner.x - clampedWidth, y: fixedCorner.y, width: clampedWidth, height: height)
        }
    }

    private static func centeredHorizontalSize(
        height: CGFloat,
        center: CGPoint,
        aspectRatio: CGFloat,
        minSize: CGFloat,
    ) -> CGRect {
        let clampedHeight = max(minSize, height)
        let width = max(minSize, clampedHeight * aspectRatio)
        return CGRect(
            x: center.x - width / 2,
            y: center.y - clampedHeight / 2,
            width: width,
            height: clampedHeight,
        )
    }

    private static func centeredVerticalSize(
        width: CGFloat,
        center: CGPoint,
        aspectRatio: CGFloat,
        minSize: CGFloat,
    ) -> CGRect {
        let clampedWidth = max(minSize, width)
        let height = max(minSize, clampedWidth / aspectRatio)
        return CGRect(
            x: center.x - clampedWidth / 2,
            y: center.y - height / 2,
            width: clampedWidth,
            height: height,
        )
    }
}

// MARK: - Coordinate adapters

enum CaptureSelectionResizeAdapter {
    static func resizedRect(
        original: CGRect,
        handle: CaptureSelectionResizeHandle,
        translation: CGPoint,
        coordinateSpace: CaptureSelectionCoordinateSpace,
        containerSize: CGSize? = nil,
        aspectLocked: Bool = false,
        aspectRatio: CGFloat? = nil,
        minSize: CGFloat = CaptureSelectionChromeMetrics.confirmedMinimumSize,
    ) -> CGRect {
        switch coordinateSpace {
        case .bottomLeftOrigin:
            var result = CaptureSelectionGeometry.resizedRect(
                original: original,
                handle: handle,
                translation: translation,
                aspectLocked: aspectLocked,
                aspectRatio: aspectRatio,
                minSize: minSize,
            )
            if let containerSize {
                result = clampBottomLeft(result, handle: handle, container: containerSize, minSize: minSize)
            }
            return result
        case .topLeftOrigin:
            let containerHeight = containerSize?.height ?? original.maxY
            let bottomLeftOriginal = flipToBottomLeft(original, containerHeight: containerHeight)
            let bottomLeftTranslation = CGPoint(x: translation.x, y: -translation.y)
            var result = CaptureSelectionGeometry.resizedRect(
                original: bottomLeftOriginal,
                handle: handle,
                translation: bottomLeftTranslation,
                aspectLocked: aspectLocked,
                aspectRatio: aspectRatio,
                minSize: minSize,
            )
            result = flipToTopLeft(result, containerHeight: containerHeight)
            if let containerSize {
                result = clampTopLeft(result, handle: handle, container: containerSize, minSize: minSize)
            }
            return result.standardized
        }
    }

    private static func flipToBottomLeft(_ rect: CGRect, containerHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.minX,
            y: containerHeight - rect.maxY,
            width: rect.width,
            height: rect.height,
        )
    }

    private static func flipToTopLeft(_ rect: CGRect, containerHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.minX,
            y: containerHeight - rect.maxY,
            width: rect.width,
            height: rect.height,
        )
    }

    private static func clampBottomLeft(
        _ rect: CGRect,
        handle: CaptureSelectionResizeHandle,
        container: CGSize,
        minSize: CGFloat,
    ) -> CGRect {
        var result = rect.standardized
        switch handle {
        case .topLeft, .left, .bottomLeft:
            result.origin.x = max(0, result.minX)
        case .topRight, .right, .bottomRight:
            result.size.width = min(result.width, container.width - result.minX)
        default:
            break
        }
        switch handle {
        case .bottomLeft, .bottom, .bottomRight:
            result.origin.y = max(0, result.minY)
        case .topLeft, .top, .topRight:
            result.size.height = min(result.height, container.height - result.minY)
        default:
            break
        }
        return CaptureSelectionGeometry.normalized(result, minSize: minSize)
    }

    private static func clampTopLeft(
        _ rect: CGRect,
        handle: CaptureSelectionResizeHandle,
        container: CGSize,
        minSize: CGFloat,
    ) -> CGRect {
        var result = rect.standardized
        switch handle {
        case .topLeft, .left, .bottomLeft:
            result.origin.x = max(0, result.minX)
        case .topRight, .right, .bottomRight:
            result.size.width = min(result.width, container.width - result.minX)
        default:
            break
        }
        switch handle {
        case .topLeft, .top, .topRight:
            result.origin.y = max(0, result.minY)
        case .bottomLeft, .bottom, .bottomRight:
            result.size.height = min(result.height, container.height - result.minY)
        default:
            break
        }
        return CaptureSelectionGeometry.normalized(result, minSize: minSize)
    }
}
