#if CUE_VIDEO_MODULE
//
    //  RecordingCountdownWindow.swift
    //  Notinhas
//
    //  Borderless overlay showing a 3-2-1 countdown centered on the selection
    //  before recording starts (see `recording.showCountdown`).
//

    import AppKit

    /// Modal-style countdown shown when the Show-Countdown preference is on.
    /// Runs on the MainActor; each step displays for one second.
    @MainActor
    final class RecordingCountdownWindow: NSPanel {
        private static let windowSize = CGSize(width: 200, height: 160)

        private let label: NSTextField = {
            let field = NSTextField(labelWithString: "")
            field.font = .systemFont(ofSize: 96, weight: .semibold)
            field.textColor = .white
            field.alignment = .center
            field.backgroundColor = .clear
            field.isBordered = false
            return field
        }()

        override init(
            contentRect: NSRect,
            styleMask style: NSWindow.StyleMask,
            backing bufferingType: NSWindow.BackingStoreType,
            defer flag: Bool,
        ) {
            super.init(contentRect: contentRect, styleMask: style, backing: bufferingType, defer: flag)
        }

        convenience init() {
            self.init(
                contentRect: CGRect(origin: .zero, size: Self.windowSize),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false,
            )
            isOpaque = false
            backgroundColor = .clear
            hasShadow = false
            level = .popUpMenu
            ignoresMouseEvents = true
            collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            animationBehavior = .none
            isReleasedWhenClosed = false
            contentView = label
        }

        /// Shows 3-2-1 centered on `rect`, then hides. Returns false when cancelled.
        func run(in rect: CGRect) async -> Bool {
            centerOn(rect)
            for step in [3, 2, 1] {
                guard !Task.isCancelled else {
                    orderOut(nil)
                    return false
                }
                label.stringValue = "\(step)"
                label.sizeToFit()
                orderFrontRegardless()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            orderOut(nil)
            return !Task.isCancelled
        }

        private func centerOn(_ rect: CGRect) {
            let screen = NSScreen.screens.first(where: { $0.frame.intersects(rect) })
            let bounds = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? rect
            var origin = CGPoint(
                x: rect.midX - Self.windowSize.width / 2,
                y: rect.midY - Self.windowSize.height / 2,
            )
            origin.x = min(max(origin.x, bounds.minX), bounds.maxX - Self.windowSize.width)
            origin.y = min(max(origin.y, bounds.minY), bounds.maxY - Self.windowSize.height)
            setFrame(CGRect(origin: origin, size: Self.windowSize), display: true)
        }
    }
#endif
