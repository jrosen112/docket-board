import MapKit
import SwiftUI

struct LocationEditRow: View {
    @Environment(\.docketSurfacePalette) private var palette

    let suggestedQuery: String
    let accent: Color
    @Binding var location: ItemLocation?
    @Binding var showsMapOnBoard: Bool
    @Binding var showsPhotoOnBoard: Bool

    @State private var isSearching = false

    var body: some View {
        HStack(spacing: DocketDetailTheme.Fact.rowSpacing) {
            Image(systemName: "mappin.and.ellipse")
                .font(DocketDetailTheme.Fact.symbolFont)
                .foregroundStyle(accent)
                .frame(width: DocketDetailTheme.Fact.symbolWidth)

            Button {
                isSearching = true
            } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: DocketDetailTheme.Edit.fieldSpacing) {
                        Text("Location")
                            .font(DocketDetailTheme.Edit.labelFont)
                            .foregroundStyle(palette.mutedText)

                        if let location {
                            Text(location.streetAddress)
                                .font(DocketDetailTheme.Edit.inputFont)
                                .foregroundStyle(palette.primaryText)
                                .lineLimit(2)
                        } else {
                            Text("Search places and addresses")
                                .font(DocketDetailTheme.Edit.inputFont)
                                .foregroundStyle(palette.mutedText)
                        }
                    }

                    Spacer(minLength: 8)
                    Image(systemName: "magnifyingglass")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(accent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if location != nil {
                Button(role: .destructive) {
                    withAnimation(DocketDetailTheme.Edit.modeAnimation) {
                        location = nil
                        showsMapOnBoard = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(palette.mutedText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove location")
            }
        }
        .padding(.vertical, DocketDetailTheme.Edit.fieldVerticalPadding)
        .id(ItemDraftField.location)
        .sheet(isPresented: $isSearching) {
            LocationSearchView(
                initialQuery: location?.name ?? suggestedQuery,
                selectedLocation: location
            ) { selected in
                let isFirstLocation = location == nil
                location = selected
                if isFirstLocation && !showsPhotoOnBoard {
                    showsMapOnBoard = true
                }
                isSearching = false
            }
        }
    }
}

private struct LocationSearchView: View {
    @Environment(\.dismiss) private var dismiss

    let selectedLocation: ItemLocation?
    let onSelect: (ItemLocation) -> Void

    @State private var query: String
    @State private var results: [ItemLocation] = []
    @State private var isSearching = false
    @State private var errorMessage: String?

    init(
        initialQuery: String,
        selectedLocation: ItemLocation?,
        onSelect: @escaping (ItemLocation) -> Void
    ) {
        self.selectedLocation = selectedLocation
        self.onSelect = onSelect
        _query = State(initialValue: initialQuery)
    }

    var body: some View {
        NavigationStack {
            Group {
                if query.trimmed.count < 2 {
                    ContentUnavailableView(
                        "Find a place",
                        systemImage: "map",
                        description: Text("Search by place name or street address.")
                    )
                } else if isSearching && results.isEmpty {
                    ProgressView("Searching Maps…")
                } else if let errorMessage, results.isEmpty {
                    ContentUnavailableView(
                        "Search unavailable",
                        systemImage: "wifi.exclamationmark",
                        description: Text(errorMessage)
                    )
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    List(results, id: \.stableID) { location in
                        Button {
                            onSelect(location)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(DocketTheme.brass)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(location.name)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text(location.fullAddress)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }

                                Spacer(minLength: 8)
                                if location == selectedLocation {
                                    Image(systemName: "checkmark")
                                        .font(.body.weight(.bold))
                                        .foregroundStyle(DocketTheme.brass)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Choose Location")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Place or address"
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .task(id: query) {
            await search()
        }
    }

    @MainActor
    private func search() async {
        let term = query.trimmed
        guard term.count >= 2 else {
            results = []
            errorMessage = nil
            isSearching = false
            return
        }

        do {
            try await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            isSearching = true
            errorMessage = nil
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = term
            let response = try await MKLocalSearch(request: request).start()
            guard !Task.isCancelled else { return }
            results = response.mapItems.compactMap(ItemLocation.init(mapItem:))
            isSearching = false
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            results = []
            errorMessage = "Check your connection and try again."
            isSearching = false
        }
    }
}

private extension ItemLocation {
    var stableID: String {
        mapItemIdentifier ?? "\(latitude),\(longitude),\(name)"
    }

    init?(mapItem: MKMapItem) {
        let representations = mapItem.addressRepresentations
        let fullAddress = representations?
            .fullAddress(includingRegion: true, singleLine: true)
            ?? mapItem.address?.fullAddress
        guard let fullAddress = fullAddress?.orNil else { return nil }

        let name = mapItem.name?.orNil
            ?? mapItem.address?.shortAddress?.orNil
            ?? fullAddress
        let coordinate = mapItem.location.coordinate
        self.init(
            name: name,
            fullAddress: fullAddress,
            shortAddress: mapItem.address?.shortAddress?.orNil,
            city: representations?.cityName?.orNil,
            cityWithContext: representations?.cityWithContext?.orNil,
            country: representations?.regionName?.orNil,
            countryCode: representations?.__regionCode?.orNil,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            mapItemIdentifier: mapItem.identifier?.rawValue
        )
    }
}
