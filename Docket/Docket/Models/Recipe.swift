//
//  Recipe.swift
//  Docket
//
//  A recipe saved from the web or social media, with a cookable structure.
//

import CloudKit
import Foundation

nonisolated struct Recipe: SharedListItem {
    static let maximumPhotoCount = 5

    let id: CKRecord.ID
    var title: String
    var notes: String?
    var status: ItemStatus
    var plannedDate: Date?
    var plannedDateHasTime: Bool
    var completionDates: [Date]
    var photoData: Data?
    var showsPhotoOnBoard: Bool
    var boardPhotoPosition: BoardPhotoPosition
    var addedBy: CKRecord.Reference
    let dateAdded: Date
    var category: ItemCategory { .recipe }
    var systemFields: Data?

    var sourceURL: String?
    var cuisines: [String]
    var ingredients: [String]
    var instructions: [String]
    var additionalPhotoData: [Data]

    var allPhotoData: [Data] {
        ([photoData].compactMap(\.self) + additionalPhotoData)
            .prefix(Self.maximumPhotoCount)
            .map { $0 }
    }

    var sourceLink: URL? {
        guard let sourceURL else { return nil }
        return Self.normalizedURL(from: sourceURL)
    }

    init(
        id: CKRecord.ID,
        title: String,
        notes: String? = nil,
        status: ItemStatus = .wantToGo,
        addedBy: CKRecord.Reference,
        dateAdded: Date = .now,
        plannedDate: Date? = nil,
        plannedDateHasTime: Bool = false,
        completionDates: [Date] = [],
        photoData: Data? = nil,
        showsPhotoOnBoard: Bool = false,
        boardPhotoPosition: BoardPhotoPosition = .center,
        sourceURL: String? = nil,
        cuisines: [String] = [],
        ingredients: [String] = [],
        instructions: [String] = [],
        additionalPhotoData: [Data] = []
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.status = status
        self.addedBy = addedBy
        self.dateAdded = dateAdded
        self.plannedDate = plannedDate
        self.plannedDateHasTime = plannedDate != nil && plannedDateHasTime
        self.completionDates = completionDates
        self.photoData = photoData
        self.showsPhotoOnBoard = showsPhotoOnBoard
        self.boardPhotoPosition = boardPhotoPosition
        self.sourceURL = sourceURL
        self.cuisines = CuisineCatalog.normalized(cuisines)
        self.ingredients = ingredients
        self.instructions = instructions
        self.additionalPhotoData = Array(additionalPhotoData.prefix(Self.maximumPhotoCount - 1))
    }

    init?(record: CKRecord) {
        guard
            record.recordType == Schema.RecordType.recipe,
            let shared = SharedFields(record: record)
        else { return nil }

        self.id = record.recordID
        self.title = shared.title
        self.notes = shared.notes
        self.status = shared.status
        self.addedBy = shared.addedBy
        self.dateAdded = shared.dateAdded
        self.plannedDate = shared.plannedDate
        self.plannedDateHasTime = shared.plannedDateHasTime
        self.completionDates = shared.completionDates
        self.photoData = shared.photoData
        self.showsPhotoOnBoard = shared.showsPhotoOnBoard
        self.boardPhotoPosition = shared.boardPhotoPosition
        self.systemFields = shared.systemFields
        self.sourceURL = record[Schema.Field.sourceURL] as? String
        self.cuisines = CuisineCatalog.normalized(
            record[Schema.Field.cuisines] as? [String] ?? []
        )
        self.ingredients = record[Schema.Field.ingredients] as? [String] ?? []
        self.instructions = record[Schema.Field.instructions] as? [String] ?? []
        self.additionalPhotoData = Schema.Field.additionalRecipePhotos.compactMap { field in
            ItemPhotoAsset.data(from: record[field] as? CKAsset)
        }
    }

    func toRecord() -> CKRecord {
        let record = CKRecord.base(type: Schema.RecordType.recipe, id: id, systemFields: systemFields)
        record.applySharedFields(
            title: title,
            notes: notes,
            status: status,
            addedBy: addedBy,
            dateAdded: dateAdded,
            plannedDate: plannedDate,
            plannedDateHasTime: plannedDateHasTime,
            completionDates: completionDates,
            photoData: photoData,
            showsPhotoOnBoard: showsPhotoOnBoard,
            boardPhotoPosition: boardPhotoPosition
        )
        record[Schema.Field.sourceURL] = sourceURL
        record[Schema.Field.cuisines] = cuisines.isEmpty ? nil : cuisines as CKRecordValue
        record[Schema.Field.ingredients] = ingredients.isEmpty ? nil : ingredients as CKRecordValue
        record[Schema.Field.instructions] = instructions.isEmpty ? nil : instructions as CKRecordValue

        for (index, field) in Schema.Field.additionalRecipePhotos.enumerated() {
            let data = additionalPhotoData.indices.contains(index) ? additionalPhotoData[index] : nil
            record[field] = ItemPhotoAsset.make(from: data)
        }
        return record
    }

    static func normalizedURL(from value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: candidate),
            let scheme = url.scheme?.lowercased(),
            scheme == "http" || scheme == "https",
            url.host != nil
        else { return nil }
        return url
    }
}
