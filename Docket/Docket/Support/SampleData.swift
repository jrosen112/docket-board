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
                    cuisines: ["Californian", "French"], priceRange: .pricey
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
                Recipe(
                    id: id(), title: "Crispy Gochujang Chicken",
                    notes: "Double the sauce and save some for rice bowls.",
                    status: .planned, addedBy: addedBy, dateAdded: daysAgo(0.8),
                    cuisines: ["Korean", "American"],
                    ingredients: [
                        "1½ lb boneless chicken thighs",
                        "3 tbsp gochujang",
                        "2 tbsp soy sauce",
                        "1 tbsp honey",
                        "1 tbsp rice vinegar",
                        "1 tsp toasted sesame oil",
                        "1 garlic clove, finely grated",
                        "Scallions and sesame seeds",
                    ],
                    instructions: [
                        "Heat the oven to 425°F. Whisk the gochujang, soy sauce, honey, vinegar, sesame oil, and garlic.",
                        "Coat the chicken with most of the sauce and arrange it on a foil-lined sheet pan.",
                        "Roast for 20–25 minutes, brushing with the remaining sauce halfway through, then broil briefly for charred edges.",
                        "Rest for 5 minutes, slice, and finish with scallions and sesame seeds.",
                    ]
                ),
                Recipe(
                    id: id(), title: "Miso-Maple Salmon Rice Bowls",
                    notes: "Good with leftover rice; crisp it in a skillet while the salmon cooks.",
                    status: .wantToGo, addedBy: addedBy, dateAdded: daysAgo(1.4),
                    cuisines: ["Japanese"],
                    ingredients: [
                        "2 skin-on salmon fillets, about 6 oz each",
                        "1 tbsp white miso",
                        "1 tbsp maple syrup",
                        "2 tsp soy sauce",
                        "1 tbsp rice vinegar, divided",
                        "2 cups cooked short-grain rice",
                        "1 Persian cucumber, thinly sliced",
                        "1 avocado, sliced",
                        "Scallions and sesame seeds",
                    ],
                    instructions: [
                        "Heat the oven to 425°F. Stir together the miso, maple syrup, soy sauce, and 2 teaspoons of the rice vinegar.",
                        "Brush the salmon with the glaze and roast for 8–12 minutes, until it flakes at the edges and is still moist in the center.",
                        "Toss the cucumber with the remaining vinegar and a pinch of salt.",
                        "Divide the rice between bowls and add the salmon, cucumber, avocado, scallions, and sesame seeds.",
                    ]
                ),
                Recipe(
                    id: id(), title: "Skillet Butter Beans with Lemon and Kale",
                    notes: "Serve with toasted sourdough to catch the broth.",
                    status: .completed, addedBy: addedBy, dateAdded: daysAgo(8),
                    cuisines: ["Mediterranean", "Vegetarian"],
                    ingredients: [
                        "2 cans butter beans, drained, rinsed, and dried",
                        "3 tbsp olive oil",
                        "3 garlic cloves, thinly sliced",
                        "½ tsp red pepper flakes",
                        "1 bunch lacinato kale, stems removed and leaves torn",
                        "½ cup vegetable or chicken stock",
                        "1 lemon",
                        "¼ cup finely grated Parmesan",
                    ],
                    instructions: [
                        "Heat 2 tablespoons of the olive oil in a wide skillet over medium-high heat. Add the beans and cook undisturbed until browned, then toss and crisp the other side.",
                        "Transfer half the beans to a plate. Lower the heat, add the remaining oil, garlic, and red pepper flakes, and cook for 30 seconds.",
                        "Add the kale, stock, and a pinch of salt. Cover and cook until the kale is tender, about 4 minutes.",
                        "Return the reserved beans to the skillet. Finish with the zest and juice of half the lemon, Parmesan, black pepper, and more lemon to taste.",
                    ]
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
