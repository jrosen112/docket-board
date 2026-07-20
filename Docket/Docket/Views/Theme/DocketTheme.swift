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
        static let categoryFooterSpacing: CGFloat = 8
        static let categoryFooterTextSpacing: CGFloat = 5
        static let categoryBadgeSize: CGFloat = 32
        static let categoryBadgeSymbolFont: Font = .system(size: 14, weight: .bold)
        /// TMDB posters are delivered at roughly 2:3, so matching the card to
        /// that ratio keeps the artwork visible instead of turning it into a
        /// short landscape crop.
        static let moviePosterAspectRatio: CGFloat = 2.0 / 3.0
        static let movieCornerRadius: CGFloat = 5
        static let movieContentPadding: CGFloat = 12
        static let movieTextSpacing: CGFloat = 4
        static let movieTitleFont: Font = DocketTheme.display(19)
        static let movieSubtitleFont: Font = .caption.weight(.medium)
        static let movieAuthorFont: Font = .caption2.italic()
        static let movieTitleLineLimit = 3
        static let moviePrimaryText = Color.white
        static let movieSecondaryText = Color.white.opacity(0.82)
        static let movieMutedText = Color.white.opacity(0.66)
        static let moviePosterGradientColors = [
            Color.black.opacity(0.04),
            Color.black.opacity(0.02),
            Color.black.opacity(0.22),
            Color.black.opacity(0.9),
        ]
        static let movieBadgeHorizontalPadding: CGFloat = 7
        static let movieBadgeVerticalPadding: CGFloat = 5
        static let movieBadgeBackground = Color.black.opacity(0.52)
        static let movieStatusSpacing: CGFloat = 4
        static let movieStatusDotSize: CGFloat = 6
        static let movieStatusFont: Font = .system(size: 8, weight: .bold)
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

    enum BoardManager {
        static let maxContentWidth: CGFloat = 680
        static let horizontalPadding: CGFloat = 18
        static let topPadding: CGFloat = 22
        static let bottomPadding: CGFloat = 36
        static let sectionSpacing: CGFloat = 16
        static let cardHeaderSpacing: CGFloat = 12
        static let titleSpacing: CGFloat = 5
        static let activeCardPadding: CGFloat = 20
        static let activeCardCornerRadius: CGFloat = 16
        static let activeTitleFont: Font = DocketTheme.display(27)
        static let pinSize: CGFloat = 13
        static let pinOffsetY: CGFloat = -6
        static let activeShadowRadius: CGFloat = 10
        static let activeShadowY: CGFloat = 6
        static let rowPadding: CGFloat = 15
        static let rowCornerRadius: CGFloat = 13
        static let rowTitleFont: Font = DocketTheme.display(19)
        static let rowShadowOpacity: Double = 0.45
        static let rowShadowRadius: CGFloat = 4
        static let rowShadowY: CGFloat = 2
        static let metadataFont: Font = .caption
        static let loadingSpacing: CGFloat = 7
        static let sectionLabelFont: Font = .caption2.weight(.bold)
        static let sectionLabelTracking: CGFloat = 1.25
        static let sectionLabelColor = DocketTheme.cream.opacity(0.5)
        static let sectionLabelLeadingPadding: CGFloat = 3
        static let sectionLabelTopPadding: CGFloat = 10
        static let latestSpacing: CGFloat = 6
        static let latestDotSize: CGFloat = 6
        /// Extra transparent height inside each list row so the tape strips
        /// and brass pin can overhang the card without being clipped by the
        /// row's bounds.
        static let rowOverhangHeadroom: CGFloat = 8
        static let unavailableColor = Color(hex: 0xE8B36A)
    }

    enum WashiTape {
        /// One strip's placement along a card's top edge. `xFraction` locates
        /// the strip center across the card width; `xNudge` shifts it inward
        /// in points (corner strips use it to stay on screen); `yCenter` is
        /// relative to the card's top edge; ±45° reads as corner tape.
        struct Strip {
            let xFraction: CGFloat
            let xNudge: CGFloat
            let yCenter: CGFloat
            let rotationDegrees: Double
        }

        static let width: CGFloat = 54
        static let height: CGFloat = 16
        static let cornerRadius: CGFloat = 1.5
        static let opacity: Double = 0.55

        /// Hand-tuned layouts of one or two strips whose x positions are far
        /// enough apart to never overlap at any card width. Picked per board
        /// via `arrangement(for:)`, salted separately from the color hash so
        /// same-color boards can still hang differently.
        static let arrangements: [[Strip]] = [
            [
                Strip(xFraction: 0.15, xNudge: 0, yCenter: 1, rotationDegrees: -4),
                Strip(xFraction: 0.85, xNudge: 0, yCenter: 1, rotationDegrees: 3),
            ],
            [Strip(xFraction: 0.5, xNudge: 0, yCenter: 1, rotationDegrees: -2)],
            [Strip(xFraction: 0.3, xNudge: 0, yCenter: 1, rotationDegrees: 3)],
            [
                Strip(xFraction: 0, xNudge: 12, yCenter: 3, rotationDegrees: -45),
                Strip(xFraction: 0.78, xNudge: 0, yCenter: 1, rotationDegrees: -3),
            ],
            [
                Strip(xFraction: 0.22, xNudge: 0, yCenter: 1, rotationDegrees: 2),
                Strip(xFraction: 0.68, xNudge: 0, yCenter: 1, rotationDegrees: -5),
            ],
            [
                Strip(xFraction: 0.28, xNudge: 0, yCenter: 1, rotationDegrees: -3),
                Strip(xFraction: 1, xNudge: -12, yCenter: 3, rotationDegrees: 45),
            ],
            [Strip(xFraction: 0.64, xNudge: 0, yCenter: 1, rotationDegrees: 4)],
        ]

        /// Muted tape stock that sits on both navy and cream. Assigned per
        /// board via `color(for:)` so each board keeps a stable identity.
        static let colors: [Color] = [
            Color(hex: 0xC96F4A),  // terracotta
            Color(hex: 0x7C9A5C),  // moss
            Color(hex: 0x9B6A8F),  // dusty plum
            Color(hex: 0x6B8CAE),  // slate blue
            Color(hex: 0x5F9EA0),  // teal
            Color(hex: 0xC08A2E),  // amber
        ]

        static func color(for key: String) -> Color {
            colors[DocketTheme.stableHash(for: key) % colors.count]
        }

        static func arrangement(for key: String) -> [Strip] {
            arrangements[
                DocketTheme.stableHash(for: key + "#tape-layout") % arrangements.count
            ]
        }
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

    enum JoinBoard {
        static let maxContentWidth: CGFloat = 520
        static let horizontalPadding: CGFloat = 24
        static let topPadding: CGFloat = 28
        static let bottomPadding: CGFloat = 24
        static let sectionSpacing: CGFloat = 20
        static let heroSpacing: CGFloat = 8
        static let iconSize: CGFloat = 64
        static let iconFont: Font = .system(size: 27, weight: .semibold)
        static let titleFont: Font = DocketTheme.display(27)
        static let bodyFont: Font = .subheadline
        static let boardNameFont: Font = DocketTheme.display(23)
        static let labelFont: Font = .caption2.weight(.bold)
        static let cardPadding: CGFloat = 20
        static let cardCornerRadius: CGFloat = 8
        static let pinSize: CGFloat = 14
        static let pinOffsetY: CGFloat = -6
        static let actionSpacing: CGFloat = 10
        static let titleColor = DocketTheme.cream
        static let bodyColor = DocketTheme.cream.opacity(0.68)
        static let cardLabelColor = DocketTheme.ink.opacity(0.55)
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
    /// name so a card keeps its tilt across refreshes and launches.
    static func rotationDegrees(for key: String) -> Double {
        Double(stableHash(for: key) % 300) / 100.0 - 1.5
    }

    /// djb2 over unicode scalars, masked non-negative — stable across
    /// launches, unlike hashValue, which is randomized per process.
    static func stableHash(for key: String) -> Int {
        var hash = 5381
        for scalar in key.unicodeScalars {
            hash = (hash &* 33) &+ Int(scalar.value)
        }
        return hash & 0x7FFF_FFFF
    }
}

// MARK: Category + status colors (presentation only — models stay color-free)

nonisolated extension ItemCategory {
    /// Color-coded accent per category, tuned to sit on cream card stock.
    var accent: Color {
        switch self {
        case .restaurant: Color(hex: 0xC96F4A)  // terracotta
        case .bar: Color(hex: 0x9B6A8F)  // dusty plum
        case .recipe: Color(hex: 0x91AF84)  // soft sage
        case .happyHour: Color(hex: 0xC08A2E)  // amber
        case .landmark: Color(hex: 0x6B8CAE)  // slate blue
        case .movie: Color(hex: 0xB85C5C)  // muted red
        case .hike: Color(hex: 0x7C9A5C)  // moss green
        case .activity: Color(hex: 0x5F9EA0)  // teal
        }
    }
}

nonisolated extension ItemStatus {
    /// Chip color, dark enough to read on cream.
    var chipColor: Color {
        switch self {
        case .wantToGo: Color(hex: 0xA6762E)  // dark brass
        case .planned: Color(hex: 0x4A7B7C)  // teal
        case .completed: Color(hex: 0x6B7B4A)  // olive
        }
    }
}
