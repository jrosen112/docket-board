//
//  ItemPresentation.swift
//  Docket
//
//  Presentation-only formatting for board cards and quick looks. Lives in the
//  UI layer on purpose — model files stay free of display concerns.
//

import Foundation

nonisolated struct ItemQuickLookFact: Identifiable, Equatable {
    let id: String
    let label: String
    let value: String
    let prefersFullWidth: Bool
}

nonisolated struct BoardCardCue: Identifiable, Equatable {
    let id: String
    let symbol: String
    let label: String
}

/// Compact, individually scannable facts for the board card. Keeping these
/// structured prevents unrelated metadata from reading like one flat sentence.
nonisolated func boardCardCues(for item: any SharedListItem) -> [BoardCardCue] {
    switch item {
    case let restaurant as Restaurant:
        return [
            cue("cuisine", "fork.knife", cuisineSummary(restaurant.cuisines, limit: nil)),
            cue("price", "dollarsign.circle", restaurant.priceRange?.rawValue),
            cue("location", "mappin.and.ellipse", restaurant.location?.boardLabel),
        ].compactMap(\.self)
    case let bar as Bar:
        return [
            cue("vibe", "wineglass", bar.barType?.rawValue.capitalized),
            cue("location", "mappin.and.ellipse", bar.location?.boardLabel),
        ].compactMap(\.self)
    case let movie as Movie:
        return [
            cue("year", "calendar", movie.releaseYear.map(String.init)),
            cue("runtime", "clock", movie.runtimeMinutes.flatMap(runtimeSummary)),
            cue("service", "play.rectangle.fill", movie.streamingService),
        ].compactMap(\.self)
    case let recipe as Recipe:
        return [
            cue("cuisine", "fork.knife", cuisineSummary(recipe.cuisines, limit: nil)),
            cue("source", "book.closed", recipeSourceName(recipe)),
            cue(
                "ingredients",
                "list.bullet",
                recipe.ingredients.isEmpty ? nil : "\(recipe.ingredients.count) ingredients"
            ),
            cue(
                "steps",
                "list.number",
                recipe.instructions.isEmpty ? nil : "\(recipe.instructions.count) steps"
            ),
        ].compactMap(\.self)
    default:
        return []
    }
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
        boardCardCues(for: item).map(\.label).joined(separator: " "),
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
            fact("cuisine", "Cuisines", cuisineSummary(restaurant.cuisines, limit: nil)),
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
            fact("runtime", "Runtime", movie.runtimeMinutes.flatMap(runtimeSummary)),
            fact("service", "Watch on", movie.streamingService),
        ].compactMap(\.self)
    case let recipe as Recipe:
        return [
            fact("cuisine", "Cuisines", cuisineSummary(recipe.cuisines, limit: nil)),
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

private nonisolated func cuisineSummary(_ cuisines: [String], limit: Int? = 2) -> String? {
    guard !cuisines.isEmpty else { return nil }
    let shown = limit.map { Array(cuisines.prefix($0)) } ?? cuisines
    let remaining = cuisines.count - shown.count
    return shown.joined(separator: ", ") + (remaining > 0 ? " +\(remaining)" : "")
}

private nonisolated func recipeSourceName(_ recipe: Recipe) -> String? {
    guard let host = recipe.sourceLink?.host?.lowercased() else { return nil }
    let domain = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host

    return switch domain {
    case "cooking.nytimes.com": "NYT Cooking"
    case "tiktok.com", "m.tiktok.com": "TikTok"
    case "instagram.com": "Instagram"
    case "youtube.com", "m.youtube.com", "youtu.be": "YouTube"
    default: domain
    }
}

private nonisolated func runtimeSummary(_ minutes: Int) -> String? {
    guard minutes > 0 else { return nil }
    let hours = minutes / 60
    let remainingMinutes = minutes % 60
    if hours == 0 { return "\(remainingMinutes)m" }
    if remainingMinutes == 0 { return "\(hours)h" }
    return "\(hours)h \(remainingMinutes)m"
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

private nonisolated func cue(
    _ id: String,
    _ symbol: String,
    _ label: String?
) -> BoardCardCue? {
    guard let label = label?.orNil else { return nil }
    return BoardCardCue(id: id, symbol: symbol, label: label)
}
