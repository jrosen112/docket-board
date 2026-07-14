//
//  MockSpaceService.swift
//  DocketTests
//
//  In-memory SpaceDataService so BoardStore behavior is testable without an
//  iCloud account. Backed by a plain dictionary of records.
//

import CloudKit
@testable import Docket

nonisolated final class MockSpaceService: SpaceDataService, @unchecked Sendable {
    let space: Space
    let container = CKContainer(identifier: "iCloud.jaredrosen.docket")

    var records: [CKRecord.ID: CKRecord] = [:]
    var loadError: Error?
    var saveError: Error?
    var loadDelayNanoseconds: UInt64 = 0
    var accountUserID = CKRecord.ID(recordName: "mock-icloud-user")
    var discoveredSpaces: [Space]
    var profileCreatorRecordNames: [CKRecord.ID: String] = [:]

    init(space: Space = .default) {
        self.space = space
        self.discoveredSpaces = [space]
    }

    func newRecordID() -> CKRecord.ID {
        CKRecord.ID(recordName: UUID().uuidString, zoneID: space.zoneID)
    }

    func accountUserRecordID() async throws -> CKRecord.ID {
        if let loadError { throw loadError }
        return accountUserID
    }

    func discoverSpaces() async throws -> [Space] {
        if let loadError { throw loadError }
        return discoveredSpaces
    }

    func loadEverything() async throws -> (items: [any SharedListItem], profiles: [UserProfile]) {
        if loadDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: loadDelayNanoseconds)
        }
        if let loadError { throw loadError }
        let decoded = RecordDecoder.partition(Array(records.values))
        let profiles = decoded.profiles.map { profile in
            var profile = profile
            profile.creatorUserRecordName = profileCreatorRecordNames[profile.id]
            return profile
        }
        return (decoded.items, profiles)
    }

    @discardableResult
    func save(_ record: CKRecord) async throws -> CKRecord {
        if let saveError { throw saveError }
        records[record.recordID] = record
        if record.recordType == Schema.RecordType.userProfile {
            profileCreatorRecordNames[record.recordID] = accountUserID.recordName
        }
        return record
    }

    func delete(_ recordID: CKRecord.ID) async throws {
        records[recordID] = nil
    }

    func loadShare() async throws -> CKShare {
        guard space.isOwned else { throw CloudKitServiceError.shareUnavailable }
        return CKShare(recordZoneID: space.zoneID)
    }
}
