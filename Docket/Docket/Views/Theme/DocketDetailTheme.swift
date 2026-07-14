import SwiftUI

nonisolated enum DocketDetailTheme {
    enum Page {
        static let sectionSpacing: CGFloat = 18
        static let horizontalPadding: CGFloat = 18
        static let topPadding: CGFloat = 18
        static let bottomPadding: CGFloat = 36
    }

    enum Hero {
        static let contentSpacing: CGFloat = 15
        static let headerSpacing: CGFloat = 10
        static let metadataSpacing: CGFloat = 8
        static let metadataMinimumSpacing: CGFloat = 12
        static let padding: CGFloat = 20
        static let cornerRadius: CGFloat = 12
        static let symbolSize: CGFloat = 36
        static let pinSize: CGFloat = 12
        static let pinOffset: CGFloat = -6
        static let categoryTracking: CGFloat = 1.4
        static let rotationScale = 0.3
        static let shadowRadius: CGFloat = 8
        static let shadowX: CGFloat = 0
        static let shadowY: CGFloat = 5

        static let symbolFont: Font = .headline
        static let categoryFont: Font = .caption.weight(.bold)
        static let titleFont: Font = DocketTheme.display(28)
        static let metadataFont: Font = .caption

        static let paper = DocketTheme.cream
        static let symbolForeground = Color.white
        static let titleColor = DocketTheme.ink
        static let metadataColor = DocketTheme.ink.opacity(0.52)
        static let shadowColor = Color.black.opacity(0.3)
        static let pinColor = DocketTheme.brass
        static let pinStrokeColor = Color.black.opacity(0.25)
        static let pinShadowColor = Color.black.opacity(0.35)
        static let pinStrokeWidth: CGFloat = 0.5
        static let pinShadowRadius: CGFloat = 1.5
        static let pinShadowX: CGFloat = 0
        static let pinShadowY: CGFloat = 1
    }

    enum Card {
        static let contentSpacing: CGFloat = 14
        static let padding: CGFloat = 18
        static let cornerRadius: CGFloat = 12
        static let dividerOpacity = 0.35
        static let stripeWidth: CGFloat = 4
        static let stripeVerticalPadding: CGFloat = 14
        static let stripeLeadingPadding: CGFloat = 6
        static let shadowRadius: CGFloat = 6
        static let shadowX: CGFloat = 0
        static let shadowY: CGFloat = 4

        static let titleFont: Font = DocketTheme.displayRegular(17)
        static let titleColor = DocketTheme.ink
        static let paper = DocketTheme.cream
        static let shadowColor = Color.black.opacity(0.22)
    }

    enum Fact {
        static let rowSpacing: CGFloat = 12
        static let valueMinimumSpacing: CGFloat = 12
        static let symbolWidth: CGFloat = 24
        static let verticalPadding: CGFloat = 4

        static let symbolFont: Font = .callout.weight(.semibold)
        static let labelFont: Font = .subheadline
        static let valueFont: Font = .subheadline.weight(.semibold)
        static let labelColor = DocketTheme.ink.opacity(0.58)
        static let valueColor = DocketTheme.ink
    }

    enum Notes {
        static let font: Font = DocketTheme.displayRegular(16)
        static let color = DocketTheme.ink.opacity(0.84)
        static let lineSpacing: CGFloat = 4
    }

    enum Empty {
        static let font: Font = .subheadline.italic()
        static let color = DocketTheme.ink.opacity(0.55)
    }

    enum QuickLook {
        static let width: CGFloat = 320
        static let padding: CGFloat = 20
        static let contentLeadingExtraPadding: CGFloat = 12
        static let cornerRadius: CGFloat = 14
        static let sectionSpacing: CGFloat = 13
        static let headerSpacing: CGFloat = 9
        static let factSpacing: CGFloat = 8
        static let factGroupSpacing: CGFloat = 10
        static let factTextSpacing: CGFloat = 4
        static let noteSpacing: CGFloat = 10
        static let noteLineSpacing: CGFloat = 2
        static let footerSpacing: CGFloat = 8
        static let stripeWidth: CGFloat = 4
        static let stripeVerticalPadding: CGFloat = 16
        static let stripeLeadingPadding: CGFloat = 14
        static let pinSize: CGFloat = 10
        static let pinOffset: CGFloat = 5
        static let categorySymbolSize: CGFloat = 30
        static let categoryTracking: CGFloat = 1.2
        static let factLabelTracking: CGFloat = 0.5

        static let titleFont: Font = DocketTheme.display(24)
        static let categoryFont: Font = .caption2.weight(.bold)
        static let categorySymbolFont: Font = .subheadline.weight(.semibold)
        static let factLabelFont: Font = .caption
        static let factValueFont: Font = .subheadline.weight(.semibold)
        static let noteSymbolFont: Font = .subheadline.weight(.semibold)
        static let notesFont: Font = DocketTheme.displayRegular(15)
        static let footerFont: Font = .caption2

        static let paper = DocketTheme.cream
        static let titleColor = DocketTheme.ink
        static let factLabelColor = DocketTheme.ink.opacity(0.56)
        static let factValueColor = DocketTheme.ink
        static let notesColor = DocketTheme.ink.opacity(0.82)
        static let footerColor = DocketTheme.ink.opacity(0.5)
        static let dividerColor = DocketTheme.ink.opacity(0.13)
    }

    enum Edit {
        static let fieldSpacing: CGFloat = 3
        static let fieldVerticalPadding: CGFloat = 3
        static let titleUnderlineOpacity = 0.24
        static let errorColor = Color.red.opacity(0.82)

        static let labelFont: Font = .caption
        static let inputFont: Font = .body.weight(.semibold)
        static let labelColor = DocketTheme.ink.opacity(0.5)
        static let inputColor = DocketTheme.ink
        static let placeholderColor = DocketTheme.ink.opacity(0.42)
        static let modeAnimation = Animation.snappy(duration: 0.28)
        static let focusDelay: Duration = .milliseconds(180)
    }
}
