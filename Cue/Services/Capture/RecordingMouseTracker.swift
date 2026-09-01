#if CUE_VIDEO_MODULE
//
    //  RecordingMouseTracker.swift
    //  Notinhas
//
    //  Polls the global mouse location while recording so the editor can
    //  reconstruct a smooth follow-camera path later, and records discrete
    //  click events for automatic zoom synthesis.
//

    import AppKit
    import Foundation

    struct RecordingMouseTrackingStopResult: Equatable {
        let samples: [RecordedMouseSample]
        let presses: [RecordedMousePress]
    }

    @MainActor
    final class RecordingMouseTracker {
        struct TrackingDiagnostics {
            let sampleCount: Int
            let duration: TimeInterval
            let effectiveSamplesPerSecond: Double
            let averageIntervalMs: Double
            let p95IntervalMs: Double
        }

        private let recordingRect: CGRect
        private let samplesPerSecondValue: Int
        private let sampleInterval: TimeInterval
        private let uptimeProvider: () -> TimeInterval
        private let mouseLocationProvider: () -> CGPoint
        private let mouseMonitorInstaller: (@escaping () -> Void) -> Any?
        private let mouseMonitorRemover: (Any) -> Void
        private let pressMonitorInstaller: (@escaping (NSEvent) -> Void) -> Any?
        private let pressMonitorRemover: (Any) -> Void

        private var timer: Timer?
        private var globalMouseMonitor: Any?
        private var pressMonitor: Any?
        private var localPressMonitor: Any?
        private var samples: [RecordedMouseSample] = []
        private var presses: [RecordedMousePress] = []
        private var startUptime: TimeInterval?
        private var pausedAtUptime: TimeInterval?
        private var accumulatedPausedDuration: TimeInterval = 0
        private(set) var diagnostics: TrackingDiagnostics?

        nonisolated static func resolvedSamplesPerSecond(for fps: Int) -> Int {
            min(max(fps * 2, 60), 120)
        }

        init(
            recordingRect: CGRect,
            fps: Int,
            uptimeProvider: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
            mouseLocationProvider: @escaping () -> CGPoint = { NSEvent.mouseLocation },
            mouseMonitorInstaller: @escaping (@escaping () -> Void) -> Any? = { onMouseEvent in
                NSEvent.addGlobalMonitorForEvents(
                    matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged],
                ) { _ in
                    onMouseEvent()
                }
            },
            mouseMonitorRemover: @escaping (Any) -> Void = { NSEvent.removeMonitor($0) },
            pressMonitorInstaller: @escaping (@escaping (NSEvent) -> Void) -> Any? = { handler in
                NSEvent.addGlobalMonitorForEvents(
                    matching: [.leftMouseDown, .rightMouseDown, .leftMouseUp, .rightMouseUp],
                ) { event in
                    handler(event)
                }
            },
            pressMonitorRemover: @escaping (Any) -> Void = { NSEvent.removeMonitor($0) },
        ) {
            self.recordingRect = recordingRect
            let samplesPerSecond = Self.resolvedSamplesPerSecond(for: fps)
            samplesPerSecondValue = samplesPerSecond
            sampleInterval = 1.0 / Double(samplesPerSecond)
            self.uptimeProvider = uptimeProvider
            self.mouseLocationProvider = mouseLocationProvider
            self.mouseMonitorInstaller = mouseMonitorInstaller
            self.mouseMonitorRemover = mouseMonitorRemover
            self.pressMonitorInstaller = pressMonitorInstaller
            self.pressMonitorRemover = pressMonitorRemover
        }

        var samplesPerSecond: Int {
            samplesPerSecondValue
        }

        func start() {
            reset()

            startUptime = uptimeProvider()
            appendCurrentSample(force: true, location: nil)
            installGlobalMouseMonitor()
            installPressMonitor()

            let timer = Timer(timeInterval: sampleInterval, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.appendCurrentSample(force: false, location: nil)
                }
            }
            self.timer = timer
            RunLoop.main.add(timer, forMode: .common)
        }

        func pause() {
            guard startUptime != nil, pausedAtUptime == nil else { return }
            appendCurrentSample(force: true, location: nil)
            pausedAtUptime = uptimeProvider()
        }

        func resume() {
            guard let pausedAtUptime else { return }

            accumulatedPausedDuration += uptimeProvider() - pausedAtUptime
            self.pausedAtUptime = nil
            appendCurrentSample(force: true, location: nil)
        }

        func stop() -> RecordingMouseTrackingStopResult {
            appendCurrentSample(force: true, location: nil)
            timer?.invalidate()
            timer = nil
            if let globalMouseMonitor {
                mouseMonitorRemover(globalMouseMonitor)
                self.globalMouseMonitor = nil
            }
            if let pressMonitor {
                pressMonitorRemover(pressMonitor)
                self.pressMonitor = nil
            }
            if let localPressMonitor {
                NSEvent.removeMonitor(localPressMonitor)
                self.localPressMonitor = nil
            }
            pausedAtUptime = nil
            diagnostics = buildDiagnostics(from: samples)
            return RecordingMouseTrackingStopResult(samples: samples, presses: presses)
        }

        func reset() {
            timer?.invalidate()
            timer = nil
            if let globalMouseMonitor {
                mouseMonitorRemover(globalMouseMonitor)
                self.globalMouseMonitor = nil
            }
            if let pressMonitor {
                pressMonitorRemover(pressMonitor)
                self.pressMonitor = nil
            }
            if let localPressMonitor {
                NSEvent.removeMonitor(localPressMonitor)
                self.localPressMonitor = nil
            }
            samples.removeAll(keepingCapacity: true)
            presses.removeAll(keepingCapacity: true)
            startUptime = nil
            pausedAtUptime = nil
            accumulatedPausedDuration = 0
            diagnostics = nil
        }

        private func appendCurrentSample(force: Bool, location: CGPoint?) {
            if pausedAtUptime != nil, !force {
                return
            }

            guard let elapsedTime = currentElapsedTime(),
                  recordingRect.width > 0,
                  recordingRect.height > 0
            else {
                return
            }

            let cursorLocation = location ?? mouseLocationProvider()
            let normalized = normalizedPoint(for: cursorLocation)

            let sample = RecordedMouseSample(
                time: elapsedTime,
                normalizedX: normalized.x,
                normalizedY: normalized.y,
                isInsideCapture: recordingRect.contains(cursorLocation),
            )

            if !force, let lastSample = samples.last {
                let minimumDelta = min(sampleInterval * 0.5, 1.0 / 240.0)
                if sample.time - lastSample.time < minimumDelta,
                   sample.normalizedX == lastSample.normalizedX,
                   sample.normalizedY == lastSample.normalizedY,
                   sample.isInsideCapture == lastSample.isInsideCapture {
                    return
                }
            }

            samples.append(sample)
        }

        private func appendPress(from event: NSEvent) {
            if pausedAtUptime != nil {
                return
            }

            guard let elapsedTime = currentElapsedTime(),
                  recordingRect.width > 0,
                  recordingRect.height > 0
            else {
                return
            }

            let cursorLocation = event.cgEvent?.location ?? mouseLocationProvider()
            guard recordingRect.contains(cursorLocation) else { return }

            let normalized = normalizedPoint(for: cursorLocation)
            let phase: RecordedMousePress.PressPhase
            let button: Int
            switch event.type {
            case .leftMouseDown, .rightMouseDown:
                phase = .down
            case .leftMouseUp, .rightMouseUp:
                phase = .up
            default:
                return
            }

            switch event.type {
            case .leftMouseDown, .leftMouseUp:
                button = 0
            case .rightMouseDown, .rightMouseUp:
                button = 1
            default:
                button = 0
            }

            let press = RecordedMousePress(
                time: elapsedTime,
                normalizedX: normalized.x,
                normalizedY: normalized.y,
                button: button,
                phase: phase,
            )

            if let lastPress = presses.last {
                let duplicateWindow: TimeInterval = 0.05
                if press.phase == lastPress.phase,
                   press.button == lastPress.button,
                   press.time - lastPress.time < duplicateWindow,
                   press.normalizedX == lastPress.normalizedX,
                   press.normalizedY == lastPress.normalizedY {
                    return
                }
            }

            presses.append(press)
        }

        private func normalizedPoint(for cursorLocation: CGPoint) -> (x: CGFloat, y: CGFloat) {
            let rawX = (cursorLocation.x - recordingRect.minX) / recordingRect.width
            let rawY = (cursorLocation.y - recordingRect.minY) / recordingRect.height
            let topLeftY = 1 - rawY
            return (
                x: rawX.clamped(to: 0 ... 1),
                y: topLeftY.clamped(to: 0 ... 1),
            )
        }

        private func installGlobalMouseMonitor() {
            guard globalMouseMonitor == nil else { return }

            globalMouseMonitor = mouseMonitorInstaller { [weak self] in
                Task { @MainActor [weak self] in
                    self?.appendCurrentSample(force: false, location: nil)
                }
            }
        }

        private func installPressMonitor() {
            guard pressMonitor == nil else { return }

            pressMonitor = pressMonitorInstaller { [weak self] event in
                MainActor.assumeIsolated {
                    self?.appendPress(from: event)
                }
            }
            localPressMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown, .leftMouseUp, .rightMouseUp],
            ) { [weak self] event in
                MainActor.assumeIsolated {
                    self?.appendPress(from: event)
                }
                return event
            }
        }

        private func buildDiagnostics(from samples: [RecordedMouseSample]) -> TrackingDiagnostics? {
            guard samples.count >= 2,
                  let first = samples.first,
                  let last = samples.last
            else {
                return nil
            }

            let duration = max(last.time - first.time, 0)
            guard duration > 0 else {
                return TrackingDiagnostics(
                    sampleCount: samples.count,
                    duration: 0,
                    effectiveSamplesPerSecond: 0,
                    averageIntervalMs: 0,
                    p95IntervalMs: 0,
                )
            }

            var deltasMs: [Double] = []
            deltasMs.reserveCapacity(samples.count - 1)
            for idx in 1 ..< samples.count {
                deltasMs.append((samples[idx].time - samples[idx - 1].time) * 1000)
            }

            let averageIntervalMs = deltasMs.reduce(0, +) / Double(max(deltasMs.count, 1))
            let sorted = deltasMs.sorted()
            let p95Index = min(max(Int(Double(sorted.count - 1) * 0.95), 0), max(sorted.count - 1, 0))
            let p95IntervalMs = sorted.isEmpty ? 0 : sorted[p95Index]

            return TrackingDiagnostics(
                sampleCount: samples.count,
                duration: duration,
                effectiveSamplesPerSecond: Double(samples.count - 1) / duration,
                averageIntervalMs: averageIntervalMs,
                p95IntervalMs: p95IntervalMs,
            )
        }

        private func currentElapsedTime() -> TimeInterval? {
            guard let startUptime else { return nil }

            let referenceUptime = pausedAtUptime ?? uptimeProvider()
            return max(0, referenceUptime - startUptime - accumulatedPausedDuration)
        }
    }

    private extension CGFloat {
        func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
            Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
        }
    }
#endif
