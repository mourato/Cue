//
//  PersistedAnnotationSession.swift
//  Notinhas
//
//  Codable sidecar model for committed annotation sessions.
//

import CoreGraphics
import Foundation
import SwiftUI

nonisolated struct PersistedAnnotationSession: Codable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var sourceFilePath: String
    var sourceFilePathHash: String
    var sourceSignature: PersistedFileSignature
    var originalFileName: String
    var cutoutFileName: String?
    var embeddedAssetFileNames: [String: String]
    var annotations: [PersistedAnnotationItem]
    var canvasEffects: PersistedCanvasEffects
    var selectedCanvasPresetId: UUID?
    var isSelectedCanvasPresetDirty: Bool
    var cropRect: CGRect?
    var isCutoutApplied: Bool
    var didCutoutAutoApplyCrop: Bool
    var cutoutAutoAppliedCropRect: CGRect?
    var createdAt: Date
    var updatedAt: Date
    /// Combine/stitch session flags. Optional so pre-existing sidecars (and older app
    /// builds) decode without it — schemaVersion stays 1, no migration needed.
    var combineSession: PersistedCombineSession?
    /// Optional Notinhas notes payload.
    var notinhasNotesSession: PersistedNotinhasNotesSession?

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, sourceFilePath, sourceFilePathHash, sourceSignature, originalFileName
        case cutoutFileName, embeddedAssetFileNames, annotations, canvasEffects, selectedCanvasPresetId
        case isSelectedCanvasPresetDirty, cropRect, isCutoutApplied, didCutoutAutoApplyCrop
        case cutoutAutoAppliedCropRect, createdAt, updatedAt, combineSession, notinhasNotesSession
    }

    init(
        schemaVersion: Int,
        sourceFilePath: String,
        sourceFilePathHash: String,
        sourceSignature: PersistedFileSignature,
        originalFileName: String,
        cutoutFileName: String?,
        embeddedAssetFileNames: [String: String],
        annotations: [PersistedAnnotationItem],
        canvasEffects: PersistedCanvasEffects,
        selectedCanvasPresetId: UUID?,
        isSelectedCanvasPresetDirty: Bool,
        cropRect: CGRect?,
        isCutoutApplied: Bool,
        didCutoutAutoApplyCrop: Bool,
        cutoutAutoAppliedCropRect: CGRect?,
        createdAt: Date,
        updatedAt: Date,
        combineSession: PersistedCombineSession?,
        notinhasNotesSession: PersistedNotinhasNotesSession?,
    ) {
        self.schemaVersion = schemaVersion
        self.sourceFilePath = sourceFilePath
        self.sourceFilePathHash = sourceFilePathHash
        self.sourceSignature = sourceSignature
        self.originalFileName = originalFileName
        self.cutoutFileName = cutoutFileName
        self.embeddedAssetFileNames = embeddedAssetFileNames
        self.annotations = annotations
        self.canvasEffects = canvasEffects
        self.selectedCanvasPresetId = selectedCanvasPresetId
        self.isSelectedCanvasPresetDirty = isSelectedCanvasPresetDirty
        self.cropRect = cropRect
        self.isCutoutApplied = isCutoutApplied
        self.didCutoutAutoApplyCrop = didCutoutAutoApplyCrop
        self.cutoutAutoAppliedCropRect = cutoutAutoAppliedCropRect
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.combineSession = combineSession
        self.notinhasNotesSession = notinhasNotesSession
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        sourceFilePath = try container.decode(String.self, forKey: .sourceFilePath)
        sourceFilePathHash = try container.decode(String.self, forKey: .sourceFilePathHash)
        sourceSignature = try container.decode(PersistedFileSignature.self, forKey: .sourceSignature)
        originalFileName = try container.decode(String.self, forKey: .originalFileName)
        cutoutFileName = try container.decodeIfPresent(String.self, forKey: .cutoutFileName)
        embeddedAssetFileNames = try container.decode([String: String].self, forKey: .embeddedAssetFileNames)
        annotations = try container.decode([PersistedAnnotationItem].self, forKey: .annotations)
        canvasEffects = try container.decode(PersistedCanvasEffects.self, forKey: .canvasEffects)
        selectedCanvasPresetId = try container.decodeIfPresent(UUID.self, forKey: .selectedCanvasPresetId)
        isSelectedCanvasPresetDirty = try container.decode(Bool.self, forKey: .isSelectedCanvasPresetDirty)
        cropRect = try container.decodeIfPresent(CGRect.self, forKey: .cropRect)
        isCutoutApplied = try container.decode(Bool.self, forKey: .isCutoutApplied)
        didCutoutAutoApplyCrop = try container.decode(Bool.self, forKey: .didCutoutAutoApplyCrop)
        cutoutAutoAppliedCropRect = try container.decodeIfPresent(CGRect.self, forKey: .cutoutAutoAppliedCropRect)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        combineSession = try container.decodeIfPresent(PersistedCombineSession.self, forKey: .combineSession)
        notinhasNotesSession = try? container.decodeIfPresent(
            PersistedNotinhasNotesSession.self,
            forKey: .notinhasNotesSession,
        )
    }
}

/// Persisted combine/stitch layout flags. Enum values stored as raw strings and read back
/// with safe fallbacks so unknown future values never break decoding.
struct PersistedCombineSession: Codable, Equatable {
    var modeRawValue: String
    var directionRawValue: String
    var gap: Double
    /// Free-canvas layer positions keyed by annotation UUID string (JSON-friendly).
    var freeBoundsByAnnotationID: [String: CGRect]
}

nonisolated struct PersistedFileSignature: Codable, Equatable {
    var fileSize: Int64
    var modifiedAtMilliseconds: Int64
    var pathExtension: String
}

struct PersistedCanvasEffects: Codable, Equatable {
    var backgroundStyle: CodableBackgroundStyle
    var isBlurredBackgroundEnabled: Bool
    var blurredBackgroundEffect: BlurredBackgroundEffect
    var padding: CGFloat
    var inset: CGFloat
    var autoBalance: Bool
    var shadowIntensity: CGFloat
    var cornerRadius: CGFloat
    var imageAlignment: String
    var aspectRatio: String
    var aspectRatioOrientation: String

    init(effects: AnnotationCanvasEffects) {
        backgroundStyle = CodableBackgroundStyle(from: effects.backgroundStyle)
            ?? CodableBackgroundStyle(from: .none)!
        isBlurredBackgroundEnabled = effects.isBlurredBackgroundEnabled
        blurredBackgroundEffect = effects.blurredBackgroundEffect
        padding = effects.padding
        inset = effects.inset
        autoBalance = effects.autoBalance
        shadowIntensity = effects.shadowIntensity
        cornerRadius = effects.cornerRadius
        imageAlignment = effects.imageAlignment.rawValue
        aspectRatio = effects.aspectRatio.rawValue
        aspectRatioOrientation = effects.aspectRatioOrientation.rawValue
    }

    var annotationCanvasEffects: AnnotationCanvasEffects {
        AnnotationCanvasEffects(
            backgroundStyle: backgroundStyle.toBackgroundStyle(),
            isBlurredBackgroundEnabled: isBlurredBackgroundEnabled,
            blurredBackgroundEffect: blurredBackgroundEffect,
            padding: padding,
            inset: inset,
            autoBalance: autoBalance,
            shadowIntensity: shadowIntensity,
            cornerRadius: cornerRadius,
            imageAlignment: ImageAlignment(rawValue: imageAlignment) ?? .center,
            aspectRatio: AspectRatioOption(rawValue: aspectRatio) ?? .auto,
            aspectRatioOrientation: AspectRatioOrientation(rawValue: aspectRatioOrientation) ?? .horizontal,
        )
    }
}

struct PersistedAnnotationItem: Codable, Equatable {
    var id: UUID
    var type: PersistedAnnotationType
    var bounds: CGRect
    var properties: PersistedAnnotationProperties

    init(item: AnnotationItem) {
        id = item.id
        type = PersistedAnnotationType(annotationType: item.type)
        bounds = item.bounds
        properties = PersistedAnnotationProperties(properties: item.properties)
    }

    var annotationItem: AnnotationItem? {
        guard let annotationType = type.annotationType else { return nil }
        return AnnotationItem(
            id: id,
            type: annotationType,
            bounds: bounds,
            properties: properties.annotationProperties,
        )
    }
}

struct PersistedAnnotationType: Codable, Equatable {
    enum Kind: String, Codable {
        case path, rectangle, filledRectangle, oval, arrow, line, text, highlight, blur, counter, watermark,
             embeddedImage,
             spotlight,
             magnify
    }

    var kind: Kind
    var points: [CGPoint]?
    var arrow: PersistedArrowGeometry?
    var lineStart: CGPoint?
    var lineEnd: CGPoint?
    var magnifySourceCenter: CGPoint?
    var magnifyShowsSourceCircle: Bool?
    var text: String?
    var blurType: String?
    var counterValue: Int?
    var embeddedImageAssetId: UUID?

    init(annotationType: AnnotationType) {
        switch annotationType {
        case .path(let points):
            kind = .path
            self.points = points
        case .rectangle:
            kind = .rectangle
        case .filledRectangle:
            kind = .filledRectangle
        case .oval:
            kind = .oval
        case .arrow(let geometry):
            kind = .arrow
            arrow = PersistedArrowGeometry(geometry: geometry)
        case .line(let start, let end):
            kind = .line
            lineStart = start
            lineEnd = end
        case .text(let value):
            kind = .text
            text = value
        case .highlight(let points):
            kind = .highlight
            self.points = points
        case .blur(let type):
            kind = .blur
            blurType = type.rawValue
        case .counter(let value):
            kind = .counter
            counterValue = value
        case .watermark(let value):
            kind = .watermark
            text = value
        case .embeddedImage(let assetId):
            kind = .embeddedImage
            embeddedImageAssetId = assetId
        case .spotlight:
            kind = .spotlight
        case .magnify(let sourceCenter, let showsSourceCircle):
            kind = .magnify
            magnifySourceCenter = sourceCenter
            magnifyShowsSourceCircle = showsSourceCircle
        }
    }

    var annotationType: AnnotationType? {
        switch kind {
        case .path:
            return .path(points ?? [])
        case .rectangle:
            return .rectangle
        case .filledRectangle:
            return .filledRectangle
        case .oval:
            return .oval
        case .arrow:
            return arrow.map { .arrow($0.arrowGeometry) }
        case .line:
            guard let lineStart, let lineEnd else { return nil }
            return .line(start: lineStart, end: lineEnd)
        case .text:
            return .text(text ?? "")
        case .highlight:
            return .highlight(points ?? [])
        case .blur:
            return .blur(BlurType(rawValue: blurType ?? "") ?? .pixelated)
        case .counter:
            return .counter(counterValue ?? 1)
        case .watermark:
            return .watermark(text ?? "")
        case .embeddedImage:
            guard let embeddedImageAssetId else { return nil }
            return .embeddedImage(embeddedImageAssetId)
        case .spotlight:
            return .spotlight
        case .magnify:
            guard let magnifySourceCenter else { return nil }
            return .magnify(
                sourceCenter: magnifySourceCenter,
                showsSourceCircle: magnifyShowsSourceCircle ?? false,
            )
        }
    }
}
