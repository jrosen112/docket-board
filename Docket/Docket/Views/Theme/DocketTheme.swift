//
//  DocketTheme.swift
//  Docket
//
//  The single source of design tokens: palette, typography, category/status
//  colors, and the card-rotation function. Components read from here and ONLY
//  here — restyling the app should mean editing this file, not hunting through
//  views.
//

import SwiftUI

nonisolated extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

nonisolated enum DocketTheme {

    // MARK: Palette (from CLAUDE.md design direction)

    /// Ink-navy board background.
    static let ink = Color(hex: 0x14181F)
    /// Slightly lifted navy for the top of the board gradient.
    static let inkLight = Color(hex: 0x1C222C)
    /// Warm cream card stock.
    static let cream = Color(hex: 0xEFE6D3)
    /// Brass/gold primary accent.
    static let brass = Color(hex: 0xD9A441)

    /// The board surface: navy with a subtle top-light vignette.
    static var boardBackground: some ShapeStyle {
        RadialGradient(
            colors: [inkLight, ink],
            center: .top,
            startRadius: 0,
            endRadius: 700
        )
    }

    // MARK: Typography (serif display per design direction)

    static func display(_ size: CGFloat) -> Font { .custom("Georgia-Bold", size: size) }
    static func displayRegular(_ size: CGFloat) -> Font { .custom("Georgia", size: size) }

    // MARK: Card rotation

    /// Deterministic per-card tilt in the range -1.5°…+1.5°, keyed by record
    /// name so a card keeps its tilt across refreshes and launches. (Do NOT use
    /// hashValue here — it's randomized per process.)
    static func rotationDegrees(for key: String) -> Double {
        var hash = 5381
        for scalar in key.unicodeScalars {
            hash = (hash &* 33) &+ Int(scalar.value)
        }
        let bounded = (hash & 0x7FFF_FFFF) % 300
        return Double(bounded) / 100.0 - 1.5
    }
}

// MARK: Category + status colors (presentation only — models stay color-free)

nonisolated extension ItemCategory {
    /// Color-coded accent per category, tuned to sit on cream card stock.
    var accent: Color {
        switch self {
        case .restaurant: Color(hex: 0xC96F4A) // terracotta
        case .bar: Color(hex: 0x9B6A8F)        // dusty plum
        case .happyHour: Color(hex: 0xC08A2E)  // amber
        case .landmark: Color(hex: 0x6B8CAE)   // slate blue
        case .movie: Color(hex: 0xB85C5C)      // muted red
        case .hike: Color(hex: 0x7C9A5C)       // moss green
        case .activity: Color(hex: 0x5F9EA0)   // teal
        }
    }
}

nonisolated extension ItemStatus {
    /// Chip color, dark enough to read on cream.
    var chipColor: Color {
        switch self {
        case .wantToGo: Color(hex: 0xA6762E)   // dark brass
        case .planned: Color(hex: 0x4A7B7C)    // teal
        case .completed: Color(hex: 0x6B7B4A)  // olive
        }
    }
}
