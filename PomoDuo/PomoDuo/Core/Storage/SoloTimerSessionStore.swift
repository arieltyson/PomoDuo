import Foundation

/// Persists solo timer state so expired phases survive relaunches.
nonisolated struct SoloTimerSessionStore {
    private enum Keys {
        static let snapshot = "soloTimer.session.snapshot"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults? = nil) {
        self.userDefaults = userDefaults
            ?? UserDefaults(suiteName: StorageConfiguration.widgetAppGroupID)
            ?? .standard
    }

    func save(_ snapshot: SoloTimerSessionSnapshot) {
        let encoder = JSONEncoder()

        guard let data = try? encoder.encode(snapshot) else {
            return
        }

        userDefaults.set(data, forKey: Keys.snapshot)
    }

    func load() -> SoloTimerSessionSnapshot? {
        let decoder = JSONDecoder()

        guard let data = userDefaults.data(forKey: Keys.snapshot) else {
            return nil
        }

        return try? decoder.decode(SoloTimerSessionSnapshot.self, from: data)
    }

    func clear() {
        userDefaults.removeObject(forKey: Keys.snapshot)
    }
}
