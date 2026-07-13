import SwiftUI

struct BarDetailView: View {
    let bar: Bar
    let addedBy: String

    var body: some View {
        Form {
            Section("Docket") {
                LabeledContent("Status", value: bar.status.label)
                LabeledContent("Added by", value: addedBy)
            }
            Section("Bar") {
                if let location = bar.location {
                    LabeledContent("Location", value: location)
                }
                if let type = bar.barType {
                    LabeledContent("Type", value: type.rawValue.capitalized)
                }
            }
            if let notes = bar.notes {
                Section("Notes") { Text(notes) }
            }
        }
    }
}
