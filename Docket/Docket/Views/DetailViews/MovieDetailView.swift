import SwiftUI

struct MovieDetailView: View {
    let movie: Movie
    let addedBy: String

    var body: some View {
        Form {
            Section("Docket") {
                LabeledContent("Status", value: movie.status.label)
                LabeledContent("Added by", value: addedBy)
            }
            Section("Movie") {
                if let year = movie.releaseYear {
                    LabeledContent("Release year", value: String(year))
                }
                if let runtime = movie.runtimeMinutes {
                    LabeledContent("Runtime", value: "\(runtime) min")
                }
                if let service = movie.streamingService {
                    LabeledContent("Streaming", value: service)
                }
            }
            if let notes = movie.notes {
                Section("Notes") { Text(notes) }
            }
        }
    }
}
