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

    init(id: CKRecord.ID, firstName: String, lastName: String) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
    }

    init?(record: CKRecord) {
        guard
            record.recordType == Schema.RecordType.userProfile,
            let firstName = record[Schema.Field.firstName] as? String
        else { return nil }

        self.id = record.recordID
        self.firstName = firstName
        self.lastName = record[Schema.Field.lastName] as? String ?? ""
    }

    func toRecord() -> CKRecord {
        let record = CKRecord(recordType: Schema.RecordType.userProfile, recordID: id)
        record[Schema.Field.firstName] = firstName
        record[Schema.Field.lastName] = lastName
        return record
    }
}
