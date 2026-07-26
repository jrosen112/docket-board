//
//  Space.swift
//  Docket
//
//  A Space is one board membership: the shared record zone, how this user
//  reaches it, and the local title shown in the board switcher.
//

import CloudKit

nonisolated struct Space: Identifiable, Hashable, Sendable {
    enum Access: String, Codable, Sendable {
        case owned
        case joined
    }

    let zoneID: CKRecordZone.ID
    let access: Access
    let title: String

    init(zoneID: CKRecordZone.ID, access: Access, title: String? = nil) {
        self.zoneID = zoneID
        self.access = access
        let cleanedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.title =
            cleanedTitle?.isEmpty == false
            ? cleanedTitle!
            : (access == .owned ? "My Board" : "Shared Board")
    }

    var isOwned: Bool { access == .owned }

    /// Stable identity for persistence and per-board local state. The title is
    /// deliberately excluded so a board can be renamed without becoming a
    /// different membership.
    var id: String { "\(access.rawValue):\(zoneID.ownerName)/\(zoneID.zoneName)" }

    static func == (lhs: Space, rhs: Space) -> Bool { lhs.id == rhs.id }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static let `default` = Space(
        zoneID: CKRecordZone.ID(zoneName: Schema.zoneName, ownerName: CKCurrentUserDefaultName),
        access: .owned,
        title: "My Board"
    )

    /// Every user-created board gets its own private record zone. Sharing that
    /// zone later exposes only this board to its invited participants.
    static func newOwned(title: String, id: UUID = UUID()) -> Space {
        Space(
            zoneID: CKRecordZone.ID(
                zoneName: "DocketBoard-\(id.uuidString)",
                ownerName: CKCurrentUserDefaultName
            ),
            access: .owned,
            title: title
        )
    }
}

/// Persists the complete board catalog plus its selected member. Existing
/// single-board installs migrate automatically and keep their last selection.
nonisolated enum SpaceStore {
    private static let catalogKey = "docket.spaces.v2"
    private static let selectedIDKey = "docket.spaces.selectedID"

    // Legacy single-space keys.
    private static let zoneNameKey = "docket.space.zoneName"
    private static let ownerNameKey = "docket.space.ownerName"
    private static let accessKey = "docket.space.access"

    private struct StoredSpace: Codable {
        let zoneName: String
        let ownerName: String
        let access: Space.Access
        let title: String

        init(_ space: Space) {
            zoneName = space.zoneID.zoneName
            ownerName = space.zoneID.ownerName
            access = space.access
            title = space.title
        }

        var space: Space {
            Space(
                zoneID: CKRecordZone.ID(zoneName: zoneName, ownerName: ownerName),
                access: access,
                title: title
            )
        }
    }

    static func load(from defaults: UserDefaults = .standard) -> Space {
        let spaces = loadAll(from: defaults)
        guard let selectedID = defaults.string(forKey: selectedIDKey) else {
            return spaces[0]
        }
        return spaces.first(where: { $0.id == selectedID }) ?? spaces[0]
    }

    static func loadAll(from defaults: UserDefaults = .standard) -> [Space] {
        if let data = defaults.data(forKey: catalogKey),
            let stored = try? JSONDecoder().decode([StoredSpace].self, from: data)
        {
            let spaces = unique(stored.map(\.space))
            if !spaces.isEmpty { return spaces }
        }

        let migrated = unique([.default, legacySpace(from: defaults)].compactMap { $0 })
        persist(migrated, in: defaults)
        if let legacy = legacySpace(from: defaults) {
            defaults.set(legacy.id, forKey: selectedIDKey)
        } else {
            defaults.set(Space.default.id, forKey: selectedIDKey)
        }
        return migrated
    }

    /// Adds or updates a board and makes it current. Retained under the old
    /// `save` name so the persistence API remains small at call sites.
    static func save(_ space: Space, in defaults: UserDefaults = .standard) {
        var spaces = loadAll(from: defaults)
        if let index = spaces.firstIndex(where: { $0.id == space.id }) {
            spaces[index] = space
        } else {
            spaces.append(space)
        }
        persist(spaces, in: defaults)
        defaults.set(space.id, forKey: selectedIDKey)
    }

    /// Replaces device-local discovery state with the memberships CloudKit
    /// reports for this account, preserving one explicit current selection.
    static func replace(
        with spaces: [Space],
        selected: Space,
        in defaults: UserDefaults = .standard
    ) {
        let discovered = unique(spaces + [selected])
        persist(discovered, in: defaults)
        defaults.set(selected.id, forKey: selectedIDKey)
    }

    /// Removes one local membership while preserving an explicit valid
    /// selection. CloudKit deletion/leaving is performed by the caller first.
    static func remove(
        _ space: Space,
        selecting selected: Space,
        in defaults: UserDefaults = .standard
    ) {
        let remaining = loadAll(from: defaults).filter { $0 != space }
        guard !remaining.isEmpty else { return }
        let validSelection = remaining.first(where: { $0 == selected }) ?? remaining[0]
        persist(remaining, in: defaults)
        defaults.set(validSelection.id, forKey: selectedIDKey)
    }

    private static func legacySpace(from defaults: UserDefaults) -> Space? {
        guard
            let zoneName = defaults.string(forKey: zoneNameKey),
            let ownerName = defaults.string(forKey: ownerNameKey),
            let accessRaw = defaults.string(forKey: accessKey),
            let access = Space.Access(rawValue: accessRaw)
        else { return nil }
        return Space(
            zoneID: CKRecordZone.ID(zoneName: zoneName, ownerName: ownerName),
            access: access
        )
    }

    private static func persist(_ spaces: [Space], in defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(spaces.map(StoredSpace.init)) else { return }
        defaults.set(data, forKey: catalogKey)
    }

    private static func unique(_ spaces: [Space]) -> [Space] {
        var seen = Set<String>()
        return spaces.filter { seen.insert($0.id).inserted }
    }
}
