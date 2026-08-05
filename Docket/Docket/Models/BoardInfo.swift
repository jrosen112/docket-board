//
//  BoardInfo.swift
//  Docket
//
//  The board's own name, stored as a record inside its zone. Titles used to
//  live only in the creating device's local defaults, so a second device — or
//  the person on the other side of a share — had nothing to read and fell back
//  to "Shared Board"/"Recovered Board". The record name is fixed per zone, so
//  publishing a title is an upsert rather than a source of duplicates.
//

import CloudKit

nonisolated struct BoardInfo: Equatable, Sendable {
    /// One board record per zone, at a known address.
    static let fixedRecordName = "board-info"

    let id: CKRecord.ID
    var title: String
    var titleUpdatedAt: Date
    var systemFields: Data?

    init(zoneID: CKRecordZone.ID, title: String, titleUpdatedAt: Date = .now) {
        self.id = Self.recordID(in: zoneID)
        self.title = title
        self.titleUpdatedAt = titleUpdatedAt
    }

    init?(record: CKRecord) {
        guard record.recordType == Schema.RecordType.board,
            let title = (record[Schema.Field.title] as? String)?.orNil
        else { return nil }

        self.id = record.recordID
        self.title = title
        self.titleUpdatedAt = record[Schema.Field.titleUpdatedAt] as? Date ?? .distantPast
        self.systemFields = record.systemFieldsData
    }

    func toRecord() -> CKRecord {
        let record = CKRecord.base(
            type: Schema.RecordType.board,
            id: id,
            systemFields: systemFields
        )
        record[Schema.Field.title] = title
        record[Schema.Field.titleUpdatedAt] = titleUpdatedAt
        return record
    }

    static func recordID(in zoneID: CKRecordZone.ID) -> CKRecord.ID {
        CKRecord.ID(recordName: fixedRecordName, zoneID: zoneID)
    }
}
