import SwiftUI

struct MovieDetailView: View {
    @Environment(\.docketSurfacePalette) private var palette

    let movie: Movie
    let addedBy: String
    let isEditing: Bool
    let allowsCategorySelection: Bool
    let saveErrorMessage: String?
    @Binding var draft: ItemDraft
    let focusedField: FocusState<ItemDraftField?>.Binding
    let onEdit: (ItemDraftField) -> Void

    @State private var showingTMDBSearch = false

    var body: some View {
        DetailPage(
            item: movie,
            addedBy: addedBy,
            symbol: "film.fill",
            isEditing: isEditing,
            allowsCategorySelection: allowsCategorySelection,
            saveErrorMessage: saveErrorMessage,
            draft: $draft,
            focusedField: focusedField,
            onEdit: onEdit
        ) {
            if isEditing {
                Button {
                    focusedField.wrappedValue = nil
                    showingTMDBSearch = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkle.magnifyingglass")
                        VStack(alignment: .leading, spacing: 2) {
                            Text(draft.tmdbID == nil ? "Find on TMDB" : "Choose a different movie")
                                .font(.subheadline.weight(.semibold))
                            Text("Fill the title, year, runtime, and poster")
                                .font(.caption)
                                .opacity(0.72)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(movie.category.accent)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 52)
                    .background(movie.category.accent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)

                DetailEditField(
                    symbol: "calendar",
                    label: "Released",
                    placeholder: "Add a year",
                    field: .releaseYear,
                    accent: movie.category.accent,
                    text: $draft.releaseYear,
                    focusedField: focusedField,
                    keyboardType: .numberPad
                )
                DetailEditField(
                    symbol: "clock.fill",
                    label: "Runtime",
                    placeholder: "Add minutes",
                    field: .runtime,
                    accent: movie.category.accent,
                    text: $draft.runtime,
                    focusedField: focusedField,
                    keyboardType: .numberPad
                )
                DetailEditField(
                    symbol: "play.tv.fill",
                    label: "Watch on",
                    placeholder: "Add a service",
                    field: .streamingService,
                    accent: movie.category.accent,
                    text: $draft.streamingService,
                    focusedField: focusedField
                )
            } else {
                DetailFactRow(
                    symbol: "calendar",
                    label: "Released",
                    value: movie.releaseYear.map(String.init) ?? "Add year",
                    accent: movie.category.accent,
                    isPlaceholder: movie.releaseYear == nil,
                    onTap: { onEdit(.releaseYear) }
                )
                DetailFactRow(
                    symbol: "clock.fill",
                    label: "Runtime",
                    value: movie.runtimeMinutes.map { "\($0) min" } ?? "Add runtime",
                    accent: movie.category.accent,
                    isPlaceholder: movie.runtimeMinutes == nil,
                    onTap: { onEdit(.runtime) }
                )
                DetailFactRow(
                    symbol: "play.tv.fill",
                    label: "Watch on",
                    value: movie.streamingService ?? "Add service",
                    accent: movie.category.accent,
                    isPlaceholder: movie.streamingService == nil,
                    onTap: { onEdit(.streamingService) }
                )

                if let tmdbURL = movie.tmdbURL {
                    Link(destination: tmdbURL) {
                        HStack(spacing: DocketDetailTheme.Fact.rowSpacing) {
                            Image(systemName: "arrow.up.right.square.fill")
                                .font(DocketDetailTheme.Fact.symbolFont)
                                .foregroundStyle(movie.category.accent)
                                .frame(width: DocketDetailTheme.Fact.symbolWidth)

                            Text("Movie information")
                                .font(DocketDetailTheme.Fact.labelFont)
                                .foregroundStyle(palette.secondaryText)

                            Spacer(minLength: DocketDetailTheme.Fact.valueMinimumSpacing)

                            Text("View on TMDB")
                                .font(DocketDetailTheme.Fact.valueFont)
                                .foregroundStyle(palette.primaryText)
                        }
                        .padding(.vertical, DocketDetailTheme.Fact.verticalPadding)
                    }
                }
            }
        }
        .sheet(isPresented: $showingTMDBSearch) {
            TMDBMovieSearchView(initialQuery: draft.title) { selection in
                apply(selection)
            }
        }
    }

    private func apply(_ selection: TMDBMovieSelection) {
        draft.tmdbID = selection.id
        draft.title = selection.title
        if let releaseYear = selection.releaseYear {
            draft.releaseYear = String(releaseYear)
        }
        if let runtimeMinutes = selection.runtimeMinutes {
            draft.runtime = String(runtimeMinutes)
        }
        if let posterData = selection.posterData,
            let preparedPoster = ItemPhotoProcessor.preparedData(from: posterData)
        {
            draft.photoData = preparedPoster
            draft.showsPhotoOnBoard = true
            draft.boardPhotoPosition = .center
        }
    }
}

extension Movie {
    fileprivate var tmdbURL: URL? {
        guard let tmdbID else { return nil }
        return URL(string: "https://www.themoviedb.org/movie/\(tmdbID)")
    }
}
