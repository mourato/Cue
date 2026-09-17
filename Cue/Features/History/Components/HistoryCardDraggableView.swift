//
//  HistoryCardDraggableView.swift
//  Cue
//
//  AppKit bridge: drag a history card file into other apps.
//

import AppKit
import SwiftUI

/// Distance before a press becomes drag-to-app (keeps tap / double-click free).
enum HistoryCardDragPolicy {
    static let exportDistanceThreshold: CGFloat = 8

    static func shouldBeginExport(translation: CGSize) -> Bool {
        hypot(translation.width, translation.height) > exportDistanceThreshold
    }
}

/// Transparent monitor so SwiftUI keeps tap/selection while AppKit owns the drag session.
struct HistoryCardDraggableView: NSViewRepresentable {
    let fileURL: URL
    let thumbnail: NSImage
    let isEnabled: Bool

    func makeNSView(context _: Context) -> HistoryCardDragMonitorView {
        HistoryCardDragMonitorView(fileURL: fileURL, thumbnail: thumbnail, isEnabled: isEnabled)
    }

    func updateNSView(_ nsView: HistoryCardDragMonitorView, context _: Context) {
        nsView.fileURL = fileURL
        nsView.thumbnail = thumbnail
        nsView.isEnabled = isEnabled
    }
}

@MainActor
final class HistoryCardDragMonitorView: NSView, NSDraggingSource {
    var fileURL: URL
    var thumbnail: NSImage
    var isEnabled: Bool

    private var isDragging = false
    private var eventMonitor: Any?
    private var mouseDownLocation: NSPoint?
    private var sourceAccess: SandboxFileAccessManager.ScopedAccess?

    init(fileURL: URL, thumbnail: NSImage, isEnabled: Bool) {
        self.fileURL = fileURL
        self.thumbnail = thumbnail
        self.isEnabled = isEnabled
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateEventMonitor()
    }

    override func hitTest(_: NSPoint) -> NSView? {
        nil
    }

    isolated deinit {
        let access = sourceAccess
        sourceAccess = nil
        removeEventMonitor()
        access?.stop()
    }

    private func updateEventMonitor() {
        removeEventMonitor()
        guard window != nil else { return }

        eventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
        ) { [weak self] event in
            self?.handle(event) ?? event
        }
    }

    private func removeEventMonitor() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }

    private func handle(_ event: NSEvent) -> NSEvent {
        guard event.window === window else { return event }

        switch event.type {
        case .leftMouseDown:
            beginTrackingIfNeeded(event)
        case .leftMouseDragged:
            continueTracking(event)
        case .leftMouseUp:
            mouseDownLocation = nil
        default:
            break
        }

        return event
    }

    private func beginTrackingIfNeeded(_ event: NSEvent) {
        guard isEnabled, !event.modifierFlags.contains(.control) else {
            mouseDownLocation = nil
            return
        }

        let location = convert(event.locationInWindow, from: nil)
        guard bounds.contains(location) else {
            mouseDownLocation = nil
            return
        }

        mouseDownLocation = location
    }

    private func continueTracking(_ event: NSEvent) {
        guard isEnabled, let mouseDownLocation, !isDragging else { return }

        let location = convert(event.locationInWindow, from: nil)
        let translation = CGSize(
            width: location.x - mouseDownLocation.x,
            height: location.y - mouseDownLocation.y
        )
        guard HistoryCardDragPolicy.shouldBeginExport(translation: translation) else { return }

        beginFileDrag(with: event)
    }

    private func beginFileDrag(with event: NSEvent) {
        guard !isDragging else { return }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

        isDragging = true
        mouseDownLocation = nil
        sourceAccess = SandboxFileAccessManager.shared.beginAccessingURL(fileURL)

        let dragItem = NSDraggingItem(pasteboardWriter: fileURL as NSURL)
        let imageSize = NSSize(width: 120, height: 75)
        let dragImage = NSImage(size: imageSize)
        dragImage.lockFocus()
        thumbnail.draw(
            in: NSRect(origin: .zero, size: imageSize),
            from: .zero,
            operation: .sourceOver,
            fraction: 0.8
        )
        dragImage.unlockFocus()

        let mouseLocation = convert(event.locationInWindow, from: nil)
        dragItem.setDraggingFrame(
            NSRect(
                x: mouseLocation.x - imageSize.width / 2,
                y: mouseLocation.y - imageSize.height / 2,
                width: imageSize.width,
                height: imageSize.height
            ),
            contents: dragImage
        )

        let session = beginDraggingSession(with: [dragItem], event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
        DiagnosticLogger.shared.log(
            .info,
            .action,
            "History card drag started",
            context: ["fileName": fileURL.lastPathComponent]
        )
    }

    func draggingSession(
        _: NSDraggingSession,
        sourceOperationMaskFor _: NSDraggingContext
    ) -> NSDragOperation {
        .copy
    }

    func draggingSession(
        _: NSDraggingSession,
        endedAt _: NSPoint,
        operation: NSDragOperation
    ) {
        isDragging = false
        sourceAccess?.stop()
        sourceAccess = nil
        DiagnosticLogger.shared.log(
            .info,
            .action,
            "History card drag ended",
            context: [
                "fileName": fileURL.lastPathComponent,
                "success": operation != [] ? "true" : "false"
            ]
        )
    }
}
