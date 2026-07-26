import CloudKit

nonisolated enum ItemDraftField: Hashable {
    case title
    case status
    case location
    case cuisine
    case priceRange
    case barType
    case sourceURL
    case ingredients
    case instructions
    case runtime
    case streamingService
    case releaseYear
    case dates
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
    var plannedDate: Date?
    var plannedDateHasTime = false
    var completionDates: [Date] = []
    var photoData: Data? {
        didSet {
            // Replacing or clearing the photo invalidates the remote artwork it
            // was downsized from, so a hand-picked image can never inherit the
            // previous movie's poster. Callers that supply both — TMDB
            // selection — set the path after assigning the photo.
            guard photoData != oldValue else { return }
            tmdbPosterPath = nil
        }
    }
    var showsPhotoOnBoard = false
    var showsMapOnBoard = false
    var boardPhotoPosition: BoardPhotoPosition = .center

    var location: ItemLocation?
    var cuisines: [String] = []
    /// Compatibility bridge for callers that still set a single cuisine.
    var cuisine: String {
        get { cuisines.first ?? "" }
        set { cuisines = CuisineCatalog.normalized([newValue]) }
    }
    var priceRange: PriceRange?
    var barType: BarType?
    var sourceURL = ""
    var ingredients = ""
    var instructions = ""
    var additionalPhotoData: [Data] = []
    var runtime = ""
    var streamingService = ""
    var releaseYear = ""
    var tmdbID: Int?
    var tmdbPosterPath: String?

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
        plannedDate = item.plannedDate
        plannedDateHasTime = item.plannedDateHasTime
        completionDates = item.completionDates.sorted(by: >)
        photoData = item.photoData
        showsPhotoOnBoard = item.showsPhotoOnBoard
        boardPhotoPosition = item.boardPhotoPosition

        switch item {
        case let restaurant as Restaurant:
            location = restaurant.location
            showsMapOnBoard = restaurant.showsMapOnBoard
            cuisines = restaurant.cuisines
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
            tmdbPosterPath = movie.tmdbPosterPath
        case let recipe as Recipe:
            cuisines = recipe.cuisines
            sourceURL = recipe.sourceURL ?? ""
            ingredients = recipe.ingredients.joined(separator: "\n")
            instructions = recipe.instructions.joined(separator: "\n")
            additionalPhotoData = recipe.additionalPhotoData
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
            restaurant.plannedDate = plannedDate
            restaurant.plannedDateHasTime = plannedDate != nil && plannedDateHasTime
            restaurant.completionDates = completionDates
            restaurant.photoData = photoData
            restaurant.showsPhotoOnBoard = boardMedia == .photo
            restaurant.boardPhotoPosition = boardPhotoPosition
            restaurant.location = location
            restaurant.showsMapOnBoard = boardMedia == .map
            restaurant.cuisines = CuisineCatalog.normalized(cuisines)
            restaurant.priceRange = priceRange
            return restaurant
        case var bar as Bar:
            bar.title = title.trimmed
            bar.notes = notes.orNil
            bar.status = status
            bar.plannedDate = plannedDate
            bar.plannedDateHasTime = plannedDate != nil && plannedDateHasTime
            bar.completionDates = completionDates
            bar.photoData = photoData
            bar.showsPhotoOnBoard = boardMedia == .photo
            bar.boardPhotoPosition = boardPhotoPosition
            bar.location = location
            bar.showsMapOnBoard = boardMedia == .map
            bar.barType = barType
            return bar
        case var movie as Movie:
            movie.title = title.trimmed
            movie.notes = notes.orNil
            movie.status = status
            movie.plannedDate = plannedDate
            movie.plannedDateHasTime = plannedDate != nil && plannedDateHasTime
            movie.completionDates = completionDates
            movie.photoData = photoData
            movie.showsPhotoOnBoard = boardMedia == .photo
            movie.boardPhotoPosition = boardPhotoPosition
            movie.runtimeMinutes = Int(runtime)
            movie.streamingService = streamingService.orNil
            movie.releaseYear = Int(releaseYear)
            movie.tmdbID = tmdbID
            movie.tmdbPosterPath = tmdbPosterPath
            return movie
        case var recipe as Recipe:
            recipe.title = title.trimmed
            recipe.notes = notes.orNil
            recipe.status = status
            recipe.plannedDate = plannedDate
            recipe.plannedDateHasTime = plannedDate != nil && plannedDateHasTime
            recipe.completionDates = completionDates
            recipe.photoData = photoData
            recipe.additionalPhotoData = Array(
                additionalPhotoData.prefix(Recipe.maximumPhotoCount - 1)
            )
            recipe.showsPhotoOnBoard = boardMedia == .photo
            recipe.boardPhotoPosition = boardPhotoPosition
            recipe.cuisines = CuisineCatalog.normalized(cuisines)
            recipe.sourceURL = sourceURL.orNil
            recipe.ingredients = ingredientLines
            recipe.instructions = instructionLines
            return recipe
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
                plannedDate: plannedDate,
                plannedDateHasTime: plannedDate != nil && plannedDateHasTime,
                completionDates: completionDates,
                photoData: photoData,
                showsPhotoOnBoard: boardMedia == .photo,
                boardPhotoPosition: boardPhotoPosition,
                location: location,
                showsMapOnBoard: boardMedia == .map,
                cuisines: CuisineCatalog.normalized(cuisines),
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
                plannedDate: plannedDate,
                plannedDateHasTime: plannedDate != nil && plannedDateHasTime,
                completionDates: completionDates,
                photoData: photoData,
                showsPhotoOnBoard: boardMedia == .photo,
                boardPhotoPosition: boardPhotoPosition,
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
                plannedDate: plannedDate,
                plannedDateHasTime: plannedDate != nil && plannedDateHasTime,
                completionDates: completionDates,
                photoData: photoData,
                showsPhotoOnBoard: boardMedia == .photo,
                boardPhotoPosition: boardPhotoPosition,
                runtimeMinutes: Int(runtime),
                streamingService: streamingService.orNil,
                releaseYear: Int(releaseYear),
                tmdbID: tmdbID,
                tmdbPosterPath: tmdbPosterPath
            )
        case .recipe:
            Recipe(
                id: id,
                title: title.trimmed,
                notes: notes.orNil,
                status: status,
                addedBy: addedBy,
                dateAdded: dateAdded,
                plannedDate: plannedDate,
                plannedDateHasTime: plannedDate != nil && plannedDateHasTime,
                completionDates: completionDates,
                photoData: photoData,
                showsPhotoOnBoard: boardMedia == .photo,
                boardPhotoPosition: boardPhotoPosition,
                sourceURL: sourceURL.orNil,
                cuisines: CuisineCatalog.normalized(cuisines),
                ingredients: ingredientLines,
                instructions: instructionLines,
                additionalPhotoData: additionalPhotoData
            )
        default:
            nil
        }
    }

    private var ingredientLines: [String] { listLines(from: ingredients) }
    private var instructionLines: [String] { listLines(from: instructions) }

    mutating func addPlannedDate(
        relativeTo now: Date = .now,
        calendar: Calendar = .current
    ) {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        plannedDate =
            calendar.date(
                bySettingHour: 19,
                minute: 0,
                second: 0,
                of: tomorrow
            ) ?? tomorrow
        plannedDateHasTime = false
        status = .planned
    }

    mutating func removePlannedDate() {
        plannedDate = nil
        plannedDateHasTime = false
    }

    mutating func logCompletion(
        on date: Date = .now,
        calendar: Calendar = .current
    ) {
        let day = calendar.startOfDay(for: date)
        if !completionDates.contains(where: { calendar.isDate($0, inSameDayAs: day) }) {
            completionDates.append(day)
            completionDates.sort(by: >)
        }

        let nextDay = calendar.date(byAdding: .day, value: 1, to: day) ?? day
        if let plannedDate, plannedDate < nextDay {
            removePlannedDate()
        }
        status = plannedDate == nil ? .completed : .planned
    }

    private func listLines(from value: String) -> [String] {
        value.components(separatedBy: .newlines)
            .map { line in
                line.trimmed
                    .replacingOccurrences(
                        of: #"^(?:[-•*]|\d+[.)])\s*"#,
                        with: "",
                        options: .regularExpression
                    )
                    .trimmed
            }
            .filter { !$0.isEmpty }
    }
}
