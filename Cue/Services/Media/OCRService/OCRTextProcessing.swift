//
//  OCRTextProcessing.swift
//  Notinhas
//
//  Text candidate selection, scoring, reading order, and formatting
//  helpers colocated with the OCRService actor.
//

import CoreGraphics
import Foundation
import Vision

/// Text-processing helpers for `OCRService`.
///
/// These helpers keep the actor isolation of `OCRService`; the split only
/// colocates the text pipeline so no single file grows past the size limit.
extension OCRService {
    // MARK: - Text Candidates and Scoring

    func bestTextCandidate(
        for observation: VNRecognizedTextObservation,
        request: OCRRequest
    ) -> VNRecognizedText? {
        let candidates = observation.topCandidates(5)
        guard let topCandidate = candidates.first else { return nil }
        let preferredLanguage = AppLanguageManager
            .normalizedLanguageIdentifier(from: request.preferredLanguageIdentifier)

        guard shouldPreferDiacriticCandidates(for: preferredLanguage) else {
            return topCandidate
        }

        return candidates
            .filter { isViableDiacriticAlternative($0, topCandidate: topCandidate) }
            .max {
                languageCandidateScore($0, preferredLanguage: preferredLanguage)
                    < languageCandidateScore($1, preferredLanguage: preferredLanguage)
            }
            ?? topCandidate
    }

    private func shouldPreferDiacriticCandidates(for languageIdentifier: String?) -> Bool {
        switch languageIdentifier {
        case "vi", "es", "fr", "de":
            true
        default:
            false
        }
    }

    private func isViableDiacriticAlternative(_ candidate: VNRecognizedText, topCandidate: VNRecognizedText) -> Bool {
        guard candidate.confidence >= topCandidate.confidence - 0.28 else { return false }

        let candidateText = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
        let topText = topCandidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidateText.isEmpty, !topText.isEmpty else { return false }

        if candidateText == topText {
            return true
        }

        let foldedCandidate = foldedForDiacriticComparison(candidateText)
        let foldedTop = foldedForDiacriticComparison(topText)
        guard foldedCandidate == foldedTop else { return false }

        return diacriticMarkCount(in: candidateText) >= diacriticMarkCount(in: topText)
    }

    private func languageCandidateScore(_ candidate: VNRecognizedText, preferredLanguage: String?) -> Float {
        var score = candidate.confidence
        let text = candidate.string

        if shouldPreferDiacriticCandidates(for: preferredLanguage) {
            score += min(Float(diacriticMarkCount(in: text)) * 0.025, 0.18)
        }

        if preferredLanguage == "vi", containsVietnameseToneOrVowelMark(in: text) {
            score += 0.08
        }

        return score
    }

    private func foldedForDiacriticComparison(_ text: String) -> String {
        text
            .folding(
                options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
            .filter { !$0.isWhitespace }
    }

    private func diacriticMarkCount(in text: String) -> Int {
        text.decomposedStringWithCanonicalMapping.unicodeScalars.reduce(into: 0) { count, scalar in
            if CharacterSet.nonBaseCharacters.contains(scalar) {
                count += 1
            }
        }
    }

    private func containsVietnameseToneOrVowelMark(in text: String) -> Bool {
        text.range(
            of: "[ăâđêôơưĂÂĐÊÔƠƯàáảãạằắẳẵặầấẩẫậèéẻẽẹềếểễệìíỉĩịòóỏõọồốổỗộờớởỡợùúủũụừứửữựỳýỷỹỵ]",
            options: .regularExpression
        ) != nil
    }

    func shouldAccept(
        _ result: OCRResult,
        from profile: VisionOCRProfile,
        request: OCRRequest,
        qualityScore: Float
    ) -> Bool {
        let trimmedText = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedText.isEmpty {
            return false
        }

        if meaningfulCharacterCount(in: trimmedText) == 0 {
            return false
        }

        if request.contentType == .code {
            return result.averageConfidence >= profile.minimumAcceptableConfidence
        }

        return qualityScore >= profile.minimumAcceptableConfidence
    }

    func score(_ result: OCRResult, from profile: VisionOCRProfile, request: OCRRequest) -> Float {
        let trimmedText = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return 0 }

        let meaningfulCharacters = meaningfulCharacterCount(in: trimmedText)
        let cjkCharacters = cjkCharacterCount(in: trimmedText)
        let lineCount = max(result.lines.count, 1)
        let averageLineLength = Float(meaningfulCharacters) / Float(lineCount)
        let preferredLanguage = AppLanguageManager
            .normalizedLanguageIdentifier(from: request.preferredLanguageIdentifier)

        var qualityScore = result.averageConfidence

        switch meaningfulCharacters {
        case 24...:
            qualityScore += 0.18
        case 12...:
            qualityScore += 0.10
        case 4...:
            qualityScore += 0.04
        default:
            qualityScore -= 0.06
        }

        if averageLineLength >= 10 {
            qualityScore += 0.06
        } else if averageLineLength < 1.5 {
            qualityScore -= 0.08
        }

        if cjkCharacters > 0 {
            qualityScore += 0.05
        }

        if profile.prefersCJKContent {
            qualityScore += cjkCharacters > 0 ? 0.08 : -0.12
        }

        if let preferredLanguage, isCJKLanguage(preferredLanguage) {
            if containsExpectedScript(for: preferredLanguage, in: trimmedText) {
                qualityScore += 0.12
            } else if cjkCharacters == 0 {
                qualityScore -= 0.10
            }
        }

        return qualityScore
    }

    // MARK: - Reading Order and Formatting

    func sortLinesForReadingOrder(_ lines: [OCRTextLine]) -> [OCRTextLine] {
        lines.sorted { lhs, rhs in
            let verticalDelta = abs(lhs.boundingBox.midY - rhs.boundingBox.midY)
            let rowTolerance = max(lhs.boundingBox.height, rhs.boundingBox.height) * 0.6
            if verticalDelta > rowTolerance {
                return lhs.boundingBox.maxY > rhs.boundingBox.maxY
            }
            return lhs.boundingBox.minX < rhs.boundingBox.minX
        }
    }

    func formatText(from lines: [OCRTextLine], request: OCRRequest) -> String {
        guard request.keepLineBreaks else {
            return lines.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        }
        let paragraphs = groupParagraphs(from: lines)
        let formattedParagraphs = paragraphs.map { paragraph -> String in
            if shouldReflowParagraph(paragraph, request: request) {
                return reflowedParagraphText(from: paragraph, request: request)
            }
            return paragraph
                .map(\.text)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .joined(separator: "\n")
        }

        return formattedParagraphs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    private func groupParagraphs(from lines: [OCRTextLine]) -> [[OCRTextLine]] {
        guard !lines.isEmpty else { return [] }

        let averageHeight = lines.map(\.boundingBox.height).reduce(0, +) / CGFloat(lines.count)
        var paragraphs: [[OCRTextLine]] = []
        var currentParagraph = [lines[0]]

        for line in lines.dropFirst() {
            guard let previousLine = currentParagraph.last else { continue }
            let verticalGap = previousLine.boundingBox.minY - line.boundingBox.maxY
            let paragraphThreshold = max(
                averageHeight * 0.75,
                max(previousLine.boundingBox.height, line.boundingBox.height) * 0.68
            )

            if verticalGap > paragraphThreshold {
                paragraphs.append(currentParagraph)
                currentParagraph = [line]
            } else {
                currentParagraph.append(line)
            }
        }

        paragraphs.append(currentParagraph)
        return paragraphs
    }

    private func shouldReflowParagraph(_ paragraph: [OCRTextLine], request: OCRRequest) -> Bool {
        guard paragraph.count > 1 else { return false }

        if isSingleVisualRow(paragraph) {
            return true
        }

        let averageWidth = paragraph.map(\.boundingBox.width).reduce(0, +) / CGFloat(paragraph.count)
        let longestLineLength = paragraph.map { meaningfulCharacterCount(in: $0.text) }.max() ?? 0
        let preferredLanguage = AppLanguageManager
            .normalizedLanguageIdentifier(from: request.preferredLanguageIdentifier)
        let paragraphText = paragraph.map(\.text).joined()
        let cjkWeight = cjkCharacterCount(in: paragraphText)
        let isLikelyCJK = (preferredLanguage.map(isCJKLanguage) ?? false) || cjkWeight >= max(
            6,
            meaningfulCharacterCount(in: paragraphText) / 3
        )

        if isLikelyCJK {
            return averageWidth >= 0.24 || paragraph.count >= 3
        }

        return averageWidth >= 0.36 || longestLineLength >= 28 || paragraph.count >= 4
    }

    private func isSingleVisualRow(_ paragraph: [OCRTextLine]) -> Bool {
        guard paragraph.count > 1 else { return false }

        let minY = paragraph.map(\.boundingBox.minY).min() ?? 0
        let maxY = paragraph.map(\.boundingBox.maxY).max() ?? 0
        let averageHeight = paragraph.map(\.boundingBox.height).reduce(0, +) / CGFloat(paragraph.count)
        guard averageHeight > 0 else { return false }

        return maxY - minY <= averageHeight * 1.45
    }

    private func reflowedParagraphText(from paragraph: [OCRTextLine], request: OCRRequest) -> String {
        let paragraphText = paragraph.map(\.text).joined()
        let preferredLanguage = AppLanguageManager
            .normalizedLanguageIdentifier(from: request.preferredLanguageIdentifier)
        let isLikelyCJK = (preferredLanguage.map(isCJKLanguage) ?? false) || cjkCharacterCount(in: paragraphText) >=
            max(
                6,
                meaningfulCharacterCount(in: paragraphText) / 3
            )
        let separator = isLikelyCJK ? "" : " "

        return paragraph.reduce(into: "") { text, line in
            let nextFragment = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !nextFragment.isEmpty else { return }
            guard !text.isEmpty else {
                text = nextFragment
                return
            }

            if separator.isEmpty {
                text += nextFragment
            } else if text.hasSuffix("-") {
                text.removeLast()
                text += nextFragment
            } else if let firstScalar = nextFragment.unicodeScalars.first,
                      leadingInlinePunctuation.contains(firstScalar)
            {
                text += nextFragment
            } else {
                text += separator + nextFragment
            }
        }
    }

    private var leadingInlinePunctuation: CharacterSet {
        CharacterSet(charactersIn: ",.;:!?)]}%")
    }

    // MARK: - Unicode Script Helpers

    private func meaningfulCharacterCount(in text: String) -> Int {
        text.unicodeScalars.reduce(into: 0) { count, scalar in
            guard !CharacterSet.whitespacesAndNewlines.contains(scalar) else { return }
            if CharacterSet.alphanumerics
                .contains(scalar) || isCJKScalar(scalar) || isKanaScalar(scalar) || isHangulScalar(scalar)
            {
                count += 1
            }
        }
    }

    private func cjkCharacterCount(in text: String) -> Int {
        text.unicodeScalars.reduce(into: 0) { count, scalar in
            if isCJKScalar(scalar) || isKanaScalar(scalar) || isHangulScalar(scalar) {
                count += 1
            }
        }
    }

    private func containsExpectedScript(for languageIdentifier: String, in text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            switch languageIdentifier {
            case "ja":
                isCJKScalar(scalar) || isKanaScalar(scalar)
            case "ko":
                isHangulScalar(scalar)
            case "zh-Hans", "zh-Hant":
                isCJKScalar(scalar)
            default:
                true
            }
        }
    }

    private func isCJKLanguage(_ languageIdentifier: String) -> Bool {
        switch languageIdentifier {
        case "ja", "ko", "zh-Hans", "zh-Hant":
            true
        default:
            false
        }
    }

    private func isCJKScalar(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x3400 ... 0x4DBF, 0x4E00 ... 0x9FFF, 0xF900 ... 0xFAFF:
            true
        default:
            false
        }
    }

    private func isKanaScalar(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x3040 ... 0x309F, 0x30A0 ... 0x30FF:
            true
        default:
            false
        }
    }

    private func isHangulScalar(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x1100 ... 0x11FF, 0x3130 ... 0x318F, 0xAC00 ... 0xD7AF:
            true
        default:
            false
        }
    }
}
