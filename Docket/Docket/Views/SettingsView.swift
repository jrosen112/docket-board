import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.docketSurfacePalette) private var palette
    @Environment(BoardStore.self) private var store
    @AppStorage(AppPreferences.darkerThemeKey) private var darkerThemeEnabled =
        AppPreferences.defaultDarkerThemeEnabled

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        ProfileSettingsView()
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(store.currentProfile?.displayName ?? "Your Profile")
                                    .foregroundStyle(palette.primaryText)
                                Text("Profile, name, and stats")
                                    .font(.caption)
                                    .foregroundStyle(palette.secondaryText)
                            }
                        } icon: {
                            Image(systemName: "person.crop.circle.fill")
                                .foregroundStyle(DocketTheme.brass)
                        }
                    }
                    .listRowBackground(palette.raisedPaper)
                } header: {
                    Text("You")
                        .foregroundStyle(DocketTheme.cream.opacity(0.62))
                }

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

                Section {
                    Link(destination: URL(string: "https://www.themoviedb.org")!) {
                        HStack(spacing: 16) {
                            Image("TMDBLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 76, height: 34)

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Movie data & images")
                                    .foregroundStyle(palette.primaryText)
                                Text("Visit The Movie Database")
                                    .font(.caption)
                                    .foregroundStyle(palette.secondaryText)
                            }

                            Spacer()

                            Image(systemName: "arrow.up.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(DocketTheme.brass)
                        }
                    }
                    .listRowBackground(palette.raisedPaper)
                } header: {
                    Text("Credits")
                        .foregroundStyle(DocketTheme.cream.opacity(0.62))
                } footer: {
                    Text("This product uses the TMDB API but is not endorsed or certified by TMDB.")
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
