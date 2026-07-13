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
}

nonisolated struct ItemDraft {
    var category: ItemCategory = .restaurant
    var title = ""
    var notes = ""
    var status: ItemStatus = .wantToGo

    var location = ""
    var cuisine = ""
    var priceRange: PriceRange?
    var barType: BarType?
    var runtime = ""
    var streamingService = ""
    var releaseYear = ""

    var isValid: Bool { !title.trimmed.isEmpty }

    init() {}

    init(item: any SharedListItem) {
        category = item.category
        title = item.title
        notes = item.notes ?? ""
        status = item.status

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
            restaurant.location = location.orNil
            restaurant.cuisine = cuisine.orNil
            restaurant.priceRange = priceRange
            return restaurant
        case var bar as Bar:
            bar.title = title.trimmed
            bar.notes = notes.orNil
            bar.status = status
            bar.location = location.orNil
            bar.barType = barType
            return bar
        case var movie as Movie:
            movie.title = title.trimmed
            movie.notes = notes.orNil
            movie.status = status
            movie.runtimeMinutes = Int(runtime)
            movie.streamingService = streamingService.orNil
            movie.releaseYear = Int(releaseYear)
            return movie
        default:
            return nil
        }
    }

    func makeNew(
        id: CKRecord.ID,
        addedBy: CKRecord.Reference
    ) -> (any SharedListItem)? {
        switch category {
        case .restaurant:
            Restaurant(
                id: id,
                title: title.trimmed,
                notes: notes.orNil,
                status: status,
                addedBy: addedBy,
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
                runtimeMinutes: Int(runtime),
                streamingService: streamingService.orNil,
                releaseYear: Int(releaseYear)
            )
        default:
            nil
        }
    }
}
