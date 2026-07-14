import SwiftUI

private struct DocketPrimaryActionModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .buttonStyle(.glassProminent)
            .tint(DocketTheme.brass)
    }
}

private struct DocketSecondaryActionModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .buttonStyle(.glass)
            .tint(DocketTheme.inkLight)
            .foregroundStyle(DocketTheme.cream)
    }
}

private struct DocketPrimaryMenuModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .menuStyle(.button)
            .buttonStyle(.borderedProminent)
            .tint(DocketTheme.brass)
    }
}

extension View {
    func docketPrimaryActionStyle() -> some View {
        modifier(DocketPrimaryActionModifier())
    }

    func docketSecondaryActionStyle() -> some View {
        modifier(DocketSecondaryActionModifier())
    }

    func docketPrimaryMenuStyle() -> some View {
        modifier(DocketPrimaryMenuModifier())
    }
}
