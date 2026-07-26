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
        static let recipe = "Recipe"
        static let movie = "Movie"
        static let boardReaction = "BoardReaction"
    }

    /// CKRecord field keys, shared and category-specific.
    enum Field {
        // MARK: SharedListItem (present on every category record)
        static let title = "title"
        static let notes = "notes"
        static let status = "status"
        static let addedBy = "addedBy"  // CKRecord.Reference -> UserProfile
        static let dateAdded = "dateAdded"
        static let plannedDate = "plannedDate"
        static let plannedDateHasTime = "plannedDateHasTime"
        static let completionDates = "completionDates"
        static let itemPhoto = "itemPhoto"  // CKAsset
        static let showsPhotoOnBoard = "showsPhotoOnBoard"
        static let boardPhotoPositionX = "boardPhotoPositionX"
        static let boardPhotoPositionY = "boardPhotoPositionY"

        // MARK: Location-based categories
        static let locationName = "locationName"
        static let locationFullAddress = "locationFullAddress"
        static let locationShortAddress = "locationShortAddress"
        static let locationCity = "locationCity"
        static let locationCityWithContext = "locationCityWithContext"
        static let locationCountry = "locationCountry"
        static let locationCountryCode = "locationCountryCode"
        static let locationCoordinate = "locationCoordinate"  // CLLocation
        static let locationMapItemIdentifier = "locationMapItemIdentifier"
        static let showsMapOnBoard = "showsMapOnBoard"

        // MARK: UserProfile
        static let firstName = "firstName"
        static let lastName = "lastName"
        /// Opaque, container-scoped ID from `CKContainer.userRecordID()`.
        /// Unlike creator metadata, this has the same representation after a
        /// reinstall and in both private and shared database scopes.
        static let accountRecordName = "accountRecordName"
        static let profilePicture = "profilePicture"  // CKAsset (added with photo work)

        // MARK: BoardReaction
        static let reactionItem = "reactionItem"  // CKRecord.Reference -> board item
        static let reactedBy = "reactedBy"  // CKRecord.Reference -> UserProfile
        static let reactionKind = "reactionKind"
        static let reactionDateAdded = "reactionDateAdded"

        // MARK: Restaurant
        /// Multi-value replacement for the legacy singular `cuisine` field.
        static let cuisines = "cuisines"
        static let cuisine = "cuisine"
        static let priceRange = "priceRange"

        // MARK: Bar
        static let barType = "barType"

        // MARK: Recipe
        static let sourceURL = "sourceURL"
        static let ingredients = "ingredients"
        static let instructions = "instructions"
        static let recipePhoto2 = "recipePhoto2"
        static let recipePhoto3 = "recipePhoto3"
        static let recipePhoto4 = "recipePhoto4"
        static let recipePhoto5 = "recipePhoto5"

        static let additionalRecipePhotos = [
            recipePhoto2,
            recipePhoto3,
            recipePhoto4,
            recipePhoto5,
        ]

        // MARK: Movie
        static let runtimeMinutes = "runtimeMinutes"
        static let streamingService = "streamingService"
        static let releaseYear = "releaseYear"
        static let tmdbID = "tmdbID"
        static let tmdbPosterPath = "tmdbPosterPath"
    }

    /// The single shared record zone that a "space" (two participants) lives in.
    static let zoneName = "SharedSpace"
}
