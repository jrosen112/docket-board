//
//  RecordDecoder.swift
//  Docket
//
//  Maps raw CKRecords to their concrete model types. Pulled out of the service
//  so the type-dispatch logic is plain and unit-testable. Unknown record types
//  (e.g. the CKShare system record) are dropped.
//

import CloudKit

nonisolated enum RecordDecoder {

    /// Maps a record to its concrete category type, or nil if it isn't a
    /// known SharedListItem type.
    static func item(from record: CKRecord) -> (any SharedListItem)? {
        switch record.recordType {
        case Schema.RecordType.restaurant: Restaurant(record: record)
        case Schema.RecordType.bar: Bar(record: record)
        case Schema.RecordType.recipe: Recipe(record: record)
        case Schema.RecordType.movie: Movie(record: record)
        default: nil
        }
    }

    /// Splits a zone's records into board items and profiles.
    static func partition(_ records: [CKRecord]) -> (items: [any SharedListItem], profiles: [UserProfile]) {
        var items: [any SharedListItem] = []
        var profiles: [UserProfile] = []
        for record in records {
            if record.recordType == Schema.RecordType.userProfile {
                if let profile = UserProfile(record: record) { profiles.append(profile) }
            } else if let item = item(from: record) {
                items.append(item)
            }
        }
        return (items, profiles)
    }
}
