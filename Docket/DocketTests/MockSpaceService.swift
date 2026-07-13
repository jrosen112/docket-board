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

    init(space: Space = .default) {
        self.space = space
    }

    func newRecordID() -> CKRecord.ID {
        CKRecord.ID(recordName: UUID().uuidString, zoneID: space.zoneID)
    }

    func loadEverything() async throws -> (items: [any SharedListItem], profiles: [UserProfile]) {
        if loadDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: loadDelayNanoseconds)
        }
        if let loadError { throw loadError }
        return RecordDecoder.partition(Array(records.values))
    }

    @discardableResult
    func save(_ record: CKRecord) async throws -> CKRecord {
        if let saveError { throw saveError }
        records[record.recordID] = record
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
