//
//  ScrollingCaptureMouseMoveSuppressor.swift
//  Notinhas
//
//  Suppresses mouse-moved events in the target app during scroll capture so hover
//  states do not destabilize stitch alignment. Requires Accessibility permission.
//

import ApplicationServices
import Foundation

@MainActor
final class ScrollingCaptureMouseMoveSuppressor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private(set) var isActive = false

    @discardableResult
    func installIfAuthorized() -> Bool {
        guard eventTap == nil else { return isActive }
        guard AXIsProcessTrusted() else { return false }

        let eventMask = CGEventMask(1 << CGEventType.mouseMoved.rawValue)
        let callback: CGEventTapCallBack = { _, _, _, _ in nil }

        guard
            let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: eventMask,
                callback: callback,
                userInfo: nil,
            )
        else {
            return false
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            return false
        }

        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        guard CGEvent.tapIsEnabled(tap: tap) else {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            CFMachPortInvalidate(tap)
            return false
        }

        eventTap = tap
        runLoopSource = source
        isActive = true
        return true
    }

    func remove() {
        isActive = false

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            eventTap = nil
        }

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }
    }
}
