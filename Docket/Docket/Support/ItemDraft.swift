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
    case showsMapOnBoard
}

nonisolated enum BoardCardMedia: String, CaseIterable, Hashable {
    case none
    case photo
    case map

    var label: String {
        switch self {
        case .none: "None"
        case .photo: "Photo"
        case .map: "Map"
        }
    }

    var symbol: String {
        switch self {
        case .none: "rectangle.slash"
        case .photo: "photo.fill"
        case .map: "map.fill"
        }
    }
}

nonisolated struct ItemDraft {
    var category: ItemCategory = .restaurant
    var title = ""
    var notes = ""
    var status: ItemStatus = .wantToGo
    var photoData: Data?
    var showsPhotoOnBoard = false
    var showsMapOnBoard = false

    var location: ItemLocation?
    var cuisine = ""
    var priceRange: PriceRange?
    var barType: BarType?
    var runtime = ""
    var streamingService = ""
    var releaseYear = ""
    var tmdbID: Int?

    var isValid: Bool { !title.trimmed.isEmpty }

    var supportsLocation: Bool {
        category == .restaurant || category == .bar
    }

    var boardCardMedia: BoardCardMedia {
        get {
            if showsPhotoOnBoard, photoData != nil { return .photo }
            if showsMapOnBoard, location != nil, supportsLocation { return .map }
            return .none
        }
        set {
            showsPhotoOnBoard = newValue == .photo && photoData != nil
            showsMapOnBoard = newValue == .map && location != nil && supportsLocation
        }
    }

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
            location = restaurant.location
            showsMapOnBoard = restaurant.showsMapOnBoard
            cuisine = restaurant.cuisine ?? ""
            priceRange = restaurant.priceRange
        case let bar as Bar:
            location = bar.location
            showsMapOnBoard = bar.showsMapOnBoard
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
        let boardMedia = boardCardMedia
        switch existing {
        case var restaurant as Restaurant:
            restaurant.title = title.trimmed
            restaurant.notes = notes.orNil
            restaurant.status = status
            restaurant.photoData = photoData
            restaurant.showsPhotoOnBoard = boardMedia == .photo
            restaurant.location = location
            restaurant.showsMapOnBoard = boardMedia == .map
            restaurant.cuisine = cuisine.orNil
            restaurant.priceRange = priceRange
            return restaurant
        case var bar as Bar:
            bar.title = title.trimmed
            bar.notes = notes.orNil
            bar.status = status
            bar.photoData = photoData
            bar.showsPhotoOnBoard = boardMedia == .photo
            bar.location = location
            bar.showsMapOnBoard = boardMedia == .map
            bar.barType = barType
            return bar
        case var movie as Movie:
            movie.title = title.trimmed
            movie.notes = notes.orNil
            movie.status = status
            movie.photoData = photoData
            movie.showsPhotoOnBoard = boardMedia == .photo
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
        let boardMedia = boardCardMedia
        return switch category {
        case .restaurant:
            Restaurant(
                id: id,
                title: title.trimmed,
                notes: notes.orNil,
                status: status,
                addedBy: addedBy,
                dateAdded: dateAdded,
                photoData: photoData,
                showsPhotoOnBoard: boardMedia == .photo,
                location: location,
                showsMapOnBoard: boardMedia == .map,
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
                showsPhotoOnBoard: boardMedia == .photo,
                location: location,
                showsMapOnBoard: boardMedia == .map,
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
                showsPhotoOnBoard: boardMedia == .photo,
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
