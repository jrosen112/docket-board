import SwiftUI

nonisolated enum AppPreferences {
    static let darkerThemeKey = "docket.appearance.darkerThemeEnabled"
    static let defaultDarkerThemeEnabled = false
}

nonisolated struct DocketSurfacePalette {
    let paper: Color
    let raisedPaper: Color
    let primaryText: Color
    let bodyText: Color
    let secondaryText: Color
    let mutedText: Color
    let divider: Color
    let shadow: Color

    static let standard = DocketSurfacePalette(
        paper: DocketTheme.cream,
        raisedPaper: DocketTheme.cream,
        primaryText: DocketTheme.ink,
        bodyText: DocketTheme.ink.opacity(0.82),
        secondaryText: DocketTheme.ink.opacity(0.65),
        mutedText: DocketTheme.ink.opacity(0.5),
        divider: DocketTheme.ink.opacity(0.13),
        shadow: Color.black.opacity(0.25)
    )

    static let darker = DocketSurfacePalette(
        paper: Color(hex: 0x232A34),
        raisedPaper: Color(hex: 0x2A333F),
        primaryText: DocketTheme.cream,
        bodyText: DocketTheme.cream.opacity(0.86),
        secondaryText: DocketTheme.cream.opacity(0.68),
        mutedText: DocketTheme.cream.opacity(0.5),
        divider: DocketTheme.cream.opacity(0.12),
        shadow: Color.black.opacity(0.5)
    )
}

private struct DocketSurfacePaletteKey: EnvironmentKey {
    static let defaultValue = DocketSurfacePalette.standard
}

extension EnvironmentValues {
    var docketSurfacePalette: DocketSurfacePalette {
        get { self[DocketSurfacePaletteKey.self] }
        set { self[DocketSurfacePaletteKey.self] = newValue }
    }
}
