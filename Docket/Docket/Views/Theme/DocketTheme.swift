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

    // MARK: Board card header

    enum BoardCardHeader {
        static let categoryFont: Font = .caption2.weight(.bold)
        static let categoryTracking: CGFloat = 1.2
    }

    enum BoardCard {
        /// Transparent breathing room included in transition and context-menu
        /// snapshots so the tilted paper, shadow, and pin are not clipped.
        static let transitionCaptureInset: CGFloat = 10
        static let photoHeight: CGFloat = 104
        static let photoCornerRadius: CGFloat = 4
    }

    enum StatusBadge {
        static let horizontalPadding: CGFloat = 8
        static let verticalPadding: CGFloat = 3
        static let cardTopPadding: CGFloat = 2
        static let font: Font = .caption2.weight(.semibold)
    }

    enum BoardFilterHeader {
        static let contentPadding: CGFloat = 10
        static let verticalMargin: CGFloat = 8
        static let barSpacing: CGFloat = 10
        static let buttonSpacing: CGFloat = 6
        static let buttonHorizontalPadding: CGFloat = 12
        static let buttonVerticalPadding: CGFloat = 7
        static let minimumButtonSpacing: CGFloat = 12
        static let clearTracking: CGFloat = 1
        static let clearHorizontalPadding: CGFloat = 14
        static let clearVerticalPadding: CGFloat = 7
        static let disabledOpacity: Double = 0.28
        static let cornerRadius: CGFloat = 18
        static let borderWidth: CGFloat = 1
        static let shadowRadius: CGFloat = 5
        static let shadowY: CGFloat = 3
        static let glassTint = DocketTheme.inkLight.opacity(0.52)
        static let borderColor = DocketTheme.cream.opacity(0.08)
        static let shadowColor = Color.black.opacity(0.24)
        static let buttonFont: Font = .caption.weight(.semibold)
        static let clearFont: Font = .caption.weight(.bold)
    }

    enum FilterSheet {
        static let sectionSpacing: CGFloat = 26
        static let sectionHeaderSpacing: CGFloat = 12
        static let gridSpacing: CGFloat = 10
        static let gridMinimumWidth: CGFloat = 118
        static let pageHorizontalPadding: CGFloat = 18
        static let pageTopPadding: CGFloat = 20
        static let pageBottomPadding: CGFloat = 34
        static let tileSpacing: CGFloat = 8
        static let tileHorizontalPadding: CGFloat = 12
        static let tileVerticalPadding: CGFloat = 11
        static let tileCornerRadius: CGFloat = 12
        static let tileMinimumHeight: CGFloat = 44
        static let sectionTitleFont: Font = DocketTheme.display(20)
        static let selectionSummaryFont: Font = .caption
        static let tileFont: Font = .subheadline.weight(.semibold)
        static let sectionTitleColor = DocketTheme.cream
        static let selectionSummaryColor = DocketTheme.cream.opacity(0.58)
        static let unselectedFill = DocketTheme.cream.opacity(0.08)
        static let unselectedForeground = DocketTheme.cream.opacity(0.88)
        static let unselectedBorder = DocketTheme.cream.opacity(0.1)
    }

    enum BoardSwitcher {
        static let labelSpacing: CGFloat = 6
        static let titleFont: Font = DocketTheme.display(20)
        static let chevronFont: Font = .caption2.weight(.bold)
        static let titleColor = DocketTheme.cream
        static let chevronColor = DocketTheme.brass.opacity(0.8)
    }

    enum BoardSkeleton {
        static let cardCount = 10
        static let columns = 2
        static let cardSpacing: CGFloat = 14
        static let cardHeights: [CGFloat] = [174, 208, 192, 156, 220, 182]
        static let cardCornerRadius: CGFloat = 5
        static let cardPadding: CGFloat = 14
        static let contentSpacing: CGFloat = 10
        static let stripeWidth: CGFloat = 3
        static let stripeVerticalPadding: CGFloat = 12
        static let stripeLeadingPadding: CGFloat = 5
        static let pinSize: CGFloat = 11
        static let pinOffsetY: CGFloat = -5
        static let categoryLineHeight: CGFloat = 7
        static let titleLineHeight: CGFloat = 15
        static let detailLineHeight: CGFloat = 9
        static let statusWidth: CGFloat = 70
        static let statusHeight: CGFloat = 19
        static let authorLineHeight: CGFloat = 7
        static let categoryTrailingInset: CGFloat = 70
        static let titleTrailingInsets: [CGFloat] = [20, 42, 8, 56]
        static let detailTrailingInsets: [CGFloat] = [34, 12, 52]
        static let authorTrailingInset: CGFloat = 46
        static let cardFill = DocketTheme.cream.opacity(0.13)
        static let lineFill = DocketTheme.cream.opacity(0.19)
        static let stripeFill = DocketTheme.cream.opacity(0.2)
        static let pinFill = DocketTheme.brass.opacity(0.28)
        static let shimmerColor = DocketTheme.cream.opacity(0.3)
        static let shimmerWidth: CGFloat = 110
        static let shimmerAngle: Angle = .degrees(16)
        static let shimmerHeightMultiplier: CGFloat = 1.35
        static let shimmerVerticalOffsetMultiplier: CGFloat = -0.18
        static let shimmerDuration: TimeInterval = 1.35
        static let shimmerFrameInterval: TimeInterval = 1.0 / 30.0
        static let contentTransitionDuration: TimeInterval = 0.22

        static func cardHeight(for index: Int) -> CGFloat {
            cardHeights[index % cardHeights.count]
        }

        static func titleTrailingInset(for index: Int) -> CGFloat {
            titleTrailingInsets[index % titleTrailingInsets.count]
        }

        static func detailTrailingInset(for index: Int) -> CGFloat {
            detailTrailingInsets[index % detailTrailingInsets.count]
        }

        static func shimmerProgress(at date: Date) -> CGFloat {
            let elapsed = date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: shimmerDuration)
            return CGFloat(elapsed / shimmerDuration)
        }
    }

    enum BoardItems {
        static let insertionScale = 0.92
        static let removalScale = 0.96
        static let changeResponse: TimeInterval = 0.42
        static let changeDamping: CGFloat = 0.84
        static let revealDelay: Duration = .milliseconds(30)
        static let revealCleanupDelay: Duration = .milliseconds(550)

        static var changeAnimation: Animation {
            .spring(response: changeResponse, dampingFraction: changeDamping)
        }
    }

    enum RefreshPill {
        static let contentSpacing: CGFloat = 8
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 10
        static let overlaySpacing: CGFloat = 8
        static let bottomPadding: CGFloat = 10
        static let borderWidth: CGFloat = 1
        static let shadowRadius: CGFloat = 8
        static let shadowY: CGFloat = 4
        static let iconFont: Font = .footnote.weight(.bold)
        static let iconWidth: CGFloat = 15
        static let messageFont: Font = .footnote.weight(.semibold)
        static let messageColor = DocketTheme.cream
        static let iconColor = DocketTheme.brass
        static let glassTint = DocketTheme.inkLight.opacity(0.78)
        static let borderColor = DocketTheme.cream.opacity(0.12)
        static let shadowColor = Color.black.opacity(0.3)
        static let swipeThreshold: CGFloat = 42
        static let dragReturnDuration: TimeInterval = 0.22
        static let insertionResponse: TimeInterval = 0.38
        static let insertionDamping: CGFloat = 0.82
        static let removalDuration: TimeInterval = 0.18
        static let visibleDuration: Duration = .seconds(2.8)
        static let minimumSaveDuration: Duration = .milliseconds(700)
    }

    enum CreateBoard {
        static let contentSpacing: CGFloat = 14
        static let horizontalPadding: CGFloat = 22
        static let topPadding: CGFloat = 34
        static let inputPadding: CGFloat = 16
        static let inputCornerRadius: CGFloat = 14
        static let headingFont: Font = DocketTheme.display(28)
        static let supportingFont: Font = .subheadline
        static let inputFont: Font = DocketTheme.displayRegular(20)
        static let errorFont: Font = .footnote
        static let headingColor = DocketTheme.cream
        static let supportingColor = DocketTheme.cream.opacity(0.68)
        static let inputColor = DocketTheme.ink
        static let inputBackground = DocketTheme.cream
        static let cancelColor = DocketTheme.cream
        static let errorColor = Color.red.opacity(0.9)
        static let focusDelay: Duration = .milliseconds(180)
    }

    enum ProfileSetup {
        static let maxContentWidth: CGFloat = 520
        static let horizontalPadding: CGFloat = 24
        static let topPadding: CGFloat = 38
        static let bottomPadding: CGFloat = 40
        static let heroSpacing: CGFloat = 10
        static let sectionSpacing: CGFloat = 22
        static let paperSpacing: CGFloat = 18
        static let paperPadding: CGFloat = 22
        static let paperCornerRadius: CGFloat = 8
        static let fieldSpacing: CGFloat = 8
        static let fieldPadding: CGFloat = 14
        static let fieldCornerRadius: CGFloat = 10
        static let pinSize: CGFloat = 16
        static let pinOffsetY: CGFloat = -7
        static let titleFont: Font = DocketTheme.display(34)
        static let headingFont: Font = DocketTheme.display(23)
        static let bodyFont: Font = .subheadline
        static let labelFont: Font = .caption.weight(.bold)
        static let messageFont: Font = .footnote.weight(.medium)
        static let titleColor = DocketTheme.cream
        static let bodyColor = DocketTheme.cream.opacity(0.68)
        static let paperTitleColor = DocketTheme.ink
        static let paperBodyColor = DocketTheme.ink.opacity(0.62)
        static let fieldBackground = DocketTheme.ink.opacity(0.06)
        static let fieldBorder = DocketTheme.ink.opacity(0.1)
        static let messageColor = DocketTheme.cream.opacity(0.76)
        static let errorColor = Color(hex: 0xE29A89)
    }

    enum ProfileSettings {
        static let maxContentWidth: CGFloat = 620
        static let horizontalPadding: CGFloat = 18
        static let verticalPadding: CGFloat = 20
        static let sectionSpacing: CGFloat = 18
        static let cardPadding: CGFloat = 20
        static let cardCornerRadius: CGFloat = 12
        static let cardSpacing: CGFloat = 14
        static let avatarSize: CGFloat = 62
        static let avatarFont: Font = DocketTheme.display(22)
        static let nameFont: Font = DocketTheme.display(24)
        static let headingFont: Font = DocketTheme.display(20)
        static let statValueFont: Font = DocketTheme.display(27)
        static let statLabelFont: Font = .caption.weight(.semibold)
        static let supportingFont: Font = .caption
        static let gridSpacing: CGFloat = 12
        static let tilePadding: CGFloat = 16
        static let tileCornerRadius: CGFloat = 10
        static let pinSize: CGFloat = 12
        static let pinOffsetY: CGFloat = -6
        static let shadowColor = Color.black.opacity(0.24)
        static let shadowRadius: CGFloat = 7
        static let shadowY: CGFloat = 4
        static let warningColor = Color(hex: 0xE8B36A)
    }

    enum DetailToolbar {
        /// Keeps keyboard actions visually separate from the keys beneath them.
        static let keyboardBottomPadding: CGFloat = 8
    }

    enum BoardScrollNote {
        static let font: Font = .footnote.weight(.medium)
        static let color = DocketTheme.cream.opacity(0.62)
        static let fadeStart: CGFloat = 480
        static let fadeDistance: CGFloat = 300
        static let progressStep: CGFloat = 0.05
        static let hiddenOffset: CGFloat = 8
        static let bottomPadding: CGFloat = 12

        static func progress(for offset: CGFloat) -> CGFloat {
            let rawProgress = (offset - fadeStart) / fadeDistance
            let clampedProgress = min(max(rawProgress, 0), 1)
            return (clampedProgress / progressStep).rounded() * progressStep
        }
    }

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
