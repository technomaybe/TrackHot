import AppKit
import Foundation
import os

// Raw touch data from Apple's private MultitouchSupport framework. NSEvent global
// monitors don't receive trackpad gesture events for background apps, so this is
// the only reliable way to see a 3-finger swipe system-wide. Layout must match the
// framework's C struct exactly (96 bytes).
private struct MTPoint { var x: Float; var y: Float }
private struct MTVector { var position: MTPoint; var velocity: MTPoint }
private struct MTTouch {
    var frame: Int32
    var timestamp: Double
    var pathIndex: Int32
    var state: Int32
    var fingerID: Int32
    var handID: Int32
    var normalized: MTVector  // 0...1, origin at bottom-left of the trackpad
    var zTotal: Float
    var field9: Int32
    var angle: Float
    var majorAxis: Float
    var minorAxis: Float
    var absolute: MTVector
    var field14: Int32
    var field15: Int32
    var zDensity: Float
}

private typealias MTCreateListFn = @convention(c) () -> UnsafeMutableRawPointer?
private typealias MTContactCallback = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, Int32, Double, Int32) -> Int32
private typealias MTRegisterCallbackFn = @convention(c) (UnsafeMutableRawPointer?, MTContactCallback) -> Void
private typealias MTDeviceStartFn = @convention(c) (UnsafeMutableRawPointer?, Int32) -> Void

let trackHotLog = Logger(subsystem: "com.patrickschroeder.trackHot", category: "gesture")

final class EventMonitorService {
    static let shared = EventMonitorService()

    private var devices: CFArray?
    private var started = false

    private init() {}

    func start() {
        guard !started else { return }
        let path = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
        guard let handle = dlopen(path, RTLD_NOW),
              let createSym = dlsym(handle, "MTDeviceCreateList"),
              let registerSym = dlsym(handle, "MTRegisterContactFrameCallback"),
              let startSym = dlsym(handle, "MTDeviceStart") else {
            trackHotLog.error("MultitouchSupport unavailable")
            return
        }
        let createList = unsafeBitCast(createSym, to: MTCreateListFn.self)
        let register = unsafeBitCast(registerSym, to: MTRegisterCallbackFn.self)
        let startDevice = unsafeBitCast(startSym, to: MTDeviceStartFn.self)

        guard let listPtr = createList() else {
            trackHotLog.error("MTDeviceCreateList returned nil")
            return
        }
        let list = Unmanaged<CFArray>.fromOpaque(listPtr).takeRetainedValue()
        devices = list  // keep device refs alive for the life of the app

        let count = CFArrayGetCount(list)
        for i in 0..<count {
            let device = UnsafeMutableRawPointer(mutating: CFArrayGetValueAtIndex(list, i))
            register(device, touchCallback)
            startDevice(device, 0)
        }
        started = true
        trackHotLog.notice("Listening on \(count, privacy: .public) multitouch device(s)")
    }
}

// MARK: - Gesture detection (runs on MultitouchSupport's callback thread)

private final class SwipeDetector {
    private struct Session {
        var startY: Float
        var startX: Float
        var fired = false
        var cancelled = false
    }

    private let lock = NSLock()
    private var sessions: [UInt: Session] = [:]

    private let requiredFingers = 3
    private let minDownTravel: Float = 0.12   // fraction of trackpad height

    func process(device: UInt, touches: UnsafeBufferPointer<MTTouch>) {
        // States 3...5 = making, holding, or breaking contact with the surface.
        let onSurface = touches.filter { (3...5).contains($0.state) }

        lock.lock()
        defer { lock.unlock() }

        if onSurface.isEmpty {
            sessions[device] = nil  // all fingers lifted: re-arm
            return
        }

        let avgX = onSurface.map(\.normalized.position.x).reduce(0, +) / Float(onSurface.count)
        let avgY = onSurface.map(\.normalized.position.y).reduce(0, +) / Float(onSurface.count)

        guard var session = sessions[device] else {
            if onSurface.count == requiredFingers {
                sessions[device] = Session(startY: avgY, startX: avgX)
            }
            return
        }

        if onSurface.count > requiredFingers {
            session.cancelled = true  // a 4th finger means it's not our gesture
        }

        if !session.fired && !session.cancelled && onSurface.count == requiredFingers {
            let down = session.startY - avgY   // y grows upward, so down = y shrinking
            let sideways = abs(avgX - session.startX)
            if down > minDownTravel && down > sideways * 1.5 {
                session.fired = true
                trackHotLog.notice("3-finger swipe down detected (travel \(down, privacy: .public))")
                DispatchQueue.main.async { fireShortcut() }
            }
        }
        sessions[device] = session
    }
}

private let detector = SwipeDetector()

private let touchCallback: MTContactCallback = { device, touchPtr, count, _, _ in
    guard let touchPtr, count > 0 else {
        detector.process(device: UInt(bitPattern: device), touches: UnsafeBufferPointer(start: nil, count: 0))
        return 0
    }
    let touches = UnsafeBufferPointer(start: touchPtr.assumingMemoryBound(to: MTTouch.self), count: Int(count))
    detector.process(device: UInt(bitPattern: device), touches: touches)
    return 0
}

private func fireShortcut() {
    let store = SettingsStore.shared
    guard store.isEnabled else {
        trackHotLog.notice("Swipe ignored: TrackHot is toggled off")
        return
    }
    guard let hotKey = store.hotKey else {
        trackHotLog.notice("Swipe ignored: no shortcut set")
        return
    }
    guard AXIsProcessTrusted() else {
        trackHotLog.notice("Swipe ignored: no Accessibility permission, can't post keystrokes")
        return
    }
    HotKeyEmitter.emit(hotKey)
    store.lastFired = Date()
    trackHotLog.notice("Fired shortcut \(hotKey.displayString, privacy: .public)")
}
