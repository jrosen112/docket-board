//
//  SharedListItem.swift
//  Docket
//
//  The protocol every category type conforms to, plus the shared enums and
//  the encode/decode helpers that keep CKRecord conversion consistent across
//  categories. Category types add their own fields on top of this.
//

import CloudKit

/// Lifecycle of an item on the board.
nonisolated enum ItemStatus: String, CaseIterable, Codable {
    case wantToGo
    case planned
    case completed

    var label: String {
        switch self {
        case .wantToGo: "Want to go"
        case .planned: "Planned"
        case .completed: "Done"
        }
    }
}

/// Every category in the app. Only a subset is implemented in Phase 1; the rest
/// are listed so the enum is stable and the board can reason about all of them.
nonisolated enum ItemCategory: String, CaseIterable, Codable {
    case restaurant
    case bar
    case happyHour
    case landmark
    case movie
    case hike
    case activity

    /// Categories implemented in the Phase 1 subset — the single list the add
    /// form and filter bar both read.
    static let supported: [ItemCategory] = [.restaurant, .bar, .movie]

    var label: String {
        switch self {
        case .restaurant: "Restaurant"
        case .bar: "Bar"
        case .happyHour: "Happy Hour"
        case .landmark: "Landmark"
        case .movie: "Movie"
        case .hike: "Hike"
        case .activity: "Activity"
        }
    }

    /// CKRecord type name backing this category (implemented categories only).
    var recordType: String {
        switch self {
        case .restaurant: Schema.RecordType.restaurant
        case .bar: Schema.RecordType.bar
        case .movie: Schema.RecordType.movie
        // Not yet implemented in the Phase 1 subset.
        case .happyHour, .landmark, .hike, .activity: rawValue.prefix(1).uppercased() + rawValue.dropFirst()
        }
    }
}

/// Shared surface used by the board/list to render any category uniformly.
/// Category-specific fields and detail views live on the concrete types.
nonisolated protocol SharedListItem: Identifiable {
    var id: CKRecord.ID { get }
    var title: String { get set }
    var notes: String? { get set }
    var status: ItemStatus { get set }
    var photoData: Data? { get set }
    var showsPhotoOnBoard: Bool { get set }
    /// Reference to the UserProfile of whoever added the item.
    var addedBy: CKRecord.Reference { get set }
    var dateAdded: Date { get }
    var category: ItemCategory { get }

    /// Encode into a CKRecord ready to save into the shared zone.
    func toRecord() -> CKRecord
}

// MARK: - Shared field encode/decode helpers

extension CKRecord {
    /// Write the fields common to every SharedListItem onto this record.
    nonisolated func applySharedFields(
        title: String,
        notes: String?,
        status: ItemStatus,
        addedBy: CKRecord.Reference,
        dateAdded: Date,
        photoData: Data?,
        showsPhotoOnBoard: Bool
    ) {
        self[Schema.Field.title] = title
        self[Schema.Field.notes] = notes
        self[Schema.Field.status] = status.rawValue
        self[Schema.Field.addedBy] = addedBy
        self[Schema.Field.dateAdded] = dateAdded
        self[Schema.Field.itemPhoto] = ItemPhotoAsset.make(from: photoData)
        self[Schema.Field.showsPhotoOnBoard] = photoData != nil && showsPhotoOnBoard
    }
}

/// Decoded common fields, or `nil` if the record is missing a required field.
/// Category `init?(record:)` implementations start here, then read their own fields.
nonisolated struct SharedFields {
    let title: String
    let notes: String?
    let status: ItemStatus
    let addedBy: CKRecord.Reference
    let dateAdded: Date
    let photoData: Data?
    let showsPhotoOnBoard: Bool
    /// System-fields archive of the source record, so edits carry the change tag.
    let systemFields: Data

    init?(record: CKRecord) {
        guard
            let title = record[Schema.Field.title] as? String,
            let statusRaw = record[Schema.Field.status] as? String,
            let status = ItemStatus(rawValue: statusRaw),
            let addedBy = record[Schema.Field.addedBy] as? CKRecord.Reference,
            let dateAdded = record[Schema.Field.dateAdded] as? Date
        else { return nil }

        self.title = title
        self.notes = record[Schema.Field.notes] as? String
        self.status = status
        self.addedBy = addedBy
        self.dateAdded = dateAdded
        let photoData = ItemPhotoAsset.data(from: record[Schema.Field.itemPhoto] as? CKAsset)
        self.photoData = photoData
        self.showsPhotoOnBoard = photoData != nil
            && (record[Schema.Field.showsPhotoOnBoard] as? Bool ?? false)
        self.systemFields = record.systemFieldsData
    }
}

/// Bridges in-memory image bytes to CloudKit's file-backed asset type.
/// The system temporary directory is appropriate here: CloudKit only needs
/// the file for the duration of the upload, while fetched assets are copied
/// back into the model as `Data` immediately during decoding.
private nonisolated enum ItemPhotoAsset {
    static func make(from data: Data?) -> CKAsset? {
        guard let data else { return nil }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DocketItemAssets", isDirectory: true)
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            let fileURL = directory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("jpg")
            try data.write(to: fileURL, options: .atomic)
            return CKAsset(fileURL: fileURL)
        } catch {
            return nil
        }
    }

    static func data(from asset: CKAsset?) -> Data? {
        guard let fileURL = asset?.fileURL else { return nil }
        return try? Data(contentsOf: fileURL)
    }
}
