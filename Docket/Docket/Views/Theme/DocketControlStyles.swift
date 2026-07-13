import SwiftUI

private struct DocketPrimaryActionModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .buttonStyle(.glassProminent)
            .tint(DocketTheme.brass)
    }
}

extension View {
    func docketPrimaryActionStyle() -> some View {
        modifier(DocketPrimaryActionModifier())
    }
}
