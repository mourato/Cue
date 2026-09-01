//
//  SoundManager.swift
//  Notinhas
//
//  Centralized sound playback gated by the user's "Play Sounds" preference
//

import AppKit

/// Gates all sound playback on the `playSounds` user preference and keeps
/// XCTest hosts silent by default.
enum SoundManager {
    private static let fallbackScreenshotSoundName = "Glass"
    private static let screenshotSoundTemplate: NSSound? = {
        let candidatePaths = [
            // Current macOS native screenshot sound.
            "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/system/Screen Capture.aif",
            // Legacy fallback present on older systems.
            "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/system/Shutter.aif",
            "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/system/Grab.aif",
        ]

        for path in candidatePaths {
            let url = URL(fileURLWithPath: path)
            if let sound = NSSound(contentsOf: url, byReference: true) {
                return sound
            }
        }

        return nil
    }()

    private static var soundsEnabled: Bool {
        UserDefaults.standard.object(forKey: PreferencesKeys.playSounds) as? Bool ?? true
    }

    static var isPlaybackSuppressedForTests: Bool {
        let environment = ProcessInfo.processInfo.environment
        guard environment["CUE_ALLOW_TEST_SOUNDS"] != "1" else { return false }
        return environment["NOTINHAS_QUIET_TESTS"] == "1"
            || environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }

    /// Play a named system sound only if the user hasn't disabled sounds.
    /// - Parameter name: System sound name (e.g. "Glass", "Pop", "Funk")
    static func play(_ name: String) {
        guard !isPlaybackSuppressedForTests, soundsEnabled else { return }
        NSSound(named: name)?.play()
    }

    /// Play the closest available native macOS screenshot sound.
    static func playScreenshotCapture() {
        guard !isPlaybackSuppressedForTests, soundsEnabled else { return }

        if let sound = screenshotSoundTemplate?.copy() as? NSSound, sound.play() {
            return
        }

        play(fallbackScreenshotSoundName)
    }
}
