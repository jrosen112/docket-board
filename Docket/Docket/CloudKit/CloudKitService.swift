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
            var records: [CKRecord] = []
            let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
            let operation = CKFetchRecordZoneChangesOperation(
                recordZoneIDs: [zoneID],
                configurationsByRecordZoneID: [zoneID: config]
            )
            operation.recordWasChangedBlock = { _, result in
                if case .success(let record) = result { records.append(record) }
            }
            operation.fetchRecordZoneChangesResultBlock = { result in
                switch result {
                case .success: continuation.resume(returning: records)
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
    /// one (which the server rejects). Owner-only: a joined space was shared
    /// by someone else.
    func createZoneShare() async throws -> CKShare {
        guard space.isOwned else { throw CloudKitServiceError.sharingRequiresOwner }
        try await ensureZone()

        // Reuse the existing share if the zone already has one.
        let zone = try await database.recordZone(for: zoneID)
        if let shareReference = zone.share,
           let existing = try await database.record(for: shareReference.recordID) as? CKShare {
            return existing
        }

        let share = CKShare(recordZoneID: zoneID)
        share[CKShare.SystemFieldKey.title] = "Our Docket" as CKRecordValue

        let (saveResults, _) = try await database.modifyRecords(saving: [share], deleting: [])
        guard let result = saveResults[share.recordID] else { return share }
        switch result {
        case .success(let saved): return (saved as? CKShare) ?? share
        case .failure(let error): throw error
        }
    }
}

nonisolated enum CloudKitServiceError: LocalizedError {
    case sharingRequiresOwner

    var errorDescription: String? {
        switch self {
        case .sharingRequiresOwner:
            "Only the person who created the board can invite others."
        }
    }
}
