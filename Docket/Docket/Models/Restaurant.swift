//
//  Restaurant.swift
//  Docket
//
//  A place to eat. Location-based category (location is a plain text field for
//  now; MKLocalSearch autocomplete + coordinates come later).
//

import CloudKit

/// Rough price tier, rendered as $–$$$$.
nonisolated enum PriceRange: String, CaseIterable, Codable {
    case inexpensive = "$"
    case moderate = "$$"
    case pricey = "$$$"
    case splurge = "$$$$"
}

nonisolated struct Restaurant: SharedListItem {
    let id: CKRecord.ID
    var title: String
    var notes: String?
    var status: ItemStatus
    let addedBy: CKRecord.Reference
    let dateAdded: Date
    var category: ItemCategory { .restaurant }

    // Restaurant-specific
    var location: String?
    var cuisine: String?
    var priceRange: PriceRange?

    init(
        id: CKRecord.ID,
        title: String,
        notes: String? = nil,
        status: ItemStatus = .wantToGo,
        addedBy: CKRecord.Reference,
        dateAdded: Date = .now,
        location: String? = nil,
        cuisine: String? = nil,
        priceRange: PriceRange? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.status = status
        self.addedBy = addedBy
        self.dateAdded = dateAdded
        self.location = location
        self.cuisine = cuisine
        self.priceRange = priceRange
    }

    init?(record: CKRecord) {
        guard
            record.recordType == Schema.RecordType.restaurant,
            let shared = SharedFields(record: record)
        else { return nil }

        self.id = record.recordID
        self.title = shared.title
        self.notes = shared.notes
        self.status = shared.status
        self.addedBy = shared.addedBy
        self.dateAdded = shared.dateAdded
        self.location = record[Schema.Field.location] as? String
        self.cuisine = record[Schema.Field.cuisine] as? String
        if let raw = record[Schema.Field.priceRange] as? String {
            self.priceRange = PriceRange(rawValue: raw)
        }
    }

    func toRecord() -> CKRecord {
        let record = CKRecord(recordType: Schema.RecordType.restaurant, recordID: id)
        record.applySharedFields(
            title: title, notes: notes, status: status,
            addedBy: addedBy, dateAdded: dateAdded
        )
        record[Schema.Field.location] = location
        record[Schema.Field.cuisine] = cuisine
        record[Schema.Field.priceRange] = priceRange?.rawValue
        return record
    }
}
