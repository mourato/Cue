#if CUE_VIDEO_MODULE
//
    //  RecordingKeystrokeRecorder.swift
    //  Notinhas
//
    //  Records structured shortcut events for post-processed keystroke captions.
//

    import AppKit
    import Foundation

    @MainActor
    final class RecordingKeystrokeRecorder {
        private let uptimeProvider: () -> TimeInterval
        private let globalMonitorInstaller: (@escaping (NSEvent) -> Void) -> Any?
        private let localMonitorInstaller: (@escaping (NSEvent) -> Void) -> Any?
        private let monitorRemover: (Any) -> Void

        private var globalMonitor: Any?
        private var localMonitor: Any?
        private var events: [RecordedKeystrokeEvent] = []
        private var startUptime: TimeInterval?
        private var pausedAtUptime: TimeInterval?
        private var accumulatedPausedDuration: TimeInterval = 0

        init(
            uptimeProvider: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
            globalMonitorInstaller: @escaping (@escaping (NSEvent) -> Void) -> Any? = { handler in
                NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { event in
                    handler(event)
                }
            },
            localMonitorInstaller: @escaping (@escaping (NSEvent) -> Void) -> Any? = { handler in
                NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
                    handler(event)
                    return event
                }
            },
            monitorRemover: @escaping (Any) -> Void = { NSEvent.removeMonitor($0) },
        ) {
            self.uptimeProvider = uptimeProvider
            self.globalMonitorInstaller = globalMonitorInstaller
            self.localMonitorInstaller = localMonitorInstaller
            self.monitorRemover = monitorRemover
        }

        func start() {
            reset()
            startUptime = uptimeProvider()
            globalMonitor = globalMonitorInstaller { [weak self] event in
                MainActor.assumeIsolated {
                    self?.handleKeyDown(event)
                }
            }
            localMonitor = localMonitorInstaller { [weak self] event in
                MainActor.assumeIsolated {
                    self?.handleKeyDown(event)
                }
            }
        }

        func pause() {
            guard pausedAtUptime == nil else { return }
            pausedAtUptime = uptimeProvider()
        }

        func resume() {
            guard let pausedAt = pausedAtUptime else { return }
            accumulatedPausedDuration += uptimeProvider() - pausedAt
            pausedAtUptime = nil
        }

        func stop() -> [RecordedKeystrokeEvent] {
            if let globalMonitor {
                monitorRemover(globalMonitor)
            }
            if let localMonitor {
                monitorRemover(localMonitor)
            }
            globalMonitor = nil
            localMonitor = nil
            return events
        }

        func reset() {
            if let globalMonitor {
                monitorRemover(globalMonitor)
            }
            if let localMonitor {
                monitorRemover(localMonitor)
            }
            globalMonitor = nil
            localMonitor = nil
            events = []
            startUptime = nil
            pausedAtUptime = nil
            accumulatedPausedDuration = 0
        }

        private func handleKeyDown(_ event: NSEvent) {
            guard let parsed = KeystrokeEventParser.parse(event) else { return }
            guard let time = currentRecordingTime() else { return }
            events.append(
                RecordedKeystrokeEvent(
                    time: time,
                    modifiers: parsed.modifiers,
                    key: parsed.key,
                ),
            )
        }

        private func currentRecordingTime() -> TimeInterval? {
            guard let startUptime else { return nil }
            var elapsed = uptimeProvider() - startUptime - accumulatedPausedDuration
            if let pausedAt = pausedAtUptime {
                elapsed -= uptimeProvider() - pausedAt
            }
            return max(0, elapsed)
        }
    }
#endif
