//
//  SpaceDataService.swift
//  Docket
//
//  The seam between BoardStore and CloudKit. CloudKitService is the real
//  implementation; tests substitute an in-memory mock so store logic (sorting,
//  profile reconciliation, error surfacing, space switching) is verifiable
//  without an iCloud account.
//

import CloudKit

nonisolated protocol SpaceDataService: Sendable {
    /// The container, exposed for UICloudSharingController.
    var container: CKContainer { get }
    /// The board this service is bound to. One service per Space; switching
    /// boards means constructing a new service.
    var space: Space { get }

    /// A fresh record ID inside this space's zone.
    func newRecordID() -> CKRecord.ID

    func loadEverything() async throws -> (items: [any SharedListItem], profiles: [UserProfile])
    @discardableResult
    func save(_ record: CKRecord) async throws -> CKRecord
    func delete(_ recordID: CKRecord.ID) async throws
    func createZoneShare() async throws -> CKShare
}
