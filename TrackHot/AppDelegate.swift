import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusBarController = StatusBarController()

        // Reading trackpad touches doesn't need Accessibility; posting the keystroke
        // does, and fireShortcut() checks for it at that moment. So start listening
        // immediately and just prompt for the permission if it's missing.
        EventMonitorService.shared.start()
        if !AXIsProcessTrusted() {
            let promptOptions = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
            _ = AXIsProcessTrustedWithOptions(promptOptions as CFDictionary)
        }
    }
}
