import AppKit
import SwiftUI

// MARK: - SwiftUI wrapper

struct HotKeyRecorderView: NSViewRepresentable {
    @Binding var hotKey: HotKey?
    var onFinishRecording: (() -> Void)?

    func makeNSView(context: Context) -> HotKeyRecorderField {
        let field = HotKeyRecorderField()
        field.onChange = { self.hotKey = $0 }
        field.onFinishRecording = onFinishRecording
        // This view only appears while actively recording, so start capturing
        // immediately rather than waiting for an extra click into the field.
        DispatchQueue.main.async {
            field.window?.makeFirstResponder(field)
        }
        return field
    }

    func updateNSView(_ field: HotKeyRecorderField, context: Context) {
        field.current = hotKey
        field.onFinishRecording = onFinishRecording
    }
}

// MARK: - AppKit field

final class HotKeyRecorderField: NSView {
    var onChange: ((HotKey?) -> Void)?
    var onFinishRecording: (() -> Void)?

    var current: HotKey? {
        didSet { needsDisplay = true }
    }

    private var isRecording = false

    override var acceptsFirstResponder: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.borderWidth = 1.5
        updateAppearance()
    }

    private func updateAppearance() {
        if isRecording {
            layer?.borderColor = NSColor.controlAccentColor.cgColor
            layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.08).cgColor
        } else {
            layer?.borderColor = NSColor.separatorColor.cgColor
            layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let label: String
        let color: NSColor

        if isRecording {
            label = "Press keys… (Esc to cancel)"
            color = .controlAccentColor
        } else if let hk = current, !hk.displayString.isEmpty {
            label = hk.displayString
            color = .labelColor
        } else {
            label = "Click to record shortcut"
            color = .placeholderTextColor
        }

        let font = NSFont.monospacedSystemFont(ofSize: 13, weight: isRecording ? .regular : .medium)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let str = NSAttributedString(string: label, attributes: attrs)
        let sz = str.size()
        str.draw(at: NSPoint(x: (bounds.width - sz.width) / 2, y: (bounds.height - sz.height) / 2))
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        if ok { isRecording = true; updateAppearance(); needsDisplay = true }
        return ok
    }

    override func resignFirstResponder() -> Bool {
        let ok = super.resignFirstResponder()
        if ok {
            isRecording = false
            updateAppearance()
            needsDisplay = true
            onFinishRecording?()
        }
        return ok
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { super.keyDown(with: event); return }

        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])

        // Esc with no modifiers cancels
        if event.keyCode == 53 && flags.isEmpty {
            window?.makeFirstResponder(nil)
            return
        }

        // Delete / Backspace clears
        if (event.keyCode == 51 || event.keyCode == 117) && flags.isEmpty {
            current = nil
            onChange?(nil)
            window?.makeFirstResponder(nil)
            return
        }

        // Require at least one modifier unless it's a function key
        let isFn = (96...122).contains(event.keyCode)
        guard !flags.isEmpty || isFn else { return }

        var cgFlags: CGEventFlags = []
        if flags.contains(.command) { cgFlags.insert(.maskCommand) }
        if flags.contains(.option)  { cgFlags.insert(.maskAlternate) }
        if flags.contains(.control) { cgFlags.insert(.maskControl) }
        if flags.contains(.shift)   { cgFlags.insert(.maskShift) }

        let hk = HotKey(keyCode: event.keyCode, modifiers: cgFlags.rawValue)
        current = hk
        onChange?(hk)
        window?.makeFirstResponder(nil)
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 220, height: 36)
    }
}
