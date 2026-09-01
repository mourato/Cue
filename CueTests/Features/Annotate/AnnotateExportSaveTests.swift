//
//  AnnotateExportSaveTests.swift
//  NotinhasTests
//
//  Characterization tests for AnnotateExporter render + save paths.
//  ALWAYS-RUN: renderFinalImage non-nil + dims (NO pixel equality — retina
//  pixel fidelity is already covered in AnnotateCoreTests), saveToOriginal /
//  saveToFile writing to a temp dir. saveAs remains a documented manual-only
//  path because NSSavePanel has no supported headless seam.
//

import AppKit
import CoreGraphics
@testable import Cue
import XCTest

@MainActor
final class AnnotateExportSaveTests: XCTestCase {
    private static var retainedAnnotateStates: [AnnotateState] = []

    private var tempDir: URL!
    private var pasteboard: NSPasteboard!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("NotinhasTests_ExportSave_\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        pasteboard = NSPasteboard.withUniqueName()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        pasteboard.clearContents()
        pasteboard = nil
        super.tearDown()
    }

    private func makeAnnotateState() -> AnnotateState {
        let state = AnnotateState()
        Self.retainedAnnotateStates.append(state)
        return state
    }

    private func makeImage(width: Int, height: Int) throws -> NSImage {
        let cgImage = try XCTUnwrap(TestImageFactory.solidColor(width: width, height: height))
        return NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
    }

    // MARK: - renderFinalImage (dims only)

    func testRenderFinalImageReturnsNonNilImageMatchingSourceDimensions() throws {
        let state = makeAnnotateState()
        try state.loadImage(makeImage(width: 200, height: 120))

        let rendered = try XCTUnwrap(AnnotateExporter.renderFinalImage(state: state))

        // Default state: no crop, backgroundStyle == .none (padding 0), 1x image.
        // Point-size equals source point-size; pixel dims equal source pixel dims.
        XCTAssertEqual(rendered.size.width, 200, accuracy: 0.0001)
        XCTAssertEqual(rendered.size.height, 120, accuracy: 0.0001)

        let renderedCG = try XCTUnwrap(AnnotateExporter.bestCGImage(from: rendered))
        XCTAssertEqual(renderedCG.width, 200)
        XCTAssertEqual(renderedCG.height, 120)
    }

    func testRenderFinalImageReturnsNilWhenNoSourceImage() {
        let state = makeAnnotateState()
        XCTAssertNil(AnnotateExporter.renderFinalImage(state: state))
    }

    func testRenderFinalImageWithAnnotationsKeepsSourceDimensions() throws {
        let state = makeAnnotateState()
        try state.loadImage(makeImage(width: 160, height: 160))
        state.annotations = [
            AnnotationItem(
                type: .rectangle,
                bounds: CGRect(x: 10, y: 10, width: 40, height: 40),
                properties: AnnotationProperties(),
            ),
        ]

        let rendered = try XCTUnwrap(AnnotateExporter.renderFinalImage(state: state))
        XCTAssertEqual(rendered.size.width, 160, accuracy: 0.0001)
        XCTAssertEqual(rendered.size.height, 160, accuracy: 0.0001)
    }

    func testRenderFinalImageWithMagnifyAnnotationDoesNotCrash() throws {
        let state = makeAnnotateState()
        try state.loadImage(makeImage(width: 160, height: 160))
        state.annotations = [
            AnnotationItem(
                type: .magnify(sourceCenter: CGPoint(x: 80, y: 80), showsSourceCircle: true),
                bounds: CGRect(x: 20, y: 20, width: 80, height: 80),
                properties: AnnotationProperties(),
            ),
        ]

        let rendered = try XCTUnwrap(AnnotateExporter.renderFinalImage(state: state))

        XCTAssertEqual(rendered.size.width, 160, accuracy: 0.0001)
        XCTAssertEqual(rendered.size.height, 160, accuracy: 0.0001)
    }

    func testRenderFinalImageUsesCombinedBoundsGapAndPadding() throws {
        let state = makeAnnotateState()
        try state.loadImage(makeImage(width: 200, height: 100))
        state.activateCombineMode(preferredMode: .autoStitch)
        try state.importImage(makeImage(width: 100, height: 100))
        state.setCombineDirection(.horizontal)
        state.setCombineGap(10)
        state.padding = 24

        let rendered = try XCTUnwrap(AnnotateExporter.renderFinalImage(state: state))

        XCTAssertEqual(rendered.size.width, 358, accuracy: 0.001)
        XCTAssertEqual(rendered.size.height, 148, accuracy: 0.001)
    }

    // MARK: - saveToOriginal (writes to state.sourceURL)

    func testSaveToOriginalWritesReadableFileAndReturnsTrue() throws {
        let state = makeAnnotateState()
        let url = tempDir.appendingPathComponent("capture.png")
        try state.loadImage(makeImage(width: 80, height: 60), url: url)

        let didSave = AnnotateExporter.saveToOriginal(state: state)

        XCTAssertTrue(didSave)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let reloaded = try XCTUnwrap(NSImage(contentsOf: url))
        XCTAssertGreaterThan(reloaded.size.width, 0)
        XCTAssertGreaterThan(reloaded.size.height, 0)
    }

    func testSaveToOriginalReturnsFalseWhenNoSourceURL() throws {
        let state = makeAnnotateState()
        try state.loadImage(makeImage(width: 40, height: 40)) // no URL

        XCTAssertFalse(AnnotateExporter.saveToOriginal(state: state))
    }

    // MARK: - saveToFile (writes pre-rendered image to state.sourceURL)

    func testSaveToFileWritesRenderedImageToTempURLAndReturnsTrue() throws {
        let state = makeAnnotateState()
        let url = tempDir.appendingPathComponent("background-save.png")
        try state.loadImage(makeImage(width: 100, height: 100), url: url)
        let rendered = AnnotateExporter.renderFinalImage(state: state)

        let didSave = AnnotateExporter.saveToFile(image: rendered, state: state)

        XCTAssertTrue(didSave)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let reloaded = try XCTUnwrap(NSImage(contentsOf: url))
        XCTAssertGreaterThan(reloaded.size.width, 0)
    }

    func testSaveToFileReturnsFalseWhenImageIsNil() throws {
        let state = makeAnnotateState()
        let url = tempDir.appendingPathComponent("noimage.png")
        try state.loadImage(makeImage(width: 40, height: 40), url: url)

        XCTAssertFalse(AnnotateExporter.saveToFile(image: nil, state: state))
    }

    func testSaveToFileReturnsFalseWhenNoSourceURL() throws {
        let state = makeAnnotateState()
        try state.loadImage(makeImage(width: 40, height: 40)) // no URL
        let rendered = AnnotateExporter.renderFinalImage(state: state)

        XCTAssertFalse(AnnotateExporter.saveToFile(image: rendered, state: state))
    }

    // MARK: - Clipboard / Save Panel

    /// Uses a unique pasteboard so the export contract is covered without touching
    /// the user's clipboard or depending on process-global state.
    func testCopyToClipboardWritesOneImageItem() throws {
        let state = makeAnnotateState()
        try state.loadImage(makeImage(width: 50, height: 50))

        AnnotateExporter.copyToClipboard(state: state, to: pasteboard)

        let item = try XCTUnwrap(pasteboard.pasteboardItems?.first)
        XCTAssertEqual(pasteboard.pasteboardItems?.count, 1)
        XCTAssertTrue(item.types.contains(.fileURL))
        XCTAssertTrue(item.types.contains(.png))
        XCTAssertTrue(item.types.contains(.tiff))
    }

    /// Manual exception: run `open Notinhas.xcodeproj`, launch the app, open an
    /// annotation, choose Save As, then cancel or complete the panel interaction.
    func testSaveAsRequiresManualInteraction() throws {
        throw XCTSkip("NSSavePanel is modal and has no supported headless seam")
    }
}
