import Foundation

/// App-group storage shared with the Share to Docket extension. Existing
/// installs copy only Docket-owned keys from standard defaults on first use.
nonisolated enum DocketSharedDefaults {
    static let suiteName = "group.jared.rosen.docket"
    private static let migrationKey = "docket.sharedDefaultsMigrated.v1"

    static func production() -> UserDefaults {
        guard let shared = UserDefaults(suiteName: suiteName) else { return .standard }
        migrateIfNeeded(to: shared)
        return shared
    }

    private static func migrateIfNeeded(to shared: UserDefaults) {
        guard !shared.bool(forKey: migrationKey) else { return }
        for (key, value) in UserDefaults.standard.dictionaryRepresentation()
        where key.hasPrefix("docket.") {
            shared.set(value, forKey: key)
        }
        shared.set(true, forKey: migrationKey)
    }
}
