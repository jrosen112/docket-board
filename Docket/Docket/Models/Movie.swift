//
//  Movie.swift
//  Docket
//
//  A movie to watch together. Text-only category (no location) — the small,
//  short card on the board.
//

import CloudKit

nonisolated struct Movie: SharedListItem {
    let id: CKRecord.ID
    var title: String
    var notes: String?
    var status: ItemStatus
    let addedBy: CKRecord.Reference
    let dateAdded: Date
    var category: ItemCategory { .movie }
    /// nil until first fetched from CloudKit; carries the change tag for edits.
    var systemFields: Data?

    // Movie-specific
    var runtimeMinutes: Int?
    var streamingService: String?
    var releaseYear: Int?

    init(
        id: CKRecord.ID,
        title: String,
        notes: String? = nil,
        status: ItemStatus = .wantToGo,
        addedBy: CKRecord.Reference,
        dateAdded: Date = .now,
        runtimeMinutes: Int? = nil,
        streamingService: String? = nil,
        releaseYear: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.status = status
        self.addedBy = addedBy
        self.dateAdded = dateAdded
        self.runtimeMinutes = runtimeMinutes
        self.streamingService = streamingService
        self.releaseYear = releaseYear
    }

    init?(record: CKRecord) {
        guard
            record.recordType == Schema.RecordType.movie,
            let shared = SharedFields(record: record)
        else { return nil }

        self.id = record.recordID
        self.title = shared.title
        self.notes = shared.notes
        self.status = shared.status
        self.addedBy = shared.addedBy
        self.dateAdded = shared.dateAdded
        self.systemFields = shared.systemFields
        self.runtimeMinutes = record[Schema.Field.runtimeMinutes] as? Int
        self.streamingService = record[Schema.Field.streamingService] as? String
        self.releaseYear = record[Schema.Field.releaseYear] as? Int
    }

    func toRecord() -> CKRecord {
        let record = CKRecord.base(type: Schema.RecordType.movie, id: id, systemFields: systemFields)
        record.applySharedFields(
            title: title, notes: notes, status: status,
            addedBy: addedBy, dateAdded: dateAdded
        )
        record[Schema.Field.runtimeMinutes] = runtimeMinutes
        record[Schema.Field.streamingService] = streamingService
        record[Schema.Field.releaseYear] = releaseYear
        return record
    }
}
