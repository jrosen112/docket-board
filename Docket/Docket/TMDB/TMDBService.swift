import Foundation

nonisolated struct TMDBMovieSummary: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let title: String
    let originalTitle: String
    let overview: String
    let releaseDate: String?
    let posterPath: String?

    var releaseYear: Int? {
        guard let releaseDate,
            let year = releaseDate.split(separator: "-").first
        else { return nil }
        return Int(year)
    }

    var subtitle: String {
        let year = releaseYear.map(String.init) ?? "Year unknown"
        guard originalTitle.caseInsensitiveCompare(title) != .orderedSame else {
            return year
        }
        return "\(year) · \(originalTitle)"
    }

    var posterThumbnailURL: URL? {
        TMDBService.posterURL(path: posterPath, size: "w185")
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case originalTitle = "original_title"
        case overview
        case releaseDate = "release_date"
        case posterPath = "poster_path"
    }
}

nonisolated struct TMDBMovieSelection: Equatable, Sendable {
    let id: Int
    let title: String
    let releaseYear: Int?
    let runtimeMinutes: Int?
    let posterData: Data?
    /// Path behind `posterData`, kept so the stored artwork can be re-fetched at
    /// full resolution later. `nil` when no poster was downloaded.
    let posterPath: String?
}

nonisolated enum TMDBServiceError: Error, Equatable, Sendable {
    case invalidRequest
    case invalidResponse
    case unauthorized
    case rateLimited
    case serverUnavailable
    case decodingFailed

    var userMessage: String {
        switch self {
        case .unauthorized:
            "Movie lookup isn't configured correctly in this build."
        case .rateLimited:
            "TMDB is receiving too many requests right now. Try again in a moment."
        case .serverUnavailable:
            "TMDB is unavailable right now. Try again shortly."
        case .invalidRequest, .invalidResponse, .decodingFailed:
            "Movie information couldn't be loaded. Please try again."
        }
    }
}

nonisolated enum TMDBConfiguration {
    static var apiKey: String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "TMDBAPIKey") as? String else {
            return nil
        }

        let key = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !key.contains("$(") else { return nil }
        return key
    }
}

nonisolated struct TMDBService: Sendable {
    private let apiKey: String
    private let session: URLSession
    private let apiBaseURL: URL

    init(
        apiKey: String,
        session: URLSession = .shared,
        apiBaseURL: URL = URL(string: "https://api.themoviedb.org/3/")!
    ) {
        self.apiKey = apiKey
        self.session = session
        self.apiBaseURL = apiBaseURL
    }

    static var live: TMDBService? {
        guard let apiKey = TMDBConfiguration.apiKey else { return nil }
        return TMDBService(apiKey: apiKey)
    }

    func searchMovies(query: String) async throws -> [TMDBMovieSummary] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }

        let data = try await request(
            path: "search/movie",
            queryItems: [
                URLQueryItem(name: "query", value: trimmedQuery),
                URLQueryItem(name: "include_adult", value: "false"),
                URLQueryItem(name: "language", value: "en-US"),
            ]
        )

        do {
            return try JSONDecoder().decode(SearchResponse.self, from: data).results
        } catch {
            throw TMDBServiceError.decodingFailed
        }
    }

    func movieSelection(for summary: TMDBMovieSummary) async throws -> TMDBMovieSelection {
        let details = try await movieDetails(id: summary.id)
        let posterPath = details.posterPath ?? summary.posterPath
        let posterData = await posterData(path: posterPath)

        return TMDBMovieSelection(
            id: details.id,
            title: details.title,
            releaseYear: details.releaseYear ?? summary.releaseYear,
            runtimeMinutes: details.runtime,
            posterData: posterData,
            // Only report a path when its artwork actually downloaded, so callers
            // never pair a stored photo with a different movie's poster.
            posterPath: posterData == nil ? nil : posterPath
        )
    }

    static func posterURL(path: String?, size: String = "w500") -> URL? {
        guard let path, !path.isEmpty else { return nil }
        let normalizedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return URL(string: "https://image.tmdb.org/t/p/\(size)/\(normalizedPath)")
    }

    /// Highest resolution TMDB publishes for a poster. `image.tmdb.org` is an
    /// unauthenticated CDN, so this needs no API key and no API request — a
    /// stored poster path is enough to load full-resolution artwork offline of
    /// the API.
    static func fullResolutionPosterURL(path: String?) -> URL? {
        posterURL(path: path, size: "original")
    }

    private func movieDetails(id: Int) async throws -> MovieDetails {
        let data = try await request(
            path: "movie/\(id)",
            queryItems: [URLQueryItem(name: "language", value: "en-US")]
        )

        do {
            return try JSONDecoder().decode(MovieDetails.self, from: data)
        } catch {
            throw TMDBServiceError.decodingFailed
        }
    }

    private func posterData(path: String?) async -> Data? {
        guard let url = Self.posterURL(path: path) else { return nil }

        do {
            let (data, response) = try await session.data(from: url)
            guard let response = response as? HTTPURLResponse,
                (200..<300).contains(response.statusCode),
                !data.isEmpty
            else { return nil }
            return data
        } catch {
            return nil
        }
    }

    private func request(path: String, queryItems: [URLQueryItem]) async throws -> Data {
        guard
            var components = URLComponents(
                url: apiBaseURL.appending(path: path),
                resolvingAgainstBaseURL: false
            )
        else {
            throw TMDBServiceError.invalidRequest
        }

        components.queryItems = queryItems + [URLQueryItem(name: "api_key", value: apiKey)]
        guard let url = components.url else { throw TMDBServiceError.invalidRequest }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.cachePolicy = .returnCacheDataElseLoad
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw TMDBServiceError.serverUnavailable
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TMDBServiceError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200..<300:
            return data
        case 401, 403:
            throw TMDBServiceError.unauthorized
        case 429:
            throw TMDBServiceError.rateLimited
        case 500..<600:
            throw TMDBServiceError.serverUnavailable
        default:
            throw TMDBServiceError.invalidResponse
        }
    }
}

private nonisolated struct SearchResponse: Decodable {
    let results: [TMDBMovieSummary]
}

private nonisolated struct MovieDetails: Decodable {
    let id: Int
    let title: String
    let releaseDate: String?
    let runtime: Int?
    let posterPath: String?

    var releaseYear: Int? {
        guard let releaseDate,
            let year = releaseDate.split(separator: "-").first
        else { return nil }
        return Int(year)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case releaseDate = "release_date"
        case runtime
        case posterPath = "poster_path"
    }
}
