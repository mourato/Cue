//
//  AnnotateCropOverlayView.swift
//  Notinhas
//
//  Crop overlay with dimming, border, grid, dimensions, and resize handles
//

import SwiftUI

/// Overlay view for crop tool showing crop region and handles
struct CropOverlayView: View {
    @ObservedObject var state: AnnotateState
    let scale: CGFloat
    let canvasBounds: CGRect

    private let handleSize: CGFloat = CaptureSelectionChromeMetrics.handleHitSize
    private let cornerHandleLength: CGFloat = CaptureSelectionChromeMetrics.cornerHandleLength

    /// Whether crop is being actively edited (vs just previewing applied crop)
    private var isActivelyEditing: Bool {
        state.selectedTool == .crop && state.isCropActive
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let cropRect = state.cropRect {
                    let scaledCrop = scaledCropRect(cropRect)

                    if isActivelyEditing {
                        // Active editing mode: show handles and grid
                        activeEditingOverlay(scaledCrop: scaledCrop, containerSize: geometry.size)
                    } else {
                        // Preview mode: show solid mask outside crop area
                        appliedCropPreview(scaledCrop: scaledCrop, containerSize: geometry.size)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Active Editing Overlay

    @ViewBuilder
    private func activeEditingOverlay(scaledCrop: CGRect, containerSize: CGSize) -> some View {
        // Dim overlay outside crop region
        CropDimOverlay(
            cropRect: scaledCrop,
            containerSize: containerSize,
        )
        .allowsHitTesting(false)

        // Crop border
        Rectangle()
            .stroke(Color.white, lineWidth: CaptureSelectionChromeMetrics.continuousBorderWidth)
            .frame(width: scaledCrop.width, height: scaledCrop.height)
            .position(x: scaledCrop.midX, y: scaledCrop.midY)
            .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 0)
            .allowsHitTesting(false)

        // Rule of thirds grid
        if state.showCropGrid {
            CropGridOverlay(cropRect: scaledCrop)
                .allowsHitTesting(false)
        }

        // Corner L-shaped handles
        ForEach(CropHandle.corners, id: \.self) { handle in
            CropCornerHandle(handle: handle, length: cornerHandleLength)
                .position(handlePosition(for: handle, in: scaledCrop))
                .allowsHitTesting(false)
        }

        // Edge handles (subtle lines)
        ForEach(CropHandle.edges, id: \.self) { handle in
            CropEdgeHandle(handle: handle, cropRect: scaledCrop)
                .position(handlePosition(for: handle, in: scaledCrop))
                .allowsHitTesting(false)
        }

        // Dimension display (when resizing)
        if state.isCropResizing || state.isCropActive {
            if let cropRect = state.cropRect {
                CropDimensionLabel(
                    width: Int(cropRect.width),
                    height: Int(cropRect.height),
                )
                .position(x: scaledCrop.midX, y: scaledCrop.maxY + 24)
                .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Applied Crop Preview (solid mask)

    @ViewBuilder
    private func appliedCropPreview(scaledCrop: CGRect, containerSize: CGSize) -> some View {
        // Solid black mask outside crop region (hides cropped areas)
        CropSolidMask(
            cropRect: scaledCrop,
            containerSize: containerSize,
        )
        .allowsHitTesting(false)

        // Subtle border around crop area
        Rectangle()
            .stroke(Color.white.opacity(0.3), lineWidth: 1)
            .frame(width: scaledCrop.width, height: scaledCrop.height)
            .position(x: scaledCrop.midX, y: scaledCrop.midY)
            .allowsHitTesting(false)
    }

    private func scaledCropRect(_ rect: CGRect) -> CGRect {
        // Convert from bottom-left origin (canvas coords) to top-left origin (SwiftUI coords)
        CGRect(
            x: (rect.origin.x - canvasBounds.minX) * scale,
            y: (canvasBounds.maxY - rect.origin.y - rect.height) * scale,
            width: rect.width * scale,
            height: rect.height * scale,
        )
    }

    private func handlePosition(for handle: CropHandle, in rect: CGRect) -> CGPoint {
        if let resizeHandle = handle.asCaptureResizeHandle {
            return CaptureSelectionHandleGeometry.anchor(for: resizeHandle, in: rect, coordinateSpace: .topLeftOrigin)
        }
        return CGPoint(x: rect.midX, y: rect.midY)
    }
}

// MARK: - Crop Handle Enum

enum CropHandle: String, CaseIterable {
    case topLeft, top, topRight
    case left, right
    case bottomLeft, bottom, bottomRight
    case body

    var asCaptureResizeHandle: CaptureSelectionResizeHandle? {
        switch self {
        case .topLeft: .topLeft
        case .top: .top
        case .topRight: .topRight
        case .left: .left
        case .right: .right
        case .bottomLeft: .bottomLeft
        case .bottom: .bottom
        case .bottomRight: .bottomRight
        case .body: nil
        }
    }

    init(_ resizeHandle: CaptureSelectionResizeHandle) {
        switch resizeHandle {
        case .topLeft: self = .topLeft
        case .top: self = .top
        case .topRight: self = .topRight
        case .left: self = .left
        case .right: self = .right
        case .bottomLeft: self = .bottomLeft
        case .bottom: self = .bottom
        case .bottomRight: self = .bottomRight
        }
    }

    static var corners: [CropHandle] {
        [.topLeft, .topRight, .bottomLeft, .bottomRight]
    }

    static var edges: [CropHandle] {
        [.top, .bottom, .left, .right]
    }
}

// MARK: - Crop Dim Overlay

struct CropDimOverlay: View {
    let cropRect: CGRect
    let containerSize: CGSize
    private let dimColor = Color.black.opacity(0.6)

    var body: some View {
        ZStack {
            // Top region
            dimColor
                .frame(width: containerSize.width, height: max(0, cropRect.minY))
                .position(x: containerSize.width / 2, y: cropRect.minY / 2)

            // Bottom region
            dimColor
                .frame(width: containerSize.width, height: max(0, containerSize.height - cropRect.maxY))
                .position(x: containerSize.width / 2, y: (containerSize.height + cropRect.maxY) / 2)

            // Left region (between top and bottom)
            dimColor
                .frame(width: max(0, cropRect.minX), height: cropRect.height)
                .position(x: cropRect.minX / 2, y: cropRect.midY)

            // Right region (between top and bottom)
            dimColor
                .frame(width: max(0, containerSize.width - cropRect.maxX), height: cropRect.height)
                .position(x: (containerSize.width + cropRect.maxX) / 2, y: cropRect.midY)
        }
    }
}

// MARK: - Crop Solid Mask (for applied crop preview)

struct CropSolidMask: View {
    let cropRect: CGRect
    let containerSize: CGSize
    /// Use canvas background color for seamless masking
    private let maskColor = Color(nsColor: .windowBackgroundColor)

    var body: some View {
        ZStack {
            // Top region
            maskColor
                .frame(width: containerSize.width, height: max(0, cropRect.minY))
                .position(x: containerSize.width / 2, y: cropRect.minY / 2)

            // Bottom region
            maskColor
                .frame(width: containerSize.width, height: max(0, containerSize.height - cropRect.maxY))
                .position(x: containerSize.width / 2, y: (containerSize.height + cropRect.maxY) / 2)

            // Left region (between top and bottom)
            maskColor
                .frame(width: max(0, cropRect.minX), height: cropRect.height)
                .position(x: cropRect.minX / 2, y: cropRect.midY)

            // Right region (between top and bottom)
            maskColor
                .frame(width: max(0, containerSize.width - cropRect.maxX), height: cropRect.height)
                .position(x: (containerSize.width + cropRect.maxX) / 2, y: cropRect.midY)
        }
    }
}

// MARK: - Rule of Thirds Grid

struct CropGridOverlay: View {
    let cropRect: CGRect

    var body: some View {
        ZStack {
            // Vertical lines (2 lines dividing into thirds)
            ForEach(1 ..< 3, id: \.self) { i in
                let x = cropRect.minX + cropRect.width * CGFloat(i) / 3
                Rectangle()
                    .fill(Color.white.opacity(0.4))
                    .frame(width: 0.5, height: cropRect.height)
                    .position(x: x, y: cropRect.midY)
            }

            // Horizontal lines (2 lines dividing into thirds)
            ForEach(1 ..< 3, id: \.self) { i in
                let y = cropRect.minY + cropRect.height * CGFloat(i) / 3
                Rectangle()
                    .fill(Color.white.opacity(0.4))
                    .frame(width: cropRect.width, height: 0.5)
                    .position(x: cropRect.midX, y: y)
            }
        }
    }
}

// MARK: - Corner Handle (L-shaped)

struct CropCornerHandle: View {
    let handle: CropHandle
    var length: CGFloat = CaptureSelectionChromeMetrics.cornerHandleLength
    private let thickness: CGFloat = CaptureSelectionChromeMetrics.handleThickness

    var body: some View {
        ZStack {
            // Horizontal bar
            Rectangle()
                .fill(Color.white)
                .frame(width: length, height: thickness)
                .offset(x: horizontalOffset, y: verticalBarOffset)
                .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 0)

            // Vertical bar
            Rectangle()
                .fill(Color.white)
                .frame(width: thickness, height: length)
                .offset(x: horizontalBarOffset, y: verticalOffset)
                .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 0)
        }
    }

    private var horizontalOffset: CGFloat {
        switch handle {
        case .topLeft, .bottomLeft: length / 2
        case .topRight, .bottomRight: -length / 2
        default: 0
        }
    }

    private var verticalOffset: CGFloat {
        switch handle {
        case .topLeft, .topRight: length / 2
        case .bottomLeft, .bottomRight: -length / 2
        default: 0
        }
    }

    private var horizontalBarOffset: CGFloat {
        switch handle {
        case .topLeft, .bottomLeft: 0
        case .topRight, .bottomRight: 0
        default: 0
        }
    }

    private var verticalBarOffset: CGFloat {
        switch handle {
        case .topLeft, .topRight: 0
        case .bottomLeft, .bottomRight: 0
        default: 0
        }
    }
}

// MARK: - Edge Handle (subtle line)

struct CropEdgeHandle: View {
    let handle: CropHandle
    let cropRect: CGRect
    private let handleLength: CGFloat = CaptureSelectionChromeMetrics.edgeHandleLength
    private let thickness: CGFloat = CaptureSelectionChromeMetrics.handleThickness

    var body: some View {
        Rectangle()
            .fill(Color.white)
            .frame(
                width: isHorizontal ? handleLength : thickness,
                height: isHorizontal ? thickness : handleLength,
            )
            .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 0)
    }

    private var isHorizontal: Bool {
        handle == .top || handle == .bottom
    }
}

// MARK: - Dimension Label

struct CropDimensionLabel: View {
    let width: Int
    let height: Int

    var body: some View {
        HStack(spacing: 4) {
            Text("\(width)")
                .fontWeight(.medium)
            Text("×")
                .foregroundColor(.secondary)
            Text("\(height)")
                .fontWeight(.medium)
        }
        .font(.system(size: 11, weight: .regular, design: .monospaced))
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.75)),
        )
    }
}
