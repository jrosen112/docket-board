//
//  FilterChip.swift
//  Docket
//
//  Tappable capsule for the filter bar, styled for the navy board surface.
//  Dumb: selection state and tap handling come from outside.
//

import SwiftUI

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    var accent: Color = DocketTheme.brass
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(isSelected ? AnyShapeStyle(accent) : AnyShapeStyle(.white.opacity(0.08)))
                )
                .foregroundStyle(isSelected ? DocketTheme.ink : DocketTheme.cream.opacity(0.85))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HStack {
        FilterChip(label: "All", isSelected: true) {}
        FilterChip(label: "Bar", isSelected: false, accent: ItemCategory.bar.accent) {}
    }
    .padding()
    .background(DocketTheme.ink)
}
