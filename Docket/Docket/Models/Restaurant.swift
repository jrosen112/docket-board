//
//  Restaurant.swift
//  Docket
//
//  A place to eat.
//

import CloudKit

/// Rough price tier, rendered as $–$$$$.
nonisolated enum PriceRange: String, CaseIterable, Codable {
    case inexpensive = "$"
    case moderate = "$$"
    case pricey = "$$$"
    case splurge = "$$$$"
}

nonisolated struct Restaurant: LocatedListItem {
    let id: CKRecord.ID
    var title: String
    var notes: String?
    var status: ItemStatus
    var photoData: Data?
    var showsPhotoOnBoard: Bool
    var boardPhotoPosition: BoardPhotoPosition
    var addedBy: CKRecord.Reference
    let dateAdded: Date
    var category: ItemCategory { .restaurant }
    /// nil until first fetched from CloudKit; carries the change tag for edits.
    var systemFields: Data?

    // Restaurant-specific
    var location: ItemLocation?
    var showsMapOnBoard: Bool
    var cuisines: [String]
    /// Compatibility bridge for older call sites and app versions.
    var cuisine: String? {
        get { cuisines.first }
        set { cuisines = CuisineCatalog.normalized([newValue].compactMap(\.self)) }
    }
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
        boardPhotoPosition: BoardPhotoPosition = .center,
        location: ItemLocation? = nil,
        showsMapOnBoard: Bool = false,
        cuisine: String? = nil,
        cuisines: [String] = [],
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
        self.boardPhotoPosition = boardPhotoPosition
        self.location = location
        self.showsMapOnBoard = showsMapOnBoard
        self.cuisines = CuisineCatalog.normalized(cuisines + [cuisine].compactMap(\.self))
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
        self.boardPhotoPosition = shared.boardPhotoPosition
        self.systemFields = shared.systemFields
        self.location = ItemLocation(record: record)
        self.showsMapOnBoard = self.location != nil
            && (record[Schema.Field.showsMapOnBoard] as? Bool ?? false)
        let storedCuisines = record[Schema.Field.cuisines] as? [String] ?? []
        let legacyCuisine = record[Schema.Field.cuisine] as? String
        self.cuisines = CuisineCatalog.normalized(
            storedCuisines + [legacyCuisine].compactMap(\.self)
        )
        if let raw = record[Schema.Field.priceRange] as? String {
            self.priceRange = PriceRange(rawValue: raw)
        }
    }

    func toRecord() -> CKRecord {
        let record = CKRecord.base(type: Schema.RecordType.restaurant, id: id, systemFields: systemFields)
        record.applySharedFields(
            title: title, notes: notes, status: status,
            addedBy: addedBy, dateAdded: dateAdded,
            photoData: photoData,
            showsPhotoOnBoard: showsPhotoOnBoard,
            boardPhotoPosition: boardPhotoPosition
        )
        record.applyLocationFields(location: location, showsMapOnBoard: showsMapOnBoard)
        record[Schema.Field.cuisines] = cuisines.isEmpty ? nil : cuisines as CKRecordValue
        // Keep the first value readable by older app versions during rollout.
        record[Schema.Field.cuisine] = cuisines.first
        record[Schema.Field.priceRange] = priceRange?.rawValue
        return record
    }
}
