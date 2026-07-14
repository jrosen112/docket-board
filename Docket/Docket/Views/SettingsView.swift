import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.docketSurfacePalette) private var palette
    @AppStorage(AppPreferences.darkerThemeKey) private var darkerThemeEnabled =
        AppPreferences.defaultDarkerThemeEnabled

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: $darkerThemeEnabled) {
                        Label {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Darker Theme")
                                    .foregroundStyle(palette.primaryText)
                                Text(darkerThemeEnabled ? "On" : "Off")
                                    .font(.caption)
                                    .foregroundStyle(palette.secondaryText)
                            }
                        } icon: {
                            Image(
                                systemName: darkerThemeEnabled
                                    ? "moon.stars.fill"
                                    : "circle.lefthalf.filled"
                            )
                                .foregroundStyle(DocketTheme.brass)
                        }
                    }
                    .tint(DocketTheme.brass)
                    .listRowBackground(palette.raisedPaper)
                } header: {
                    Text("Appearance")
                        .foregroundStyle(DocketTheme.cream.opacity(0.62))
                } footer: {
                    Text(
                        "Darkens cards and detail surfaces while keeping Docket's board palette."
                    )
                        .foregroundStyle(DocketTheme.cream.opacity(0.62))
                }
            }
            .scrollContentBackground(.hidden)
            .background(DocketTheme.boardBackground)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DocketTheme.ink, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
