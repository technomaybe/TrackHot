import Combine
import Foundation

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published var isEnabled: Bool = true {
        didSet { save() }
    }
    @Published var hotKey: HotKey? {
        didSet { save() }
    }
    @Published var lastFired: Date?

    private let hotKeyKey = "com.trackhot.hotKey"
    private let enabledKey = "com.trackhot.enabled"

    private init() {
        load()
    }

    private func save() {
        if let hotKey, let data = try? JSONEncoder().encode(hotKey) {
            UserDefaults.standard.set(data, forKey: hotKeyKey)
        } else {
            UserDefaults.standard.removeObject(forKey: hotKeyKey)
        }
        UserDefaults.standard.set(isEnabled, forKey: enabledKey)
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: hotKeyKey),
           let decoded = try? JSONDecoder().decode(HotKey.self, from: data) {
            hotKey = decoded
        }
        if UserDefaults.standard.object(forKey: enabledKey) != nil {
            isEnabled = UserDefaults.standard.bool(forKey: enabledKey)
        }
    }
}
