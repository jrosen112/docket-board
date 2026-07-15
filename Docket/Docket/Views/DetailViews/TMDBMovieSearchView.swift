import SwiftUI

struct TMDBMovieSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.docketSurfacePalette) private var palette

    let initialQuery: String
    let onSelect: (TMDBMovieSelection) -> Void

    @State private var query: String
    @State private var results: [TMDBMovieSummary] = []
    @State private var isSearching = false
    @State private var loadingMovieID: Int?
    @State private var errorMessage: String?

    private let service = TMDBService.live

    init(initialQuery: String, onSelect: @escaping (TMDBMovieSelection) -> Void) {
        self.initialQuery = initialQuery
        self.onSelect = onSelect
        _query = State(initialValue: initialQuery)
    }

    var body: some View {
        NavigationStack {
            Group {
                if service == nil {
                    configurationUnavailable
                } else if isSearching && results.isEmpty {
                    ProgressView("Searching TMDB…")
                        .tint(DocketTheme.brass)
                        .foregroundStyle(DocketTheme.cream)
                } else if let errorMessage, results.isEmpty {
                    ContentUnavailableView(
                        "Couldn't Search",
                        systemImage: "exclamationmark.magnifyingglass",
                        description: Text(errorMessage)
                    )
                } else if normalizedQuery.count < 2 {
                    ContentUnavailableView(
                        "Find a Movie",
                        systemImage: "film.stack",
                        description: Text("Enter at least two characters to search TMDB.")
                    )
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: normalizedQuery)
                } else {
                    resultList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DocketTheme.boardBackground)
            .navigationTitle("Find on TMDB")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DocketTheme.ink, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
            .task(id: normalizedQuery) {
                await search()
            }
        }
    }

    private var normalizedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var resultList: some View {
        List(results) { movie in
            Button {
                select(movie)
            } label: {
                TMDBMovieSearchResultRow(
                    movie: movie,
                    isLoading: loadingMovieID == movie.id
                )
            }
            .buttonStyle(.plain)
            .disabled(loadingMovieID != nil)
            .listRowBackground(palette.raisedPaper)
        }
        .scrollContentBackground(.hidden)
        .background(DocketTheme.boardBackground)
        .overlay(alignment: .top) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(DocketDetailTheme.Edit.errorColor)
                    .clipShape(Capsule())
                    .padding(.top, 8)
            }
        }
    }

    private var configurationUnavailable: some View {
        ContentUnavailableView {
            Label("TMDB Isn't Configured", systemImage: "key.horizontal")
        } description: {
            Text("Movie lookup isn't configured in this build.")
        }
    }

    @MainActor
    private func search() async {
        results = []
        errorMessage = nil

        guard normalizedQuery.count >= 2, let service else {
            isSearching = false
            return
        }

        isSearching = true
        defer { isSearching = false }

        do {
            try await Task.sleep(for: .milliseconds(350))
            let movies = try await service.searchMovies(query: normalizedQuery)
            try Task.checkCancellation()
            results = movies
        } catch is CancellationError {
            return
        } catch let error as TMDBServiceError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = "Movie information couldn't be loaded. Please try again."
        }
    }

    private func select(_ movie: TMDBMovieSummary) {
        guard let service else { return }
        loadingMovieID = movie.id
        errorMessage = nil

        Task {
            do {
                let selection = try await service.movieSelection(for: movie)
                onSelect(selection)
                dismiss()
            } catch let error as TMDBServiceError {
                errorMessage = error.userMessage
                loadingMovieID = nil
            } catch {
                errorMessage = "That movie couldn't be loaded. Please try again."
                loadingMovieID = nil
            }
        }
    }
}

private struct TMDBMovieSearchResultRow: View {
    @Environment(\.docketSurfacePalette) private var palette

    let movie: TMDBMovieSummary
    let isLoading: Bool

    var body: some View {
        HStack(spacing: 14) {
            poster

            VStack(alignment: .leading, spacing: 5) {
                Text(movie.title)
                    .font(DocketTheme.displayRegular(18))
                    .foregroundStyle(palette.primaryText)
                    .lineLimit(2)

                Text(movie.subtitle)
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(2)

                if !movie.overview.isEmpty {
                    Text(movie.overview)
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            if isLoading {
                ProgressView()
                    .tint(DocketTheme.brass)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.secondaryText)
            }
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }

    private var poster: some View {
        AsyncImage(url: movie.posterThumbnailURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            default:
                ZStack {
                    DocketTheme.inkLight
                    Image(systemName: "film")
                        .font(.title3)
                        .foregroundStyle(DocketTheme.brass)
                }
            }
        }
        .frame(width: 54, height: 81)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
