import MapKit
import SwiftUI
import UIKit

/// A non-interactive map image centered on a saved place. Snapshots are
/// generated locally from coordinates and cached for the life of the app.
struct LocationMapSnapshotView: View {
    let location: ItemLocation

    @State private var image: UIImage?
    @State private var didFinishLoading = false

    private var cacheKey: String {
        "\(location.latitude),\(location.longitude)"
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(uiColor: .secondarySystemBackground),
                    Color(uiColor: .tertiarySystemBackground),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if didFinishLoading {
                Image(systemName: "map.fill")
                    .font(.system(size: 58))
                    .foregroundStyle(Color.secondary.opacity(0.18))
            } else {
                ProgressView()
                    .tint(DocketTheme.brass)
            }

            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 31, weight: .bold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(DocketTheme.brass, Color.white)
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                .accessibilityHidden(true)
        }
        .clipped()
        .task(id: cacheKey) {
            didFinishLoading = false
            image = await LocationMapSnapshotCache.image(for: location)
            didFinishLoading = true
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Map of \(location.name)")
    }
}

@MainActor
private enum LocationMapSnapshotCache {
    private static let images = NSCache<NSString, UIImage>()

    static func image(for location: ItemLocation) async -> UIImage? {
        let key = "\(location.latitude),\(location.longitude)" as NSString
        if let cached = images.object(forKey: key) { return cached }

        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: 550,
            longitudinalMeters: 550
        )
        options.size = CGSize(width: 520, height: 280)
        options.traitCollection = UITraitCollection(mutations: { traits in
            traits.userInterfaceStyle = .light
            traits.displayScale = 2
        })
        let configuration = MKStandardMapConfiguration(
            elevationStyle: .flat,
            emphasisStyle: .muted
        )
        configuration.pointOfInterestFilter = .excludingAll
        options.preferredConfiguration = configuration

        let snapshotter = MKMapSnapshotter(options: options)
        let generated = await withCheckedContinuation { continuation in
            snapshotter.start { snapshot, _ in
                continuation.resume(returning: snapshot?.image)
            }
        }
        if let generated { images.setObject(generated, forKey: key) }
        return generated
    }
}
