import CloudKit

nonisolated enum ItemDraftField: Hashable {
    case title
    case status
    case location
    case cuisine
    case priceRange
    case barType
    case runtime
    case streamingService
    case releaseYear
    case notes
    case photo
    case showsPhotoOnBoard
}

nonisolated struct ItemDraft {
    var category: ItemCategory = .restaurant
    var title = ""
    var notes = ""
    var status: ItemStatus = .wantToGo
    var photoData: Data?
    var showsPhotoOnBoard = false

    var location = ""
    var cuisine = ""
    var priceRange: PriceRange?
    var barType: BarType?
    var runtime = ""
    var streamingService = ""
    var releaseYear = ""
    var tmdbID: Int?

    var isValid: Bool { !title.trimmed.isEmpty }

    init(category: ItemCategory = .restaurant) {
        self.category = category
    }

    init(item: any SharedListItem) {
        category = item.category
        title = item.title
        notes = item.notes ?? ""
        status = item.status
        photoData = item.photoData
        showsPhotoOnBoard = item.showsPhotoOnBoard

        switch item {
        case let restaurant as Restaurant:
            location = restaurant.location ?? ""
            cuisine = restaurant.cuisine ?? ""
            priceRange = restaurant.priceRange
        case let bar as Bar:
            location = bar.location ?? ""
            barType = bar.barType
        case let movie as Movie:
            runtime = movie.runtimeMinutes.map(String.init) ?? ""
            streamingService = movie.streamingService ?? ""
            releaseYear = movie.releaseYear.map(String.init) ?? ""
            tmdbID = movie.tmdbID
        default:
            break
        }
    }

    /// Applies editable fields while preserving record identity, attribution,
    /// creation date, and CloudKit system fields from the fetched model.
    func applying(to existing: any SharedListItem) -> (any SharedListItem)? {
        switch existing {
        case var restaurant as Restaurant:
            restaurant.title = title.trimmed
            restaurant.notes = notes.orNil
            restaurant.status = status
            restaurant.photoData = photoData
            restaurant.showsPhotoOnBoard = showsPhotoOnBoard
            restaurant.location = location.orNil
            restaurant.cuisine = cuisine.orNil
            restaurant.priceRange = priceRange
            return restaurant
        case var bar as Bar:
            bar.title = title.trimmed
            bar.notes = notes.orNil
            bar.status = status
            bar.photoData = photoData
            bar.showsPhotoOnBoard = showsPhotoOnBoard
            bar.location = location.orNil
            bar.barType = barType
            return bar
        case var movie as Movie:
            movie.title = title.trimmed
            movie.notes = notes.orNil
            movie.status = status
            movie.photoData = photoData
            movie.showsPhotoOnBoard = showsPhotoOnBoard
            movie.runtimeMinutes = Int(runtime)
            movie.streamingService = streamingService.orNil
            movie.releaseYear = Int(releaseYear)
            movie.tmdbID = tmdbID
            return movie
        default:
            return nil
        }
    }

    func makeNew(
        id: CKRecord.ID,
        addedBy: CKRecord.Reference,
        dateAdded: Date = .now
    ) -> (any SharedListItem)? {
        switch category {
        case .restaurant:
            Restaurant(
                id: id,
                title: title.trimmed,
                notes: notes.orNil,
                status: status,
                addedBy: addedBy,
                dateAdded: dateAdded,
                photoData: photoData,
                showsPhotoOnBoard: showsPhotoOnBoard,
                location: location.orNil,
                cuisine: cuisine.orNil,
                priceRange: priceRange
            )
        case .bar:
            Bar(
                id: id,
                title: title.trimmed,
                notes: notes.orNil,
                status: status,
                addedBy: addedBy,
                dateAdded: dateAdded,
                photoData: photoData,
                showsPhotoOnBoard: showsPhotoOnBoard,
                location: location.orNil,
                barType: barType
            )
        case .movie:
            Movie(
                id: id,
                title: title.trimmed,
                notes: notes.orNil,
                status: status,
                addedBy: addedBy,
                dateAdded: dateAdded,
                photoData: photoData,
                showsPhotoOnBoard: showsPhotoOnBoard,
                runtimeMinutes: Int(runtime),
                streamingService: streamingService.orNil,
                releaseYear: Int(releaseYear),
                tmdbID: tmdbID
            )
        default:
            nil
        }
    }
}
