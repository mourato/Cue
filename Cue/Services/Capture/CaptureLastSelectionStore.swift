//
//  CaptureLastSelectionStore.swift
//  Notinhas
//
//  Persists the shared remembered capture area used by All-In-One and
//  individual area-based capture flows.
//

import CoreGraphics
import Foundation

enum CaptureLastSelectionStore {
    /// The shared preference is stored under the legacy All-In-One key so existing
    /// users keep their setting. Recording's old preference is read only when the
    /// shared value has never been written.
    static func isEnabled(userDefaults: UserDefaults) -> Bool {
        if let value = userDefaults.object(forKey: PreferencesKeys.captureAllInOneRememberLastSelection) as? Bool {
            return value
        }
        if let legacyRecordingValue = userDefaults.object(forKey: PreferencesKeys.recordingRememberLastArea) as? Bool {
            return legacyRecordingValue
        }
        return true
    }

    // MARK: - Save

    static func save(_ rect: CGRect, userDefaults: UserDefaults) {
        let rectDict: [String: CGFloat] = [
            "x": rect.origin.x,
            "y": rect.origin.y,
            "width": rect.width,
            "height": rect.height
        ]
        userDefaults.set(rectDict, forKey: PreferencesKeys.captureAllInOneLastAreaRect)
        // The shared rect now wins over the legacy fallback, so drop the stale copy.
        userDefaults.removeObject(forKey: PreferencesKeys.recordingLastAreaRect)
    }

    // MARK: - Load

    /// Loads the shared area, falling back to the legacy recording area when the
    /// shared value has never been written. Returns nil when the stored rect is
    /// invalid or no longer intersects a connected screen; otherwise the rect is
    /// fitted inside the screen it overlaps most, so display changes never
    /// restore an area that hangs off-screen.
    static func load(userDefaults: UserDefaults, screens: [CGRect]) -> CGRect? {
        // A written-but-invalid shared rect is not replaced by an older recording
        // rect; the fallback only applies while the shared value is absent.
        let key = userDefaults.object(forKey: PreferencesKeys.captureAllInOneLastAreaRect) != nil
            ? PreferencesKeys.captureAllInOneLastAreaRect
            : PreferencesKeys.recordingLastAreaRect
        guard let rect = decodeRect(forKey: key, userDefaults: userDefaults) else {
            return nil
        }
        return CaptureSelectionGeometry.fitted(rect, toScreens: screens)
    }

    /// Returns the area to restore for a new selection only when the shared
    /// preference is enabled.
    static func restoredRect(userDefaults: UserDefaults, screens: [CGRect]) -> CGRect? {
        guard isEnabled(userDefaults: userDefaults) else { return nil }
        return load(userDefaults: userDefaults, screens: screens)
    }

    /// Copies the legacy Recording preference into the shared key once so the
    /// Capture settings toggle reflects the effective value after upgrade.
    static func migrateLegacyRecordingPreferenceIfNeeded(userDefaults: UserDefaults) {
        guard userDefaults.object(forKey: PreferencesKeys.captureAllInOneRememberLastSelection) == nil,
              let legacyValue = userDefaults.object(forKey: PreferencesKeys.recordingRememberLastArea) as? Bool
        else {
            return
        }
        userDefaults.set(legacyValue, forKey: PreferencesKeys.captureAllInOneRememberLastSelection)
    }

    // MARK: - Validation

    private static func decodeRect(forKey key: String, userDefaults: UserDefaults) -> CGRect? {
        guard let rectDict = userDefaults.dictionary(forKey: key),
              let x = rectDict["x"] as? CGFloat,
              let y = rectDict["y"] as? CGFloat,
              let width = rectDict["width"] as? CGFloat,
              let height = rectDict["height"] as? CGFloat
        else {
            return nil
        }
        guard x.isFinite, y.isFinite, width.isFinite, height.isFinite,
              width > 0, height > 0
        else {
            return nil
        }
        return CaptureSelectionGeometry.normalized(CGRect(x: x, y: y, width: width, height: height))
    }
}
