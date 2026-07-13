//
//  StatusChip.swift
//  Docket
//
//  Small capsule showing an item's status, colored per DocketTheme.
//

import SwiftUI

struct StatusChip: View {
    let status: ItemStatus

    var body: some View {
        Text(status.label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
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
