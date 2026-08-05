//
//  BoardReaction.swift
//  Docket
//
//  A single participant's tapback on a board item. The record name is
//  deterministic for an item/profile pair, which makes CloudKit itself enforce
//  the "one reaction per person per item" rule across devices.
//

import CloudKit

/// One tapback emoji.
///
/// The six `standard` kinds are the iMessage set and lead the picker, but the
/// picker's `+` can produce any emoji, so this is a validated string rather than
/// a closed enum. CloudKit always stored the emoji itself in `reactionKind`, so
/// widening the set needs no schema change and no migration — an older build
/// simply renders an unfamiliar emoji it never offers.
nonisolated struct BoardReactionKind: RawRepresentable, Hashable, Identifiable, Sendable {
    let rawValue: String

    /// Fails for anything that is not exactly one emoji, which keeps arbitrary
    /// text out of a field that is rendered as a glyph everywhere it appears.
    init?(rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 1,
            let character = trimmed.first,
            Self.isEmoji(character)
        else { return nil }
        self.rawValue = trimmed
    }

    /// Bypasses validation for the built-in set, which is known-good and needs
    /// to be usable as a `let` constant.
    private init(builtIn rawValue: String) {
        self.rawValue = rawValue
    }

    static let love = BoardReactionKind(builtIn: "❤️")
    static let like = BoardReactionKind(builtIn: "👍")
    static let dislike = BoardReactionKind(builtIn: "👎")
    static let laugh = BoardReactionKind(builtIn: "😂")
    static let emphasize = BoardReactionKind(builtIn: "‼️")
    static let question = BoardReactionKind(builtIn: "❓")

    /// The always-offered kinds, in picker order.
    static let standard: [BoardReactionKind] = [
        .love, .like, .dislike, .laugh, .emphasize, .question,
    ]

    private static let standardLabels: [BoardReactionKind: String] = [
        .love: "Love",
        .like: "Like",
        .dislike: "Dislike",
        .laugh: "Laugh",
        .emphasize: "Emphasize",
        .question: "Question",
    ]

    var id: String { rawValue }

    var isStandard: Bool { Self.standardLabels[self] != nil }

    /// Spoken name. Custom emoji have no name of ours to give, so VoiceOver is
    /// left to read the glyph itself.
    var label: String { Self.standardLabels[self] ?? rawValue }

    /// A single scalar has to default to emoji presentation on its own; digits
    /// and `#` are `Emoji=Yes` but only read as emoji inside a keycap sequence,
    /// which arrives as a multi-scalar cluster carrying U+FE0F.
    private static func isEmoji(_ character: Character) -> Bool {
        let scalars = character.unicodeScalars
        guard let first = scalars.first else { return false }
        guard scalars.count > 1 else { return first.properties.isEmojiPresentation }
        return first.properties.isEmoji
            && scalars.contains { $0.properties.isEmojiPresentation || $0 == "\u{FE0F}" }
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

/// One person behind a tapback. Carries enough to draw an avatar, not just a
/// name: `imageData` stays nil until the `profilePicture` CKAsset work lands, at
/// which point avatars upgrade from initials without touching call sites.
nonisolated struct BoardReactionPerson: Identifiable, Equatable, Sendable {
    let profileID: CKRecord.ID
    let displayName: String
    let initials: String
    var imageData: Data?

    var id: CKRecord.ID { profileID }
}

nonisolated struct BoardReactionAttribution: Identifiable, Equatable, Sendable {
    let kind: BoardReactionKind
    let people: [BoardReactionPerson]

    var id: BoardReactionKind { kind }
}
