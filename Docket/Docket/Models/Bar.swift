//
//  Bar.swift
//  Docket
//
//  A place to drink.
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

nonisolated struct Bar: LocatedListItem {
    let id: CKRecord.ID
    var title: String
    var notes: String?
    var status: ItemStatus
    var photoData: Data?
    var showsPhotoOnBoard: Bool
    var addedBy: CKRecord.Reference
    let dateAdded: Date
    var category: ItemCategory { .bar }
    /// nil until first fetched from CloudKit; carries the change tag for edits.
    var systemFields: Data?

    // Bar-specific
    var location: ItemLocation?
    var showsMapOnBoard: Bool
    var barType: BarType?

    init(
        id: CKRecord.ID,
        title: String,
        notes: String? = nil,
        status: ItemStatus = .wantToGo,
        addedBy: CKRecord.Reference,
        dateAdded: Date = .now,
        photoData: Data? = nil,
        showsPhotoOnBoard: Bool = false,
        location: ItemLocation? = nil,
        showsMapOnBoard: Bool = false,
        barType: BarType? = nil
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
        self.showsMapOnBoard = showsMapOnBoard
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
        self.photoData = shared.photoData
        self.showsPhotoOnBoard = shared.showsPhotoOnBoard
        self.systemFields = shared.systemFields
        self.location = ItemLocation(record: record)
        self.showsMapOnBoard = self.location != nil
            && (record[Schema.Field.showsMapOnBoard] as? Bool ?? false)
        if let raw = record[Schema.Field.barType] as? String {
            self.barType = BarType(rawValue: raw)
        }
    }

    func toRecord() -> CKRecord {
        let record = CKRecord.base(type: Schema.RecordType.bar, id: id, systemFields: systemFields)
        record.applySharedFields(
            title: title, notes: notes, status: status,
            addedBy: addedBy, dateAdded: dateAdded,
            photoData: photoData, showsPhotoOnBoard: showsPhotoOnBoard
        )
        record.applyLocationFields(location: location, showsMapOnBoard: showsMapOnBoard)
        record[Schema.Field.barType] = barType?.rawValue
        return record
    }
}
