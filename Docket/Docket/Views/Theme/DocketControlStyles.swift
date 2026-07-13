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

extension View {
    func docketPrimaryActionStyle() -> some View {
        modifier(DocketPrimaryActionModifier())
    }

    func docketSecondaryActionStyle() -> some View {
        modifier(DocketSecondaryActionModifier())
    }
}
