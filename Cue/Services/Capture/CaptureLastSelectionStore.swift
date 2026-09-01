//
//  CaptureLastSelectionStore.swift
//  Notinhas
//
//  Persists and restores the last All-In-One capture selection rectangle.
//

import CoreGraphics
import Foundation

enum CaptureLastSelectionStore {
    // MARK: - Save

    static func save(_ rect: CGRect, userDefaults: UserDefaults) {
        let rectDict: [String: CGFloat] = [
            "x": rect.origin.x,
            "y": rect.origin.y,
            "width": rect.width,
            "height": rect.height,
        ]
        userDefaults.set(rectDict, forKey: PreferencesKeys.captureAllInOneLastAreaRect)
    }

    // MARK: - Load

    static func load(userDefaults: UserDefaults, screens: [CGRect]) -> CGRect? {
        guard let rectDict = userDefaults.dictionary(forKey: PreferencesKeys.captureAllInOneLastAreaRect),
              let x = rectDict["x"] as? CGFloat,
              let y = rectDict["y"] as? CGFloat,
              let width = rectDict["width"] as? CGFloat,
              let height = rectDict["height"] as? CGFloat else {
            return nil
        }

        guard x.isFinite, y.isFinite, width.isFinite, height.isFinite,
              width > 0, height > 0 else {
            return nil
        }

        let rect = CaptureSelectionGeometry.normalized(
            CGRect(x: x, y: y, width: width, height: height),
        )

        guard isRectVisibleOnScreens(rect, screens: screens) else {
            return nil
        }

        return rect
    }

    // MARK: - Validation

    static func isRectVisibleOnScreens(_ rect: CGRect, screens: [CGRect]) -> Bool {
        for screenFrame in screens where screenFrame.intersects(rect) {
            return true
        }
        return false
    }
}
