//
//  BoardReaction.swift
//  Docket
//
//  A single participant's tapback on a board item. The record name is
//  deterministic for an item/profile pair, which makes CloudKit itself enforce
//  the "one reaction per person per item" rule across devices.
//

import CloudKit

nonisolated enum BoardReactionKind: String, CaseIterable, Identifiable, Sendable {
    case love = "❤️"
    case like = "👍"
    case dislike = "👎"
    case laugh = "😂"
    case emphasize = "‼️"
    case question = "❓"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .love: "Love"
        case .like: "Like"
        case .dislike: "Dislike"
        case .laugh: "Laugh"
        case .emphasize: "Emphasize"
        case .question: "Question"
        }
    }
}

nonisolated struct BoardReaction: Identifiable, Equatable, Sendable {
    let id: CKRecord.ID
    let itemReference: CKRecord.Reference
    let reactedBy: CKRecord.Reference
    var kind: BoardReactionKind
    let dateAdded: Date
    var systemFields: Data?

    var itemID: CKRecord.ID { itemReference.recordID }
    var profileID: CKRecord.ID { reactedBy.recordID }

    init(
        id: CKRecord.ID,
        itemID: CKRecord.ID,
        reactedBy: CKRecord.Reference,
        kind: BoardReactionKind,
        dateAdded: Date = .now
    ) {
        self.id = id
        self.itemReference = CKRecord.Reference(recordID: itemID, action: .deleteSelf)
        self.reactedBy = reactedBy
        self.kind = kind
        self.dateAdded = dateAdded
    }

    init?(record: CKRecord) {
        guard
            record.recordType == Schema.RecordType.boardReaction,
            let itemReference = record[Schema.Field.reactionItem] as? CKRecord.Reference,
            let reactedBy = record[Schema.Field.reactedBy] as? CKRecord.Reference,
            let rawKind = record[Schema.Field.reactionKind] as? String,
            let kind = BoardReactionKind(rawValue: rawKind),
            let dateAdded = record[Schema.Field.reactionDateAdded] as? Date
        else { return nil }

        self.id = record.recordID
        self.itemReference = itemReference
        self.reactedBy = reactedBy
        self.kind = kind
        self.dateAdded = dateAdded
        self.systemFields = record.systemFieldsData
    }

    func toRecord() -> CKRecord {
        let record = CKRecord.base(
            type: Schema.RecordType.boardReaction,
            id: id,
            systemFields: systemFields
        )
        record[Schema.Field.reactionItem] = itemReference
        record[Schema.Field.reactedBy] = reactedBy
        record[Schema.Field.reactionKind] = kind.rawValue
        record[Schema.Field.reactionDateAdded] = dateAdded
        return record
    }

    static func recordID(
        for itemID: CKRecord.ID,
        profileID: CKRecord.ID
    ) -> CKRecord.ID {
        CKRecord.ID(
            recordName: "reaction-\(itemID.recordName)-\(profileID.recordName)",
            zoneID: itemID.zoneID
        )
    }
}

nonisolated struct BoardReactionGroup: Identifiable, Equatable, Sendable {
    let kind: BoardReactionKind
    let count: Int
    let includesCurrentUser: Bool

    var id: BoardReactionKind { kind }
}

nonisolated struct BoardReactionAttribution: Identifiable, Equatable, Sendable {
    let kind: BoardReactionKind
    let names: [String]

    var id: BoardReactionKind { kind }
}
