//
//  AnnotationShapeFillStyleDrawing.swift
//  Notinhas
//
//  Shared CG drawing for annotate shapes and Notinhas note areas.
//

import AppKit
import CoreGraphics

nonisolated enum AnnotationShapeFillStyleDrawing {
    static func drawRoundedRect(
        in rect: CGRect,
        cornerRadius: CGFloat,
        style: AnnotationShapeFillStyle,
        color: NSColor,
        strokeWidth: CGFloat,
        in context: CGContext,
    ) {
        let standardized = rect.standardized
        let path = roundedRectPath(in: standardized, cornerRadius: cornerRadius)
        draw(path: path, bounds: standardized, style: style, color: color, strokeWidth: strokeWidth, in: context)
    }

    static func drawEllipse(
        in rect: CGRect,
        style: AnnotationShapeFillStyle,
        color: NSColor,
        strokeWidth: CGFloat,
        in context: CGContext,
    ) {
        let standardized = rect.standardized
        let path = CGPath(ellipseIn: standardized, transform: nil)
        draw(path: path, bounds: standardized, style: style, color: color, strokeWidth: strokeWidth, in: context)
    }

    static func drawHatch(in rect: CGRect, color: NSColor, context: CGContext) {
        context.saveGState()
        context.clip(to: rect)
        context.setStrokeColor(color.withAlphaComponent(0.35).cgColor)
        context.setLineWidth(1)
        let spacing: CGFloat = 8
        var offset: CGFloat = rect.minX - rect.height
        while offset < rect.maxX + rect.height {
            context.move(to: CGPoint(x: offset, y: rect.minY))
            context.addLine(to: CGPoint(x: offset + rect.height, y: rect.maxY))
            offset += spacing
        }
        context.strokePath()
        context.restoreGState()
    }

    private static func draw(
        path: CGPath,
        bounds: CGRect,
        style: AnnotationShapeFillStyle,
        color: NSColor,
        strokeWidth: CGFloat,
        in context: CGContext,
    ) {
        context.saveGState()
        context.setLineWidth(strokeWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        switch style {
        case .outline:
            context.setStrokeColor(color.withAlphaComponent(0.95).cgColor)
            context.addPath(path)
            context.strokePath()
        case .solid:
            context.setFillColor(color.withAlphaComponent(1).cgColor)
            context.setStrokeColor(color.withAlphaComponent(0.95).cgColor)
            context.addPath(path)
            context.drawPath(using: .fillStroke)
        case .tinted:
            context.setFillColor(color.withAlphaComponent(0.18).cgColor)
            context.setStrokeColor(color.withAlphaComponent(0.95).cgColor)
            context.addPath(path)
            context.drawPath(using: .fillStroke)
        case .hatched:
            context.setStrokeColor(color.withAlphaComponent(0.95).cgColor)
            context.addPath(path)
            context.strokePath()
            context.saveGState()
            context.addPath(path)
            context.clip()
            drawHatch(in: bounds, color: color, context: context)
            context.restoreGState()
        }

        context.restoreGState()
    }

    private static func roundedRectPath(in rect: CGRect, cornerRadius: CGFloat) -> CGPath {
        let radius = max(0, min(cornerRadius, min(rect.width, rect.height) / 2))
        return CGPath(
            roundedRect: rect,
            cornerWidth: radius,
            cornerHeight: radius,
            transform: nil,
        )
    }
}
