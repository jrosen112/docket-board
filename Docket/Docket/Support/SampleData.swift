//
//  SampleData.swift
//  Docket
//
//  DEBUG-only seed data for on-device UI iteration, so the board doesn't have
//  to be repopulated by hand after every change. Every seeded record's name
//  carries a "sample-" prefix, so "Delete sample data" can remove exactly the
//  seeds and never touch real items. Compiled out of Release/TestFlight builds.
//

#if DEBUG
import CloudKit

nonisolated enum SampleData {

    private static let recordNamePrefix = "sample-"

    static func isSample(_ id: CKRecord.ID) -> Bool {
        id.recordName.hasPrefix(recordNamePrefix)
    }

    /// A varied board: three categories, every status, mixed note lengths
    /// (masonry needs height variance), staggered dates so sort order shows.
    static func items(addedBy: CKRecord.Reference, in zoneID: CKRecordZone.ID) -> [any SharedListItem] {
        func id() -> CKRecord.ID {
            CKRecord.ID(recordName: recordNamePrefix + UUID().uuidString, zoneID: zoneID)
        }
        func daysAgo(_ days: Double) -> Date {
            Date(timeIntervalSinceNow: -days * 86_400)
        }
        func location(
            _ name: String,
            _ address: String,
            _ shortAddress: String,
            latitude: Double,
            longitude: Double
        ) -> ItemLocation {
            ItemLocation(
                name: name,
                fullAddress: address,
                shortAddress: shortAddress,
                city: "San Francisco",
                cityWithContext: "San Francisco, CA",
                country: "United States",
                countryCode: "US",
                latitude: latitude,
                longitude: longitude
            )
        }

        return [
            Restaurant(
                id: id(), title: "Zuni Café",
                notes: "Get the roast chicken for two — takes an hour, order it the second we sit down.",
                status: .planned, addedBy: addedBy, dateAdded: daysAgo(0.2),
                location: location(
                    "Zuni Café", "1658 Market St, San Francisco, CA 94102, United States",
                    "1658 Market St", latitude: 37.7736, longitude: -122.4216
                ),
                showsMapOnBoard: true,
                cuisine: "Californian", priceRange: .pricey
            ),
            Restaurant(
                id: id(), title: "Souvla",
                status: .wantToGo, addedBy: addedBy, dateAdded: daysAgo(1),
                location: location(
                    "Souvla", "517 Hayes St, San Francisco, CA 94102, United States",
                    "517 Hayes St", latitude: 37.7764, longitude: -122.4257
                ),
                cuisine: "Greek", priceRange: .inexpensive
            ),
            Restaurant(
                id: id(), title: "House of Prime Rib",
                notes: "Anniversary dinner. Worth it.",
                status: .completed, addedBy: addedBy, dateAdded: daysAgo(12),
                location: location(
                    "House of Prime Rib", "1906 Van Ness Ave, San Francisco, CA 94109, United States",
                    "1906 Van Ness Ave", latitude: 37.7935, longitude: -122.4226
                ),
                cuisine: "Steakhouse", priceRange: .splurge
            ),
            Bar(
                id: id(), title: "Trick Dog",
                notes: "Menu changes theme every six months.",
                status: .wantToGo, addedBy: addedBy, dateAdded: daysAgo(0.5),
                location: location(
                    "Trick Dog", "3010 20th St, San Francisco, CA 94110, United States",
                    "3010 20th St", latitude: 37.7590, longitude: -122.4115
                ),
                showsMapOnBoard: true,
                barType: .cocktail
            ),
            Bar(
                id: id(), title: "Zeitgeist",
                notes: "Cash only. Huge patio, get there before 5 on weekends or forget about a table.",
                status: .planned, addedBy: addedBy, dateAdded: daysAgo(3),
                location: location(
                    "Zeitgeist", "199 Valencia St, San Francisco, CA 94103, United States",
                    "199 Valencia St", latitude: 37.7700, longitude: -122.4221
                ),
                barType: .dive
            ),
            Bar(
                id: id(), title: "Charmaine's",
                status: .wantToGo, addedBy: addedBy, dateAdded: daysAgo(6),
                location: location(
                    "Charmaine's", "1100 Market St, San Francisco, CA 94102, United States",
                    "1100 Market St", latitude: 37.7800, longitude: -122.4124
                ),
                barType: .rooftop
            ),
            Movie(
                id: id(), title: "Past Lives",
                status: .wantToGo, addedBy: addedBy, dateAdded: daysAgo(0.1),
                runtimeMinutes: 105, streamingService: "Paramount+", releaseYear: 2023
            ),
            Movie(
                id: id(), title: "Heat",
                notes: "You've somehow never seen this and that's a problem.",
                status: .planned, addedBy: addedBy, dateAdded: daysAgo(2),
                runtimeMinutes: 170, streamingService: "Max", releaseYear: 1995
            ),
            Movie(
                id: id(), title: "Chungking Express",
                status: .completed, addedBy: addedBy, dateAdded: daysAgo(20),
                runtimeMinutes: 102, streamingService: "Criterion", releaseYear: 1994
            ),
        ]
    }
}
#endif
