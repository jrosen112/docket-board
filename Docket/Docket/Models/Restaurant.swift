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
    var photoData: Data?
    var showsPhotoOnBoard: Bool
    var addedBy: CKRecord.Reference
    let dateAdded: Date
    var category: ItemCategory { .restaurant }
    /// nil until first fetched from CloudKit; carries the change tag for edits.
    var systemFields: Data?

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
        photoData: Data? = nil,
        showsPhotoOnBoard: Bool = false,
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
        self.photoData = photoData
        self.showsPhotoOnBoard = showsPhotoOnBoard
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
        self.photoData = shared.photoData
        self.showsPhotoOnBoard = shared.showsPhotoOnBoard
        self.systemFields = shared.systemFields
        self.location = record[Schema.Field.location] as? String
        self.cuisine = record[Schema.Field.cuisine] as? String
        if let raw = record[Schema.Field.priceRange] as? String {
            self.priceRange = PriceRange(rawValue: raw)
        }
    }

    func toRecord() -> CKRecord {
        let record = CKRecord.base(type: Schema.RecordType.restaurant, id: id, systemFields: systemFields)
        record.applySharedFields(
            title: title, notes: notes, status: status,
            addedBy: addedBy, dateAdded: dateAdded,
            photoData: photoData, showsPhotoOnBoard: showsPhotoOnBoard
        )
        record[Schema.Field.location] = location
        record[Schema.Field.cuisine] = cuisine
        record[Schema.Field.priceRange] = priceRange?.rawValue
        return record
    }
}
