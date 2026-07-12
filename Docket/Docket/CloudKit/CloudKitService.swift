//
//  CloudKitService.swift
//  Docket
//
//  The CloudKit "engine": owns the container + shared zone and does all record
//  I/O. Knows nothing about SwiftUI. An actor so its mutable state (the
//  zone-ensured flag) is safe to touch from anywhere.
//
//  Phase 1 operates against the OWNER's private database + custom zone, so the
//  owner can use the app solo. When we wire share acceptance, a participant
//  variant will point the same operations at `sharedCloudDatabase` and the
//  owner's zone ID.
//
//  Fetching uses CKFetchRecordZoneChangesOperation (zone changes) rather than
//  CKQuery on purpose: querying a fresh record type requires manually adding
//  Queryable indexes in the CloudKit Console first, whereas zone-changes needs
//  no schema config and is the right base for push sync later.
//

import CloudKit

actor CloudKitService {

    nonisolated let container: CKContainer
    nonisolated let zoneID: CKRecordZone.ID

    /// The owner's private database (where the shared zone physically lives).
    nonisolated var database: CKDatabase { container.privateCloudDatabase }

    private var didEnsureZone = false

    init(containerIdentifier: String = "iCloud.jaredrosen.docket") {
        self.container = CKContainer(identifier: containerIdentifier)
        self.zoneID = CKRecordZone.ID(
            zoneName: Schema.zoneName,
            ownerName: CKCurrentUserDefaultName
        )
    }

    /// A record ID inside the shared zone. Callers use this when creating new
    /// records so they land in the right zone.
    nonisolated func newRecordID() -> CKRecord.ID {
        CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID)
    }

    // MARK: - Zone

    /// Creates the shared zone if it doesn't exist yet. Idempotent.
    func ensureZone() async throws {
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
        let records = try await fetchAllRecords()
        var items: [any SharedListItem] = []
        var profiles: [UserProfile] = []
        for record in records {
            switch record.recordType {
            case Schema.RecordType.userProfile:
                if let profile = UserProfile(record: record) { profiles.append(profile) }
            default:
                if let item = Self.item(from: record) { items.append(item) }
            }
        }
        return (items, profiles)
    }

    /// Maps a raw record to its concrete category type, or nil for unrelated
    /// records (e.g. the CKShare record itself).
    private static func item(from record: CKRecord) -> (any SharedListItem)? {
        switch record.recordType {
        case Schema.RecordType.restaurant: Restaurant(record: record)
        case Schema.RecordType.bar: Bar(record: record)
        case Schema.RecordType.movie: Movie(record: record)
        default: nil
        }
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

    /// Creates (or returns the existing) zone-wide share for the shared zone.
    /// The caller hands this to a UICloudSharingController to send the invite.
    func createZoneShare() async throws -> CKShare {
        try await ensureZone()
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
