//
//  CloudKitService.swift
//  Docket
//
//  The CloudKit "engine": binds one Space (board) to real CloudKit I/O. Knows
//  nothing about SwiftUI. An actor so its mutable state (the zone-ensured flag)
//  is safe to touch from anywhere.
//
//  Owned space  → private database, this user's zone.
//  Joined space → shared database, the owner's zone.
//
//  Fetching uses CKFetchRecordZoneChangesOperation (zone changes) rather than
//  CKQuery on purpose: querying a fresh record type requires manually adding
//  Queryable indexes in the CloudKit Console first, whereas zone-changes needs
//  no schema config and is the right base for push sync later.
//

import CloudKit

actor CloudKitService: SpaceDataService {

    private static let requestTimeout: TimeInterval = 8
    private static let resourceTimeout: TimeInterval = 12

    nonisolated let container: CKContainer
    nonisolated let space: Space
    /// Owned → private database; joined → shared database.
    nonisolated let database: CKDatabase

    nonisolated var zoneID: CKRecordZone.ID { space.zoneID }

    private var didEnsureZone = false

    init(space: Space = .default, containerIdentifier: String = "iCloud.jaredrosen.docket") {
        let container = CKContainer(identifier: containerIdentifier)
        self.container = container
        self.space = space
        self.database = space.isOwned
            ? container.privateCloudDatabase
            : container.sharedCloudDatabase
    }

    /// A record ID inside this space's zone. Callers use this when creating new
    /// records so they land in the right zone.
    nonisolated func newRecordID() -> CKRecord.ID {
        CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID)
    }

    nonisolated func accountUserRecordID() async throws -> CKRecord.ID {
        try await container.userRecordID()
    }

    /// Rebuilds the local board catalog on a new device from the account's
    /// private and shared databases. Only Docket's zone naming conventions are
    /// admitted so unrelated custom zones in the same container are ignored.
    nonisolated func discoverSpaces() async throws -> [Space] {
        let privateDatabase = container.privateCloudDatabase
        let sharedDatabase = container.sharedCloudDatabase
        let ownedZones = try await privateDatabase.allRecordZones()
        let joinedZones = try await sharedDatabase.allRecordZones()

        var discovered: [Space] = []
        for zone in ownedZones where Self.isDocketZone(zone.zoneID) {
            let title = await Self.boardTitle(for: zone, in: privateDatabase)
            discovered.append(
                Space(
                    zoneID: zone.zoneID,
                    access: .owned,
                    title: title ?? Self.fallbackTitle(for: zone.zoneID, access: .owned)
                )
            )
        }
        for zone in joinedZones where Self.isDocketZone(zone.zoneID) {
            let title = await Self.boardTitle(for: zone, in: sharedDatabase)
            discovered.append(
                Space(
                    zoneID: zone.zoneID,
                    access: .joined,
                    title: title ?? Self.fallbackTitle(for: zone.zoneID, access: .joined)
                )
            )
        }
        return Self.unique(discovered)
    }

    private nonisolated static func isDocketZone(_ zoneID: CKRecordZone.ID) -> Bool {
        zoneID.zoneName == Schema.zoneName || zoneID.zoneName.hasPrefix("DocketBoard-")
    }

    private nonisolated static func fallbackTitle(
        for zoneID: CKRecordZone.ID,
        access: Space.Access
    ) -> String {
        if zoneID.zoneName == Schema.zoneName {
            return access == .owned ? "My Board" : "Shared Board"
        }
        return access == .owned ? "Recovered Board" : "Shared Board"
    }

    private nonisolated static func boardTitle(
        for zone: CKRecordZone,
        in database: CKDatabase
    ) async -> String? {
        guard let shareID = zone.share?.recordID,
              let share = try? await database.record(for: shareID) as? CKShare
        else { return nil }
        return share[CKShare.SystemFieldKey.title] as? String
    }

    private nonisolated static func unique(_ spaces: [Space]) -> [Space] {
        var seen = Set<String>()
        return spaces.filter { seen.insert($0.id).inserted }
    }

    // MARK: - Zone

    /// Creates the zone if it doesn't exist yet. Idempotent. A joined space's
    /// zone already exists in the owner's database, so this is a no-op there.
    func ensureZone() async throws {
        guard space.isOwned else { return }
        if didEnsureZone { return }
        let zone = CKRecordZone(zoneID: zoneID)
        _ = try await database.modifyRecordZones(saving: [zone], deleting: [])
        didEnsureZone = true
    }

    // MARK: - Writes

    @discardableResult
    func save(_ record: CKRecord) async throws -> CKRecord {
        try await ensureZone()
        return try await database.save(record)
    }

    func delete(_ recordID: CKRecord.ID) async throws {
        try await database.deleteRecord(withID: recordID)
    }

    // MARK: - Reads

    /// One combined load of everything in the zone: category items + profiles.
    func loadEverything() async throws -> (items: [any SharedListItem], profiles: [UserProfile]) {
        RecordDecoder.partition(try await fetchAllRecords())
    }

    /// Pulls every record currently in the zone via zone-changes (no schema
    /// indexes required). We don't persist the change token yet — that's the
    /// step-7 sync work; for now we always fetch from scratch.
    private func fetchAllRecords() async throws -> [CKRecord] {
        try await ensureZone()
        return try await withCheckedThrowingContinuation { continuation in
            let accumulator = CloudKitFetchAccumulator()
            let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
            let operation = CKFetchRecordZoneChangesOperation(
                recordZoneIDs: [zoneID],
                configurationsByRecordZoneID: [zoneID: config]
            )
            let operationConfiguration = CKOperation.Configuration()
            operationConfiguration.timeoutIntervalForRequest = Self.requestTimeout
            operationConfiguration.timeoutIntervalForResource = Self.resourceTimeout
            operation.configuration = operationConfiguration
            operation.recordWasChangedBlock = { _, result in
                // One undecodable/failed record must not take down the whole
                // board — skip it and render everything else. Zone-level
                // failures below still fail the load.
                if case .success(let record) = result {
                    accumulator.append(record)
                }
            }
            operation.recordZoneFetchResultBlock = { _, result in
                if case .failure(let error) = result {
                    accumulator.record(error)
                }
            }
            operation.fetchRecordZoneChangesResultBlock = { result in
                switch result {
                case .success:
                    let snapshot = accumulator.snapshot()
                    if let error = snapshot.error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: snapshot.records)
                    }
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
            database.add(operation)
        }
    }

    // MARK: - Sharing

    /// Returns the zone-wide share for this space, creating it on first call.
    /// CloudKit allows exactly ONE zone-wide share per zone, so subsequent
    /// calls must return the existing share rather than trying to save a new
    /// one (which the server rejects). Owners can manage membership; joined
    /// participants use the same record to view the people list or leave.
    func loadShare() async throws -> CKShare {
        try await ensureZone()

        // Owners manage membership; participants use the same share record to
        // view the people list and leave the board.
        let zone = try await database.recordZone(for: zoneID)
        if let shareReference = zone.share,
           let existing = try await database.record(for: shareReference.recordID) as? CKShare {
            return existing
        }

        guard space.isOwned else { throw CloudKitServiceError.shareUnavailable }

        let share = CKShare(recordZoneID: zoneID)
        share[CKShare.SystemFieldKey.title] = space.title as CKRecordValue

        let (saveResults, _) = try await database.modifyRecords(saving: [share], deleting: [])
        guard let result = saveResults[share.recordID] else { return share }
        switch result {
        case .success(let saved): return (saved as? CKShare) ?? share
        case .failure(let error): throw error
        }
    }
}

/// CloudKit operation callbacks are not actor-isolated and may arrive on
/// different queues. This keeps partial records/errors synchronized until the
/// operation-level completion fires.
nonisolated final class CloudKitFetchAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var records: [CKRecord] = []
    private var firstError: Error?

    func append(_ record: CKRecord) {
        lock.withLock { records.append(record) }
    }

    func record(_ error: Error) {
        lock.withLock {
            if firstError == nil { firstError = error }
        }
    }

    func snapshot() -> (records: [CKRecord], error: Error?) {
        lock.withLock { (records, firstError) }
    }
}

nonisolated enum CloudKitServiceError: LocalizedError {
    case shareUnavailable

    var errorDescription: String? {
        switch self {
        case .shareUnavailable:
            "This board's sharing details aren't available yet. Try again after refreshing."
        }
    }
}
