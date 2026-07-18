//
//  UserProfile.swift
//  Docket
//
//  A first-class profile per participant. `addedBy` on every item references
//  one of these. Kept deliberately small but extensible — future "fun" fields
//  (favorite places, interests, etc.) slot in here without touching item types.
//

import CloudKit

nonisolated struct UserProfile: Identifiable, Equatable {
    let id: CKRecord.ID
    var firstName: String
    var lastName: String
    /// Stable app identity for reclaiming this profile after reinstall. This
    /// is the opaque record name CloudKit assigns to the iCloud account within
    /// Docket's container, not an email address or other personal information.
    var accountRecordName: String?
    /// CloudKit's stable account identity for the user who created this
    /// profile. Retained as a legacy migration signal for profiles created
    /// before `accountRecordName` existed.
    var creatorUserRecordName: String?
    /// nil until first fetched from CloudKit; carries the change tag for edits.
    var systemFields: Data?

    /// Equality is content identity; CloudKit metadata doesn't participate.
    static func == (lhs: UserProfile, rhs: UserProfile) -> Bool {
        lhs.id == rhs.id && lhs.firstName == rhs.firstName && lhs.lastName == rhs.lastName
    }
    // profilePicture (CKAsset) is added with the photo work; the field key is
    // already reserved in Schema.Field.profilePicture.

    var displayName: String {
        [firstName, lastName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Reference used by items' `addedBy`. `.none` so deleting a profile never
    /// cascades into deleting the items that person added.
    var reference: CKRecord.Reference {
        CKRecord.Reference(recordID: id, action: .none)
    }

    init(
        id: CKRecord.ID,
        firstName: String,
        lastName: String,
        accountRecordName: String? = nil,
        creatorUserRecordName: String? = nil
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.accountRecordName = accountRecordName
        self.creatorUserRecordName = creatorUserRecordName
    }

    init?(record: CKRecord) {
        guard
            record.recordType == Schema.RecordType.userProfile,
            let firstName = record[Schema.Field.firstName] as? String
        else { return nil }

        self.id = record.recordID
        self.firstName = firstName
        self.lastName = record[Schema.Field.lastName] as? String ?? ""
        self.accountRecordName = record[Schema.Field.accountRecordName] as? String
        self.creatorUserRecordName = record.creatorUserRecordID?.recordName
        self.systemFields = record.systemFieldsData
    }

    func toRecord() -> CKRecord {
        let record = CKRecord.base(type: Schema.RecordType.userProfile, id: id, systemFields: systemFields)
        record[Schema.Field.firstName] = firstName
        record[Schema.Field.lastName] = lastName
        record[Schema.Field.accountRecordName] = accountRecordName
        return record
    }
}
