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

nonisolated struct BoardParticipantRoster: Equatable, Sendable {
    let participantCount: Int
    let participantNames: [String]
}

nonisolated struct SpaceContents {
    var items: [any SharedListItem]
    let profiles: [UserProfile]
    let reactions: [BoardReaction]
}

nonisolated protocol SpaceDataService: Sendable {
    /// The container, exposed for UICloudSharingController.
    var container: CKContainer { get }
    /// The board this service is bound to. One service per Space; switching
    /// boards means constructing a new service.
    var space: Space { get }

    /// A fresh record ID inside this space's zone.
    func newRecordID() -> CKRecord.ID

    /// Stable identity for the iCloud account currently using the container.
    func accountUserRecordID() async throws -> CKRecord.ID
    /// All Docket-owned and Docket-shared zones available to this account.
    func discoverSpaces() async throws -> [Space]
    func loadEverything() async throws -> SpaceContents
    @discardableResult
    func save(_ record: CKRecord) async throws -> CKRecord
    func delete(_ recordID: CKRecord.ID) async throws
    /// Permanently deletes an owned board's complete custom record zone.
    func deleteBoardZone() async throws
    /// Loads this board's existing share. For an owned, not-yet-shared board,
    /// creates the zone-wide share first.
    func loadShare() async throws -> CKShare
    /// Returns active membership from an existing CKShare without creating a
    /// share as a side effect of opening Board Manager. nil means the private
    /// board has never been shared and therefore has only its owner.
    func loadParticipantRoster() async throws -> BoardParticipantRoster?
}
