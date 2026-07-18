//
//  CloudKitSchema.swift
//  Docket
//
//  Single source of truth for CloudKit record-type names and field keys.
//  CloudKit's schema is CASE-SENSITIVE and silently creates a duplicate field
//  on a typo, so every record read/write in the app must go through these
//  constants rather than inline string literals.
//
//  Everything is namespaced under `Schema` on purpose: CloudKit already defines
//  `CKRecord.RecordType` and `CKRecord.FieldKey` (both aliases for String), so
//  bare `RecordType` / `FieldKey` names would collide inside CKRecord extensions.
//

import Foundation

nonisolated enum Schema {

    /// CKRecord type names.
    enum RecordType {
        static let userProfile = "UserProfile"
        static let restaurant = "Restaurant"
        static let bar = "Bar"
        static let movie = "Movie"
    }

    /// CKRecord field keys, shared and category-specific.
    enum Field {
        // MARK: SharedListItem (present on every category record)
        static let title = "title"
        static let notes = "notes"
        static let status = "status"
        static let addedBy = "addedBy"          // CKRecord.Reference -> UserProfile
        static let dateAdded = "dateAdded"
        static let itemPhoto = "itemPhoto"      // CKAsset
        static let showsPhotoOnBoard = "showsPhotoOnBoard"

        // MARK: Location-based categories
        static let location = "location"

        // MARK: UserProfile
        static let firstName = "firstName"
        static let lastName = "lastName"
        /// Opaque, container-scoped ID from `CKContainer.userRecordID()`.
        /// Unlike creator metadata, this has the same representation after a
        /// reinstall and in both private and shared database scopes.
        static let accountRecordName = "accountRecordName"
        static let profilePicture = "profilePicture"   // CKAsset (added with photo work)

        // MARK: Restaurant
        static let cuisine = "cuisine"
        static let priceRange = "priceRange"

        // MARK: Bar
        static let barType = "barType"

        // MARK: Movie
        static let runtimeMinutes = "runtimeMinutes"
        static let streamingService = "streamingService"
        static let releaseYear = "releaseYear"
        static let tmdbID = "tmdbID"
    }

    /// The single shared record zone that a "space" (two participants) lives in.
    static let zoneName = "SharedSpace"
}
