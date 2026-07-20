//
//  StatusChip.swift
//  Docket
//
//  Small capsule showing an item's status, colored per DocketTheme.
//

import SwiftUI

struct StatusChip: View {
    let status: ItemStatus
    var category: ItemCategory? = nil

    var body: some View {
        Text(category.map { status.label(for: $0) } ?? status.label)
            .font(DocketTheme.StatusBadge.font)
            .lineLimit(1)
            .padding(.horizontal, DocketTheme.StatusBadge.horizontalPadding)
            .padding(.vertical, DocketTheme.StatusBadge.verticalPadding)
            .background(Capsule().fill(status.chipColor.opacity(0.16)))
            .foregroundStyle(status.chipColor)
    }
}

#Preview {
    HStack {
        ForEach(ItemStatus.allCases, id: \.self) { StatusChip(status: $0) }
    }
    .padding()
    .background(DocketTheme.cream)
}
