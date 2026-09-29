import CoreGraphics
import Foundation

enum HotKeyEmitter {
    static func emit(_ hotKey: HotKey) {
        let src = CGEventSource(stateID: .hidSystemState)
        let flags = CGEventFlags(rawValue: hotKey.modifiers)

        let keyDown = CGEvent(keyboardEventSource: src, virtualKey: hotKey.keyCode, keyDown: true)
        keyDown?.flags = flags
        keyDown?.post(tap: .cghidEventTap)

        let keyUp = CGEvent(keyboardEventSource: src, virtualKey: hotKey.keyCode, keyDown: false)
        keyUp?.flags = flags
        keyUp?.post(tap: .cghidEventTap)
    }
}
