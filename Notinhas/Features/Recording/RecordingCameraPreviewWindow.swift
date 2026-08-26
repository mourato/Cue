#if NOTINHAS_VIDEO_MODULE
    import AppKit
    import AVFoundation

    enum RecordingCameraPreviewSize: String, CaseIterable, Identifiable {
        case small, medium, large, huge

        var id: String {
            rawValue
        }

        var displayName: String {
            switch self {
            case .small: L10n.Camera.small
            case .medium: L10n.Camera.medium
            case .large: L10n.Camera.large
            case .huge: L10n.Camera.huge
            }
        }

        fileprivate var widthFraction: CGFloat {
            switch self {
            case .small: 0.28
            case .medium: 0.34
            case .large: 0.42
            case .huge: 0.50
            }
        }

        fileprivate var maximumWidth: CGFloat {
            switch self {
            case .small: 240
            case .medium: 320
            case .large: 400
            case .huge: 480
            }
        }
    }

    enum RecordingCameraPreviewShape: String, CaseIterable, Identifiable {
        case circle, square, rectangle, vertical

        var id: String {
            rawValue
        }

        var displayName: String {
            switch self {
            case .circle: L10n.Camera.circle
            case .square: L10n.Camera.square
            case .rectangle: L10n.Camera.rectangle
            case .vertical: L10n.Camera.vertical
            }
        }

        fileprivate var aspectRatio: CGFloat {
            switch self {
            case .circle, .square: 1
            case .rectangle: 16 / 9
            case .vertical: 9 / 16
            }
        }
    }

    struct RecordingCameraPreviewConfiguration: Equatable {
        var size: RecordingCameraPreviewSize = .small
        var shape: RecordingCameraPreviewShape = .rectangle

        static let `default` = Self()
    }

    enum RecordingCameraPreviewPlacement {
        static let inset: CGFloat = 16

        static func frame(
            in selectionRect: CGRect,
            configuration: RecordingCameraPreviewConfiguration = .default,
        ) -> CGRect {
            guard !selectionRect.isEmpty else { return .zero }

            let availableWidth = max(0, selectionRect.width - inset * 2)
            let availableHeight = max(0, selectionRect.height - inset * 2)
            let desiredWidth = min(configuration.size.maximumWidth, availableWidth * configuration.size.widthFraction)
            let desiredHeight = desiredWidth / configuration.shape.aspectRatio
            let scale = min(
                1,
                availableWidth / max(desiredWidth, 1),
                availableHeight / max(desiredHeight, 1),
            )
            let fittedWidth = desiredWidth * scale
            let fittedHeight = desiredHeight * scale

            guard fittedWidth > 0, fittedHeight > 0 else { return .zero }

            return CGRect(
                x: selectionRect.maxX - fittedWidth - inset,
                y: selectionRect.minY + inset,
                width: fittedWidth,
                height: fittedHeight,
            )
        }

        static func frame(
            in selectionRect: CGRect,
            configuration: RecordingCameraPreviewConfiguration,
            normalizedCenter: CGPoint?,
        ) -> CGRect {
            let fittedFrame = frame(in: selectionRect, configuration: configuration)
            guard let normalizedCenter, !fittedFrame.isEmpty else { return fittedFrame }

            return clampedFrame(
                CGRect(
                    x: selectionRect.minX + normalizedCenter.x * selectionRect.width - fittedFrame.width / 2,
                    y: selectionRect.minY + normalizedCenter.y * selectionRect.height - fittedFrame.height / 2,
                    width: fittedFrame.width,
                    height: fittedFrame.height,
                ),
                in: selectionRect,
            )
        }

        static func clampedOrigin(_ origin: CGPoint, size: CGSize, in selectionRect: CGRect) -> CGPoint {
            guard !selectionRect.isEmpty else { return origin }

            let bounds = selectionRect.insetBy(dx: inset, dy: inset)
            return CGPoint(
                x: min(max(origin.x, bounds.minX), max(bounds.minX, bounds.maxX - size.width)),
                y: min(max(origin.y, bounds.minY), max(bounds.minY, bounds.maxY - size.height)),
            )
        }

        static func clampedFrame(_ frame: CGRect, in selectionRect: CGRect) -> CGRect {
            CGRect(
                origin: clampedOrigin(frame.origin, size: frame.size, in: selectionRect),
                size: frame.size,
            )
        }
    }

    nonisolated enum RecordingCameraPreviewSetupError: Error {
        case noDevice
        case cannotAddInput
    }

    /// Owns the camera session separately from the recording writer so the user can
    /// verify framing before pressing Record. It has no data output: the preview layer
    /// consumes the session directly and the writer creates its own session later.
    final nonisolated class RecordingCameraPreviewSession: @unchecked Sendable {
        let session: AVCaptureSession
        private let sessionQueue = DispatchQueue(
            label: "com.mourato.notinhas.camera.preview",
            qos: .userInteractive,
        )

        init(deviceID: String?) throws {
            let captureSession = AVCaptureSession()
            guard let device = RecordingCameraDeviceProvider.device(matching: deviceID) else {
                throw RecordingCameraPreviewSetupError.noDevice
            }

            let input = try AVCaptureDeviceInput(device: device)
            guard captureSession.canAddInput(input) else {
                throw RecordingCameraPreviewSetupError.cannotAddInput
            }

            if captureSession.canSetSessionPreset(.high) {
                captureSession.sessionPreset = .high
            }
            captureSession.beginConfiguration()
            captureSession.addInput(input)
            captureSession.commitConfiguration()
            session = captureSession
        }

        func start() {
            sessionQueue.async { [session] in
                guard !session.isRunning else { return }
                session.startRunning()
            }
        }

        func stop() {
            sessionQueue.sync { [session] in
                guard session.isRunning else { return }
                session.stopRunning()
            }
        }
    }

    @MainActor
    final class RecordingCameraPreviewWindow: NSPanel {
        let deviceID: String

        private let cameraSession: RecordingCameraPreviewSession
        private let previewLayer: AVCaptureVideoPreviewLayer
        private var selectionRect: CGRect
        private var configuration: RecordingCameraPreviewConfiguration
        private var previewView: RecordingCameraPreviewView!

        var onConfigurationChanged: ((RecordingCameraPreviewConfiguration) -> Void)?

        init?(
            deviceID: String?,
            selectionRect: CGRect,
            configuration: RecordingCameraPreviewConfiguration = .default,
            normalizedCenter: CGPoint? = nil,
        ) {
            guard let cameraSession = try? RecordingCameraPreviewSession(deviceID: deviceID) else {
                return nil
            }

            self.deviceID = deviceID ?? RecordingCameraDeviceProvider.systemDefaultID
            self.cameraSession = cameraSession
            previewLayer = AVCaptureVideoPreviewLayer(session: cameraSession.session)
            self.selectionRect = selectionRect
            self.configuration = configuration

            super.init(
                contentRect: RecordingCameraPreviewPlacement.frame(
                    in: selectionRect,
                    configuration: configuration,
                    normalizedCenter: normalizedCenter,
                ),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false,
            )

            configureWindow()

            let previewView = RecordingCameraPreviewView(frame: .zero)
            self.previewView = previewView
            previewView.wantsLayer = true
            previewView.layer?.masksToBounds = true
            previewView.layer?.borderColor = NSColor.white.withAlphaComponent(0.75).cgColor
            previewView.layer?.borderWidth = 1
            previewView.onMouseDown = { [weak self] event in self?.beginDrag(with: event) }
            previewView.onMouseDragged = { [weak self] event in self?.continueDrag(with: event) }
            previewView.onMouseUp = { [weak self] in self?.endDrag() }
            previewView.contextMenuProvider = { [weak self] in self?.makeContextMenu() }
            previewView.onAccessibilityMove = { [weak self] delta in
                self?.movePreview(by: delta) ?? false
            }
            previewView.customAccessibilityActions = [
                NSAccessibilityCustomAction(name: L10n.Camera.moveLeft) { [weak self] in
                    self?.movePreview(by: CGPoint(x: -0.05, y: 0)) ?? false
                },
                NSAccessibilityCustomAction(name: L10n.Camera.moveRight) { [weak self] in
                    self?.movePreview(by: CGPoint(x: 0.05, y: 0)) ?? false
                },
                NSAccessibilityCustomAction(name: L10n.Camera.moveUp) { [weak self] in
                    self?.movePreview(by: CGPoint(x: 0, y: 0.05)) ?? false
                },
                NSAccessibilityCustomAction(name: L10n.Camera.moveDown) { [weak self] in
                    self?.movePreview(by: CGPoint(x: 0, y: -0.05)) ?? false
                },
            ]

            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame = previewView.bounds
            previewView.layer?.addSublayer(previewLayer)
            contentView = previewView
            previewLayer.frame = previewView.bounds
            updatePreviewAppearance()
        }

        func start() {
            orderFrontRegardless()
            cameraSession.start()
        }

        override func close() {
            endDrag()
            cameraSession.stop()
            super.close()
        }

        var normalizedCenter: CGPoint? {
            guard !selectionRect.isEmpty, !frame.isEmpty else { return nil }
            return CGPoint(
                x: (frame.midX - selectionRect.minX) / max(selectionRect.width, 1),
                y: (frame.midY - selectionRect.minY) / max(selectionRect.height, 1),
            )
        }

        func updateSelectionRect(_ selectionRect: CGRect) {
            let currentCenter = normalizedCenter
            self.selectionRect = selectionRect

            let previewFrame = RecordingCameraPreviewPlacement.frame(
                in: selectionRect,
                configuration: configuration,
                normalizedCenter: currentCenter,
            )

            guard !previewFrame.isEmpty else {
                orderOut(nil)
                return
            }

            applyFrame(RecordingCameraPreviewPlacement.clampedFrame(previewFrame, in: selectionRect))
            orderFrontRegardless()
        }

        func updateConfiguration(_ configuration: RecordingCameraPreviewConfiguration) {
            guard self.configuration != configuration else { return }

            let currentCenter = normalizedCenter
            self.configuration = configuration
            let resizedFrame = RecordingCameraPreviewPlacement.frame(
                in: selectionRect,
                configuration: configuration,
                normalizedCenter: currentCenter,
            )
            applyFrame(resizedFrame)
        }

        private func makeContextMenu() -> NSMenu {
            let menu = NSMenu()
            menu.autoenablesItems = false

            let sizeHeader = NSMenuItem(title: L10n.Camera.previewSize, action: nil, keyEquivalent: "")
            sizeHeader.isEnabled = false
            menu.addItem(sizeHeader)

            for size in RecordingCameraPreviewSize.allCases {
                let item = NSMenuItem(
                    title: size.displayName,
                    action: #selector(selectPreviewSize(_:)),
                    keyEquivalent: "",
                )
                item.target = self
                item.representedObject = size.rawValue
                item.state = configuration.size == size ? .on : .off
                menu.addItem(item)
            }

            menu.addItem(.separator())

            let shapeHeader = NSMenuItem(title: L10n.Camera.previewShape, action: nil, keyEquivalent: "")
            shapeHeader.isEnabled = false
            menu.addItem(shapeHeader)

            for shape in RecordingCameraPreviewShape.allCases {
                let item = NSMenuItem(
                    title: shape.displayName,
                    action: #selector(selectPreviewShape(_:)),
                    keyEquivalent: "",
                )
                item.target = self
                item.representedObject = shape.rawValue
                item.state = configuration.shape == shape ? .on : .off
                menu.addItem(item)
            }

            return menu
        }

        @objc private func selectPreviewSize(_ sender: NSMenuItem) {
            guard let rawValue = sender.representedObject as? String,
                  let size = RecordingCameraPreviewSize(rawValue: rawValue)
            else { return }

            let nextConfiguration = RecordingCameraPreviewConfiguration(
                size: size,
                shape: configuration.shape,
            )
            updateConfiguration(nextConfiguration)
            onConfigurationChanged?(nextConfiguration)
        }

        @objc private func selectPreviewShape(_ sender: NSMenuItem) {
            guard let rawValue = sender.representedObject as? String,
                  let shape = RecordingCameraPreviewShape(rawValue: rawValue)
            else { return }

            let nextConfiguration = RecordingCameraPreviewConfiguration(
                size: configuration.size,
                shape: shape,
            )
            updateConfiguration(nextConfiguration)
            onConfigurationChanged?(nextConfiguration)
        }

        private func configureWindow() {
            isFloatingPanel = true
            isOpaque = false
            backgroundColor = .clear
            sharingType = .none
            level = .popUpMenu
            ignoresMouseEvents = false
            hasShadow = true
            hidesOnDeactivate = false
            isReleasedWhenClosed = false
            collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            animationBehavior = .none
        }

        override var canBecomeKey: Bool {
            false
        }

        override var canBecomeMain: Bool {
            false
        }

        private func applyFrame(_ frame: CGRect) {
            setFrame(frame, display: true)
            previewLayer.frame = contentView?.bounds ?? .zero
            updatePreviewAppearance()
        }

        private func updatePreviewAppearance() {
            let radius = configuration.shape == .circle
                ? min(previewView.bounds.width, previewView.bounds.height) / 2
                : ToolbarConstants.buttonCornerRadius
            previewView.layer?.cornerRadius = radius
            previewView.setAccessibilityElement(true)
            previewView.setAccessibilityRole(.group)
            previewView.setAccessibilityLabel(L10n.Camera.preview)
            previewView.setAccessibilityHelp(L10n.Camera.previewDragHint)
            previewView.setAccessibilityValue(previewAccessibilityValue())
            previewView.setAccessibilityValueDescription(L10n.Camera.preview)
        }

        private func previewAccessibilityValue() -> String {
            guard let normalizedCenter else { return L10n.Camera.preview }
            return L10n.format(
                "camera.preview-position",
                defaultValue: "Horizontal %d%%, vertical %d%%",
                comment: "Accessibility value for the camera preview position",
                Int(normalizedCenter.x * 100),
                Int(normalizedCenter.y * 100),
            )
        }

        private func movePreview(by delta: CGPoint) -> Bool {
            guard !selectionRect.isEmpty, !frame.isEmpty else { return false }

            let currentCenter = normalizedCenter ?? CGPoint(x: 0.5, y: 0.5)
            let nextCenter = CGPoint(
                x: min(max(currentCenter.x + delta.x, 0), 1),
                y: min(max(currentCenter.y + delta.y, 0), 1),
            )
            let nextFrame = RecordingCameraPreviewPlacement.frame(
                in: selectionRect,
                configuration: configuration,
                normalizedCenter: nextCenter,
            )
            guard !nextFrame.isEmpty else { return false }

            applyFrame(nextFrame)
            return true
        }

        private func beginDrag(with _: NSEvent) {
            dragStartMouseLocation = NSEvent.mouseLocation
            dragStartFrameOrigin = frame.origin
            NSCursor.closedHand.push()
        }

        private func continueDrag(with _: NSEvent) {
            let origin = CGPoint(
                x: dragStartFrameOrigin.x + NSEvent.mouseLocation.x - dragStartMouseLocation.x,
                y: dragStartFrameOrigin.y + NSEvent.mouseLocation.y - dragStartMouseLocation.y,
            )
            setFrameOrigin(RecordingCameraPreviewPlacement.clampedOrigin(origin, size: frame.size, in: selectionRect))
            updatePreviewAppearance()
        }

        private var dragStartMouseLocation: CGPoint = .zero
        private var dragStartFrameOrigin: CGPoint = .zero

        private func endDrag() {
            if dragStartMouseLocation != .zero {
                NSCursor.pop()
            }
            dragStartMouseLocation = .zero
            dragStartFrameOrigin = .zero
        }
    }

    @MainActor
    private final class RecordingCameraPreviewView: NSView {
        var onMouseDown: ((NSEvent) -> Void)?
        var onMouseDragged: ((NSEvent) -> Void)?
        var onMouseUp: (() -> Void)?
        var contextMenuProvider: (() -> NSMenu?)?
        var onAccessibilityMove: ((CGPoint) -> Bool)?
        var customAccessibilityActions: [NSAccessibilityCustomAction] = []

        override func mouseDown(with event: NSEvent) {
            onMouseDown?(event)
        }

        override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
            true
        }

        override func mouseDragged(with event: NSEvent) {
            onMouseDragged?(event)
        }

        override func mouseUp(with _: NSEvent) {
            onMouseUp?()
        }

        override func menu(for _: NSEvent) -> NSMenu? {
            contextMenuProvider?()
        }

        override func accessibilityCustomActions() -> [NSAccessibilityCustomAction]? {
            customAccessibilityActions
        }

        override func accessibilityPerformIncrement() -> Bool {
            onAccessibilityMove?(CGPoint(x: 0.05, y: 0)) ?? false
        }

        override func accessibilityPerformDecrement() -> Bool {
            onAccessibilityMove?(CGPoint(x: -0.05, y: 0)) ?? false
        }
    }
#endif
