import CoreLocation
import MapKit
import SwiftUI

/// The interactive map shown between a place's hero card and particulars.
/// It starts close enough to make nearby streets legible, supports pan/zoom,
/// and hands the saved place off to Apple Maps when requested.
struct LocationDetailMapView: View {
    let location: ItemLocation

    @State private var position: MapCameraPosition

    init(location: ItemLocation) {
        self.location = location
        _position = State(
            initialValue: .region(
                MKCoordinateRegion(
                    center: location.coordinate,
                    latitudinalMeters: 700,
                    longitudinalMeters: 700
                )
            )
        )
    }

    var body: some View {
        Map(position: $position, interactionModes: [.pan, .zoom]) {
            Marker(location.name, coordinate: location.coordinate)
                .tint(DocketTheme.brass)
        }
        .overlay(alignment: .topTrailing) {
            Button(action: recenter) {
                Image(systemName: "location.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(DocketTheme.ink)
                    .frame(width: 38, height: 38)
                    .background(DocketTheme.cream.opacity(0.94), in: Circle())
                    .shadow(color: .black.opacity(0.22), radius: 3, y: 2)
            }
            .buttonStyle(.plain)
            .padding(10)
            .accessibilityLabel("Re-center map on saved location")
        }
        .overlay(alignment: .bottomTrailing) {
            Button(action: openInMaps) {
                Label("Open in Maps", systemImage: "arrow.up.right.square.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DocketTheme.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(DocketTheme.cream.opacity(0.94), in: Capsule())
                    .shadow(color: .black.opacity(0.22), radius: 3, y: 2)
            }
            .buttonStyle(.plain)
            .padding(10)
        }
        .accessibilityLabel("Map of \(location.fullAddress)")
    }

    private func recenter() {
        withAnimation(.easeInOut(duration: 0.25)) {
            position = .region(
                MKCoordinateRegion(
                    center: location.coordinate,
                    latitudinalMeters: 700,
                    longitudinalMeters: 700
                )
            )
        }
    }

    private func openInMaps() {
        let mapItem = MKMapItem(
            location: CLLocation(
                latitude: location.latitude,
                longitude: location.longitude
            ),
            address: MKAddress(
                fullAddress: location.fullAddress,
                shortAddress: location.shortAddress
            )
        )
        mapItem.name = location.name
        mapItem.openInMaps()
    }
}
