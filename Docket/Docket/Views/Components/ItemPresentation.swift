//
//  ItemPresentation.swift
//  Docket
//
//  Presentation-only formatting for items (the category-specific subtitle line
//  on cards). Lives in the UI layer on purpose — model files stay free of
//  display concerns.
//

import Foundation

nonisolated struct ItemQuickLookFact: Identifiable, Equatable {
    let id: String
    let label: String
    let value: String
    let prefersFullWidth: Bool
}

/// One-line category-specific summary, e.g. "Thai · $$ · Mission" for a
/// restaurant or "2023 · 105 min · Showtime" for a movie.
nonisolated func cardSubtitle(for item: any SharedListItem) -> String? {
    let parts: [String?]
    switch item {
    case let restaurant as Restaurant:
        parts = [
            restaurant.cuisine,
            restaurant.priceRange?.rawValue,
            restaurant.location?.boardLabel,
        ]
    case let bar as Bar:
        parts = [bar.barType.map { $0.rawValue.capitalized }, bar.location?.boardLabel]
    case let movie as Movie:
        parts = [
            movie.releaseYear.map(String.init),
            movie.runtimeMinutes.map { "\($0) min" },
            movie.streamingService,
        ]
    case let recipe as Recipe:
        parts = [
            recipe.ingredients.isEmpty ? nil : "\(recipe.ingredients.count) ingredients",
            recipe.instructions.isEmpty ? nil : "\(recipe.instructions.count) steps",
        ]
    default:
        parts = []
    }
    let joined = parts.compactMap(\.self).joined(separator: " · ")
    return joined.isEmpty ? nil : joined
}

/// Matches every word in a board query across the content visible on a card
/// plus its notes, category, and status. Empty/whitespace-only queries match
/// everything so search composes cleanly with the board's structured filters.
nonisolated func itemMatchesBoardSearch(
    _ item: any SharedListItem,
    query: String
) -> Bool {
    let terms = query.split(whereSeparator: \Character.isWhitespace).map(String.init)
    guard !terms.isEmpty else { return true }

    let recipeText: String? =
        if let recipe = item as? Recipe {
            ([recipe.sourceURL] + recipe.ingredients + recipe.instructions)
                .compactMap(\.self)
                .joined(separator: " ")
        } else {
            nil
        }

    let searchableText = [
        item.title,
        item.notes,
        item.category.label,
        item.status.label(for: item.category),
        cardSubtitle(for: item),
        recipeText,
    ]
    .compactMap(\.self)
    .joined(separator: " ")

    return terms.allSatisfy(searchableText.localizedStandardContains)
}

/// Labeled category-specific facts for the long-press quick look. Empty fields
/// are omitted so the preview stays useful rather than showing placeholders.
nonisolated func quickLookFacts(for item: any SharedListItem) -> [ItemQuickLookFact] {
    switch item {
    case let restaurant as Restaurant:
        return [
            fact(
                "location",
                "Location",
                restaurant.location?.detailAddress,
                prefersFullWidth: true
            ),
            fact("cuisine", "Cuisine", restaurant.cuisine),
            fact("price", "Price", restaurant.priceRange?.rawValue),
        ].compactMap(\.self)
    case let bar as Bar:
        return [
            fact("location", "Location", bar.location?.detailAddress, prefersFullWidth: true),
            fact("vibe", "Vibe", bar.barType?.rawValue.capitalized),
        ].compactMap(\.self)
    case let movie as Movie:
        return [
            fact("released", "Released", movie.releaseYear.map(String.init)),
            fact("runtime", "Runtime", movie.runtimeMinutes.map { "\($0) min" }),
            fact("service", "Watch on", movie.streamingService),
        ].compactMap(\.self)
    case let recipe as Recipe:
        return [
            fact("source", "Source", recipe.sourceURL, prefersFullWidth: true),
            fact(
                "ingredients",
                "Shopping list",
                recipe.ingredients.isEmpty ? nil : "\(recipe.ingredients.count) ingredients"
            ),
            fact(
                "instructions",
                "Method",
                recipe.instructions.isEmpty ? nil : "\(recipe.instructions.count) steps"
            ),
        ].compactMap(\.self)
    default:
        return []
    }
}

nonisolated extension ItemCategory {
    var symbol: String {
        switch self {
        case .restaurant: "fork.knife"
        case .bar: "wineglass.fill"
        case .recipe: "book.pages.fill"
        case .movie: "film.fill"
        case .happyHour: "clock.badge.checkmark"
        case .landmark: "building.columns.fill"
        case .hike: "figure.hiking"
        case .activity: "ticket.fill"
        }
    }
}

private nonisolated func fact(
    _ id: String,
    _ label: String,
    _ value: String?,
    prefersFullWidth: Bool = false
) -> ItemQuickLookFact? {
    guard let value = value?.orNil else { return nil }
    return ItemQuickLookFact(
        id: id,
        label: label,
        value: value,
        prefersFullWidth: prefersFullWidth
    )
}
