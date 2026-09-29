import AppKit
import Combine
import SwiftUI

struct ContentView: View {
    @ObservedObject private var store = SettingsStore.shared
    @State private var trusted = AXIsProcessTrusted()
    @State private var showSavedConfirmation = false
    @State private var isEditingShortcut = false

    private let permissionTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("TrackHot")
                    .font(.headline)
                Spacer()
                Toggle("", isOn: $store.isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            Text("Remaps a 3-finger swipe down on the trackpad to a keyboard shortcut.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Shortcut")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if isEditingShortcut {
                    HotKeyRecorderView(hotKey: $store.hotKey) {
                        isEditingShortcut = false
                    }
                    .frame(height: 36)
                } else {
                    HStack {
                        if let hotKey = store.hotKey, !hotKey.displayString.isEmpty {
                            Text(hotKey.displayString)
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundStyle(.primary)
                        } else {
                            Text("No shortcut set")
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(store.hotKey == nil ? "Set" : "Change") {
                            isEditingShortcut = true
                        }
                        .controlSize(.small)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
                }
            }

            if showSavedConfirmation {
                Label("Shortcut saved", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else if !trusted {
                Label("Grant Accessibility permission in System Settings for TrackHot to work.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if let lastFired = store.lastFired {
                Text("Last fired \(lastFired.formatted(date: .omitted, time: .standard))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Button("Quit TrackHot") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 300)
        .onReceive(permissionTimer) { _ in
            trusted = AXIsProcessTrusted()
        }
        .onChange(of: store.hotKey) { newValue in
            guard newValue != nil else { return }
            showSavedConfirmation = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showSavedConfirmation = false
            }
        }
    }
}
