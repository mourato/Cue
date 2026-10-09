//
//  OCRService.swift
//  Notinhas
//
//  Provides OCR text recognition using Vision framework
//

import AppKit
import CoreImage
import CoreText
import Vision

/// Errors that can occur during OCR processing
enum OCRError: LocalizedError {
    case imageConversionFailed
    case noTextFound
    case recognitionFailed(Error)

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            L10n.OCR.imageConversionFailed
        case .noTextFound:
            L10n.OCR.noTextFound
        case let .recognitionFailed(error):
            L10n.OCR.recognitionFailed(error.localizedDescription)
        }
    }
}

/// Service for performing OCR text recognition on images.
///
/// Runs as an actor so bitmap normalization, contrast enhancement, Vision
/// execution, and result scoring stay off the main actor. Serialization is
/// per synchronous stretch: one Vision `perform`, one `CIContext` use, or any
/// other synchronous access runs at a time on this actor's executor. Async
/// methods may interleave with other work across their `await` points, so the
/// recognition pipeline as a whole is not atomic.
actor OCRService {
    static let shared = OCRService()

    private typealias OCRCandidate = (result: OCRResult, score: Float)

    private struct OCRPassSummary {
        let acceptedResult: OCRResult?
        let bestCandidate: OCRCandidate?
        let lastError: Error?
    }

    private let ciContext = CIContext(options: [.cacheIntermediates: false])

    private var hasPrewarmed = false

    init() {}

    // MARK: - Image Normalization

    /// Draw the image into a standard sRGB bitmap so Vision can read it.
    /// This fixes `TextRecognition.CRImageReaderError` on images produced by
    /// `SCScreenshotManager` and other IOSurface-backed sources.
    private func normalizedImageForVision(_ image: CGImage) -> CGImage {
        let width = image.width
        let height = image.height
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            DiagnosticLogger.shared.log(
                .warning,
                .ocr,
                "OCR image normalization failed; using original image",
                context: ["width": "\(width)", "height": "\(height)"]
            )
            return image
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let normalized = context.makeImage() else {
            DiagnosticLogger.shared.log(
                .warning,
                .ocr,
                "OCR image normalization produced no output; using original image",
                context: ["width": "\(width)", "height": "\(height)"]
            )
            return image
        }

        return normalized
    }

    // MARK: - Public API

    func recognize(_ request: OCRRequest) async throws -> OCRResult {
        // ScreenCaptureKit images are sometimes backed by IOSurfaces or use color
        // spaces that Vision cannot read directly, producing CRImageReaderError.
        // Normalize to a standard sRGB bitmap before recognition to avoid that.
        let normalizedImage = normalizedImageForVision(request.image)
        let request = OCRRequest(
            image: normalizedImage,
            preferredLanguageIdentifier: request.preferredLanguageIdentifier,
            contentType: request.contentType,
            keepLineBreaks: request.keepLineBreaks
        )

        let profile = VisionOCRProfile.resolve(for: request)
        let languageContext = request.preferredLanguageIdentifier ?? "auto"
        let primaryProfiles = uniqueProfiles([profile] + VisionOCRProfile.recoveryProfiles(
            for: request,
            primary: profile
        ))
        let primaryPass = await runRecognitionPass(
            for: request,
            profiles: primaryProfiles,
            languageContext: languageContext
        )

        if let acceptedResult = primaryPass.acceptedResult {
            return acceptedResult
        }

        var bestCandidate = primaryPass.bestCandidate
        var lastError = primaryPass.lastError

        if let enhancedImage = makeContrastEnhancedImage(from: request.image) {
            let enhancedProfiles = uniqueProfiles(VisionOCRProfile.enhancedRecoveryProfiles(
                for: request,
                primary: profile
            ))
            if !enhancedProfiles.isEmpty {
                let enhancedRequest = OCRRequest(
                    image: enhancedImage,
                    preferredLanguageIdentifier: request.preferredLanguageIdentifier,
                    contentType: request.contentType,
                    keepLineBreaks: request.keepLineBreaks
                )

                DiagnosticLogger.shared.log(
                    .info,
                    .ocr,
                    "OCR contrast-enhanced recovery started",
                    context: [
                        "sourceProfile": profile.id,
                        "profiles": enhancedProfiles.map(\.id).joined(separator: ",")
                    ]
                )

                let enhancedPass = await runRecognitionPass(
                    for: enhancedRequest,
                    profiles: enhancedProfiles,
                    languageContext: "\(languageContext)+contrast"
                )

                bestCandidate = betterCandidate(bestCandidate, than: enhancedPass.bestCandidate)
                if let acceptedResult = enhancedPass.acceptedResult {
                    return acceptedResult
                }
                lastError = enhancedPass.lastError ?? lastError
            }
        }

        if request.contentType != .code,
           let verticalImage = VerticalCJKTextNormalizer.normalizedImage(from: request.image)
        {
            let verticalRequest = OCRRequest(
                image: verticalImage,
                preferredLanguageIdentifier: request.preferredLanguageIdentifier,
                contentType: request.contentType,
                keepLineBreaks: request.keepLineBreaks
            )
            let verticalProfiles = uniqueProfiles(
                [profile]
                    + VisionOCRProfile.recoveryProfiles(for: request, primary: profile)
                    + VisionOCRProfile.enhancedRecoveryProfiles(for: request, primary: profile)
            )

            DiagnosticLogger.shared.log(
                .info,
                .ocr,
                "OCR vertical CJK recovery started",
                context: [
                    "sourceProfile": profile.id,
                    "sourceSize": "\(request.image.width)x\(request.image.height)",
                    "normalizedSize": "\(verticalImage.width)x\(verticalImage.height)",
                    "profiles": verticalProfiles.map(\.id).joined(separator: ",")
                ]
            )

            let verticalPass = await runRecognitionPass(
                for: verticalRequest,
                profiles: verticalProfiles,
                languageContext: "\(languageContext)+vertical-cjk"
            )

            bestCandidate = betterCandidate(bestCandidate, than: verticalPass.bestCandidate)
            if let acceptedResult = verticalPass.acceptedResult {
                return acceptedResult
            }
            lastError = verticalPass.lastError ?? lastError
        }

        if let bestCandidate {
            DiagnosticLogger.shared.log(
                .warning,
                .ocr,
                "OCR returning best available candidate after exhausting profiles",
                context: [
                    "profile": bestCandidate.result.profileID,
                    "confidence": String(format: "%.3f", bestCandidate.result.averageConfidence),
                    "score": String(format: "%.3f", bestCandidate.score)
                ]
            )
            return bestCandidate.result
        }

        throw lastError ?? OCRError.noTextFound
    }

    /// Recognize text from a CGImage
    /// - Parameter image: The image to extract text from
    /// - Returns: Recognized text joined by newlines
    func recognizeText(
        from image: CGImage,
        preferredLanguageIdentifier: String? = nil,
        contentType: OCRContentType = .interfaceText,
        keepLineBreaks: Bool = true
    ) async throws -> String {
        let result = try await recognize(
            OCRRequest(
                image: image,
                preferredLanguageIdentifier: preferredLanguageIdentifier,
                contentType: contentType,
                keepLineBreaks: keepLineBreaks
            )
        )
        return result.text
    }

    /// Recognize text from an NSImage
    ///
    /// `@MainActor` keeps the AppKit `NSImage` to `CGImage` extraction on the
    /// main actor; the heavy normalization and recognition then hop to this
    /// OCR actor through the `CGImage` overload.
    /// - Parameter image: The NSImage to extract text from
    /// - Returns: Recognized text joined by newlines
    @MainActor
    func recognizeText(
        from image: NSImage,
        preferredLanguageIdentifier: String? = nil,
        contentType: OCRContentType = .interfaceText,
        keepLineBreaks: Bool = true
    ) async throws -> String {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            DiagnosticLogger.shared.log(.error, .ocr, "NSImage to CGImage conversion failed")
            throw OCRError.imageConversionFailed
        }
        return try await recognizeText(
            from: cgImage,
            preferredLanguageIdentifier: preferredLanguageIdentifier,
            contentType: contentType,
            keepLineBreaks: keepLineBreaks
        )
    }

    // MARK: - Launch Prewarm

    /// Outcome of a launch `prewarm(preferredLanguageIdentifier:)` call.
    enum PrewarmOutcome: Equatable {
        /// This process already started its single prewarm request.
        case alreadyPrewarmed
        /// One `.accurate` Vision request ran on the synthetic bitmap.
        case succeeded
        /// The prewarm request failed; real recognition is unaffected.
        case failed
    }

    /// Warm the Vision/ANE OCR pipeline once per process with a single
    /// `.accurate` request using the resolved normal interface profile over a
    /// small synthetic bitmap (never screen or user content). Bypasses the
    /// profile recovery loop on purpose: warmup only needs one request.
    ///
    /// Designed to be fired without awaiting at launch. Failure is fail-soft
    /// with no retry and no clipboard, history, toast, or permission side
    /// effects. Each synchronous Vision pass and shared-resource access on
    /// this actor still runs one at a time, so a capture requested meanwhile
    /// never overlaps prewarm's Vision `perform`; the two calls may interleave
    /// across `await` points rather than queueing end-to-end.
    @discardableResult
    func prewarm(preferredLanguageIdentifier: String?) async -> PrewarmOutcome {
        // Guard before any await so duplicate launches start no second request.
        guard !hasPrewarmed else { return .alreadyPrewarmed }
        hasPrewarmed = true

        guard let image = Self.prewarmBitmap() else {
            DiagnosticLogger.shared.log(.warning, .ocr, "OCR launch prewarm skipped: synthetic bitmap unavailable")
            return .failed
        }

        let request = OCRRequest(
            image: image,
            preferredLanguageIdentifier: preferredLanguageIdentifier,
            contentType: .interfaceText,
            keepLineBreaks: true
        )
        let profile = VisionOCRProfile.resolve(for: request)

        do {
            _ = try await recognize(
                request,
                using: profile,
                languageContext: request.preferredLanguageIdentifier ?? "auto",
                isFallback: false
            )
            DiagnosticLogger.shared.log(
                .info,
                .ocr,
                "OCR launch prewarm completed",
                context: ["profile": profile.id]
            )
            return .succeeded
        } catch {
            DiagnosticLogger.shared.log(
                .debug,
                .ocr,
                "OCR launch prewarm failed; continuing without warmup",
                context: ["profile": profile.id, "reason": error.localizedDescription]
            )
            return .failed
        }
    }

    /// Small synthetic text bitmap for prewarm; never screen or user content.
    private static func prewarmBitmap() -> CGImage? {
        let width = 480
        let height = 100

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))

        let attributes = [
            kCTFontAttributeName: CTFontCreateWithName("Helvetica" as CFString, 30, nil),
            kCTForegroundColorAttributeName: CGColor(red: 0, green: 0, blue: 0, alpha: 1)
        ] as CFDictionary
        guard let attributedText = CFAttributedStringCreate(
            nil,
            "Cue OCR Prewarm 1234" as CFString,
            attributes
        ) else {
            return nil
        }

        let line = CTLineCreateWithAttributedString(attributedText)
        context.textPosition = CGPoint(x: 18, y: 30)
        CTLineDraw(line, context)

        return context.makeImage()
    }

    // MARK: - Vision Runtime

    private func runRecognitionPass(
        for request: OCRRequest,
        profiles: [VisionOCRProfile],
        languageContext: String
    ) async -> OCRPassSummary {
        var lastError: Error?
        var bestCandidate: OCRCandidate?

        for (index, profile) in profiles.enumerated() {
            let isFallback = index > 0

            do {
                let result = try await recognize(
                    request,
                    using: profile,
                    languageContext: languageContext,
                    isFallback: isFallback
                )
                let qualityScore = score(result, from: profile, request: request)
                let candidate = (result: result, score: qualityScore)
                bestCandidate = betterCandidate(bestCandidate, than: candidate)

                if shouldAccept(result, from: profile, request: request, qualityScore: qualityScore) {
                    return OCRPassSummary(acceptedResult: result, bestCandidate: bestCandidate, lastError: lastError)
                }

                guard index < profiles.count - 1 else { continue }

                DiagnosticLogger.shared.log(
                    .warning,
                    .ocr,
                    "OCR retrying with fallback profile after low-confidence result",
                    context: [
                        "profile": profile.id,
                        "confidence": String(format: "%.3f", result.averageConfidence),
                        "score": String(format: "%.3f", qualityScore)
                    ]
                )
            } catch {
                lastError = error
                guard index < profiles.count - 1 else { break }

                DiagnosticLogger.shared.log(
                    .warning,
                    .ocr,
                    "OCR retrying with fallback profile after failure",
                    context: [
                        "failedProfile": profile.id,
                        "nextProfile": profiles[index + 1].id,
                        "reason": error.localizedDescription
                    ]
                )
            }
        }

        return OCRPassSummary(acceptedResult: nil, bestCandidate: bestCandidate, lastError: lastError)
    }

    private func recognize(
        _ request: OCRRequest,
        using profile: VisionOCRProfile,
        languageContext: String,
        isFallback: Bool
    ) async throws -> OCRResult {
        DiagnosticLogger.shared.log(
            .info,
            .ocr,
            isFallback ? "OCR fallback started" : "OCR started",
            context: [
                "width": "\(request.image.width)",
                "height": "\(request.image.height)",
                "profile": profile.id,
                "language": languageContext,
                "contentType": request.contentType.rawValue
            ]
        )

        return try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false
            func resumeOnce(with result: Result<OCRResult, Error>) {
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(with: result)
            }

            let visionRequest = VNRecognizeTextRequest { visionRequest, error in
                if let error {
                    DiagnosticLogger.shared.logError(
                        .ocr,
                        error,
                        "OCR recognition failed",
                        context: ["profile": profile.id]
                    )
                    resumeOnce(with: .failure(OCRError.recognitionFailed(error)))
                    return
                }

                guard let observations = visionRequest.results as? [VNRecognizedTextObservation] else {
                    resumeOnce(with: .failure(OCRError.noTextFound))
                    return
                }

                let lines = observations.compactMap { observation -> OCRTextLine? in
                    guard let candidate = self.bestTextCandidate(for: observation, request: request) else { return nil }
                    return OCRTextLine(
                        text: candidate.string,
                        confidence: candidate.confidence,
                        boundingBox: observation.boundingBox
                    )
                }

                guard !lines.isEmpty else {
                    DiagnosticLogger.shared.log(
                        .warning,
                        .ocr,
                        "OCR completed: no text found",
                        context: ["profile": profile.id]
                    )
                    resumeOnce(with: .failure(OCRError.noTextFound))
                    return
                }

                let orderedLines = self.sortLinesForReadingOrder(lines)
                let resultText = self.formatText(from: orderedLines, request: request)
                let averageConfidence = orderedLines.map(\.confidence).reduce(0, +) / Float(orderedLines.count)
                let result = OCRResult(
                    engine: .vision,
                    profileID: profile.id,
                    text: resultText,
                    lines: orderedLines,
                    averageConfidence: averageConfidence
                )

                DiagnosticLogger.shared.log(
                    .info,
                    .ocr,
                    "OCR completed",
                    context: [
                        "profile": profile.id,
                        "lines": "\(lines.count)",
                        "chars": "\(resultText.count)",
                        "confidence": String(format: "%.3f", averageConfidence)
                    ]
                )
                resumeOnce(with: .success(result))
            }

            profile.configure(visionRequest)

            let handler = VNImageRequestHandler(cgImage: request.image, options: [:])

            do {
                try handler.perform([visionRequest])
            } catch {
                DiagnosticLogger.shared.logError(.ocr, error, "OCR handler failed", context: ["profile": profile.id])
                resumeOnce(with: .failure(OCRError.recognitionFailed(error)))
            }
        }
    }

    private func uniqueProfiles(_ profiles: [VisionOCRProfile]) -> [VisionOCRProfile] {
        var seenIDs = Set<String>()
        return profiles.filter { profile in
            seenIDs.insert(profile.id).inserted
        }
    }

    private func betterCandidate(_ lhs: OCRCandidate?, than rhs: OCRCandidate?) -> OCRCandidate? {
        switch (lhs, rhs) {
        case (nil, nil):
            nil
        case let (candidate?, nil), let (nil, candidate?):
            candidate
        case let (lhs?, rhs?):
            lhs.score >= rhs.score ? lhs : rhs
        }
    }

    private func makeContrastEnhancedImage(from image: CGImage) -> CGImage? {
        let ciImage = CIImage(cgImage: image)

        guard
            let colorControls = CIFilter(name: "CIColorControls"),
            let sharpen = CIFilter(name: "CISharpenLuminance")
        else {
            return nil
        }

        colorControls.setValue(ciImage, forKey: kCIInputImageKey)
        colorControls.setValue(0, forKey: kCIInputSaturationKey)
        colorControls.setValue(1.32, forKey: kCIInputContrastKey)
        colorControls.setValue(0.02, forKey: kCIInputBrightnessKey)

        guard let normalizedImage = colorControls.outputImage?.cropped(to: ciImage.extent) else {
            return nil
        }

        sharpen.setValue(normalizedImage, forKey: kCIInputImageKey)
        sharpen.setValue(0.45, forKey: kCIInputSharpnessKey)

        guard let outputImage = sharpen.outputImage?.cropped(to: ciImage.extent) else {
            return nil
        }

        return ciContext.createCGImage(outputImage, from: ciImage.extent)
    }
}
