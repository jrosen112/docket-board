//
//  Space.swift
//  Docket
//
//  A "space" is one shared board: a CKRecordZone plus how this user reaches it.
//  This mirrors CLAUDE.md's sharing model directly — each space is its own zone
//  + CKShare — so multi-board support later (girlfriend board, brother board,
//  a friend's board you joined) is "hold several Spaces" rather than a rework.
//
//  - `.owned`  → the zone lives in this user's private database.
//  - `.joined` → someone else's zone, reached via the shared database.
//
//  Phase 1 keeps exactly one current Space persisted; multi-board later becomes
//  a persisted list + a current selection.
//

import CloudKit

nonisolated struct Space: Hashable, Sendable {
    enum Access: String, Sendable {
        case owned
        case joined
    }

    let zoneID: CKRecordZone.ID
    let access: Access

    var isOwned: Bool { access == .owned }

    /// Stable string identity, used to key per-space local state (e.g. which
    /// profile is "me" on this board).
    var id: String { "\(access.rawValue):\(zoneID.ownerName)/\(zoneID.zoneName)" }

    /// The default board: a zone this user owns in their own private database.
    static let `default` = Space(
        zoneID: CKRecordZone.ID(zoneName: Schema.zoneName, ownerName: CKCurrentUserDefaultName),
        access: .owned
    )
}

/// Persists which Space the app is currently pointed at.
nonisolated enum SpaceStore {
    private static let zoneNameKey = "docket.space.zoneName"
    private static let ownerNameKey = "docket.space.ownerName"
    private static let accessKey = "docket.space.access"

    static func save(_ space: Space, in defaults: UserDefaults = .standard) {
        defaults.set(space.zoneID.zoneName, forKey: zoneNameKey)
        defaults.set(space.zoneID.ownerName, forKey: ownerNameKey)
        defaults.set(space.access.rawValue, forKey: accessKey)
    }

    static func load(from defaults: UserDefaults = .standard) -> Space {
        guard
            let zoneName = defaults.string(forKey: zoneNameKey),
            let ownerName = defaults.string(forKey: ownerNameKey),
            let accessRaw = defaults.string(forKey: accessKey),
            let access = Space.Access(rawValue: accessRaw)
        else { return .default }
        return Space(
            zoneID: CKRecordZone.ID(zoneName: zoneName, ownerName: ownerName),
            access: access
        )
    }
}
