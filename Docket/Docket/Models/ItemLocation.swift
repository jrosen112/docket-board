import CloudKit
import CoreLocation

/// A MapKit-backed place selected by the user. The formatted address is kept
/// alongside coordinates so board content remains useful without another
/// lookup, while the map item ID lets us reconnect to Apple's place data.
nonisolated struct ItemLocation: Equatable, Hashable, Sendable {
    let name: String
    let fullAddress: String
    let shortAddress: String?
    let city: String?
    let cityWithContext: String?
    let country: String?
    let countryCode: String?
    let latitude: Double
    let longitude: Double
    let mapItemIdentifier: String?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// The compact location text used on board cards.
    var boardLabel: String {
        cityWithContext ?? shortAddress ?? fullAddress
    }

    /// The street line shown while editing. MapKit's `shortAddress` can be a
    /// city-level label, so prefer the first component of the full address.
    var streetAddress: String {
        addressComponents.first ?? shortAddress ?? fullAddress
    }

    /// The contextual address shown in details and quick look. US addresses
    /// omit the redundant country; international addresses always retain it.
    var detailAddress: String {
        var components = addressComponents
        guard !components.isEmpty else { return fullAddress }

        if isUnitedStates {
            let unitedStatesLabels = ["united states", "united states of america", "usa", "us"]
            if let last = components.last,
               unitedStatesLabels.contains(last.lowercased()) {
                components.removeLast()
            }
        } else if let country = country?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !country.isEmpty,
                  !components.contains(where: { $0.caseInsensitiveCompare(country) == .orderedSame }) {
            components.append(country)
        }

        return components.joined(separator: ", ")
    }

    private var addressComponents: [String] {
        fullAddress
            .components(separatedBy: .newlines)
            .flatMap { $0.split(separator: ",") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var isUnitedStates: Bool {
        if countryCode?.caseInsensitiveCompare("US") == .orderedSame { return true }
        guard let country else { return false }
        return ["united states", "united states of america", "usa", "us"]
            .contains(country.lowercased())
    }

    init(
        name: String,
        fullAddress: String,
        shortAddress: String? = nil,
        city: String? = nil,
        cityWithContext: String? = nil,
        country: String? = nil,
        countryCode: String? = nil,
        latitude: Double,
        longitude: Double,
        mapItemIdentifier: String? = nil
    ) {
        self.name = name
        self.fullAddress = fullAddress
        self.shortAddress = shortAddress
        self.city = city
        self.cityWithContext = cityWithContext
        self.country = country
        self.countryCode = countryCode
        self.latitude = latitude
        self.longitude = longitude
        self.mapItemIdentifier = mapItemIdentifier
    }

    init?(record: CKRecord) {
        guard
            let name = record[Schema.Field.locationName] as? String,
            let fullAddress = record[Schema.Field.locationFullAddress] as? String,
            let coordinate = record[Schema.Field.locationCoordinate] as? CLLocation
        else { return nil }

        self.init(
            name: name,
            fullAddress: fullAddress,
            shortAddress: record[Schema.Field.locationShortAddress] as? String,
            city: record[Schema.Field.locationCity] as? String,
            cityWithContext: record[Schema.Field.locationCityWithContext] as? String,
            country: record[Schema.Field.locationCountry] as? String,
            countryCode: record[Schema.Field.locationCountryCode] as? String,
            latitude: coordinate.coordinate.latitude,
            longitude: coordinate.coordinate.longitude,
            mapItemIdentifier: record[Schema.Field.locationMapItemIdentifier] as? String
        )
    }
}

nonisolated protocol LocatedListItem: SharedListItem {
    var location: ItemLocation? { get set }
    var showsMapOnBoard: Bool { get set }
}

extension CKRecord {
    nonisolated func applyLocationFields(
        location: ItemLocation?,
        showsMapOnBoard: Bool
    ) {
        self[Schema.Field.locationName] = location?.name
        self[Schema.Field.locationFullAddress] = location?.fullAddress
        self[Schema.Field.locationShortAddress] = location?.shortAddress
        self[Schema.Field.locationCity] = location?.city
        self[Schema.Field.locationCityWithContext] = location?.cityWithContext
        self[Schema.Field.locationCountry] = location?.country
        self[Schema.Field.locationCountryCode] = location?.countryCode
        self[Schema.Field.locationMapItemIdentifier] = location?.mapItemIdentifier
        self[Schema.Field.locationCoordinate] = location.map {
            CLLocation(latitude: $0.latitude, longitude: $0.longitude)
        }
        self[Schema.Field.showsMapOnBoard] = location != nil && showsMapOnBoard
    }
}
