//
//  ItemPresentation.swift
//  Docket
//
//  Presentation-only formatting for items (the category-specific subtitle line
//  on cards). Lives in the UI layer on purpose — model files stay free of
//  display concerns.
//

import Foundation

/// One-line category-specific summary, e.g. "Thai · $$ · Mission" for a
/// restaurant or "2023 · 105 min · Showtime" for a movie.
nonisolated func cardSubtitle(for item: any SharedListItem) -> String? {
    let parts: [String?]
    switch item {
    case let restaurant as Restaurant:
        parts = [restaurant.cuisine, restaurant.priceRange?.rawValue, restaurant.location]
    case let bar as Bar:
        parts = [bar.barType.map { $0.rawValue.capitalized }, bar.location]
    case let movie as Movie:
        parts = [
            movie.releaseYear.map(String.init),
            movie.runtimeMinutes.map { "\($0) min" },
            movie.streamingService,
        ]
    default:
        parts = []
    }
    let joined = parts.compactMap(\.self).joined(separator: " · ")
    return joined.isEmpty ? nil : joined
}
