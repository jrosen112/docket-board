import SwiftUI

struct MovieDetailView: View {
    let movie: Movie
    let addedBy: String

    var body: some View {
        DetailPage(item: movie, addedBy: addedBy, symbol: "film.fill") {
            if let year = movie.releaseYear {
                DetailFactRow(
                    symbol: "calendar",
                    label: "Released",
                    value: String(year),
                    accent: movie.category.accent
                )
            }
            if let runtime = movie.runtimeMinutes {
                DetailFactRow(
                    symbol: "clock.fill",
                    label: "Runtime",
                    value: "\(runtime) min",
                    accent: movie.category.accent
                )
            }
            if let service = movie.streamingService {
                DetailFactRow(
                    symbol: "play.tv.fill",
                    label: "Watch on",
                    value: service,
                    accent: movie.category.accent
                )
            }
            if movie.releaseYear == nil,
               movie.runtimeMinutes == nil,
               movie.streamingService == nil {
                DetailEmptyFacts()
            }
        }
    }
}
