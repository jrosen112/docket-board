//
//  SharedBoardTitle.swift
//  Docket
//
//  How a joined board gets its name from CloudKit. Invite acceptance and
//  later-device discovery both go through here, so the same board is not
//  "Dana's Board" on the phone and "Shared Board" on the iPad.
//

import Foundation

nonisolated enum SharedBoardTitle {
    /// The share's own title if the owner set one, otherwise a possessive
    /// built from the owner's name. Nil when CloudKit offers neither, leaving
    /// the generic fallback to the caller.
    static func resolve(shareTitle: String?, ownerName: String?) -> String? {
        if let shareTitle = shareTitle?.orNil { return shareTitle }
        guard let ownerName = ownerName?.orNil else { return nil }
        return ownerName.hasSuffix("s")
            ? "\(ownerName)’ Board"
            : "\(ownerName)’s Board"
    }

    /// The short display name for a CloudKit identity, or nil when the account
    /// exposes no name components.
    static func ownerName(from components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        return PersonNameComponentsFormatter.localizedString(
            from: components,
            style: .short,
            options: []
        ).orNil
    }
}
