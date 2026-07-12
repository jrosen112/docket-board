//
//  Bar.swift
//  Docket
//
//  A place to drink. Location-based category (plain text location for now).
//

import CloudKit

/// The vibe of the bar. Freeform enough to cover most spots.
nonisolated enum BarType: String, CaseIterable, Codable {
    case cocktail
    case dive
    case wine
    case brewery
    case sports
    case rooftop
}

nonisolated struct Bar: SharedListItem {
    let id: CKRecord.ID
    var title: String
    var notes: String?
    var status: ItemStatus
    let addedBy: CKRecord.Reference
    let dateAdded: Date
    var category: ItemCategory { .bar }

    // Bar-specific
    var location: String?
    var barType: BarType?

    init(
        id: CKRecord.ID,
        title: String,
        notes: String? = nil,
        status: ItemStatus = .wantToGo,
        addedBy: CKRecord.Reference,
        dateAdded: Date = .now,
        location: String? = nil,
        barType: BarType? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.status = status
        self.addedBy = addedBy
        self.dateAdded = dateAdded
        self.location = location
        self.barType = barType
    }

    init?(record: CKRecord) {
        guard
            record.recordType == Schema.RecordType.bar,
            let shared = SharedFields(record: record)
        else { return nil }

        self.id = record.recordID
        self.title = shared.title
        self.notes = shared.notes
        self.status = shared.status
        self.addedBy = shared.addedBy
        self.dateAdded = shared.dateAdded
        self.location = record[Schema.Field.location] as? String
        if let raw = record[Schema.Field.barType] as? String {
            self.barType = BarType(rawValue: raw)
        }
    }

    func toRecord() -> CKRecord {
        let record = CKRecord(recordType: Schema.RecordType.bar, recordID: id)
        record.applySharedFields(
            title: title, notes: notes, status: status,
            addedBy: addedBy, dateAdded: dateAdded
        )
        record[Schema.Field.location] = location
        record[Schema.Field.barType] = barType?.rawValue
        return record
    }
}
