//
//  EmptyBoardView.swift
//  Docket
//
//  What the board shows with no (matching) cards, styled for the navy surface.
//

import SwiftUI

struct EmptyBoardView: View {
    let isFiltered: Bool

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "pin")
                .font(.system(size: 34))
                .foregroundStyle(DocketTheme.brass.opacity(0.7))
            Text(isFiltered ? "Nothing matches" : "Nothing on the board yet")
                .font(DocketTheme.display(19))
                .foregroundStyle(DocketTheme.cream)
            Text(isFiltered ? "Try clearing a filter." : "Tap + to pin your first spot.")
                .font(.subheadline)
                .foregroundStyle(DocketTheme.cream.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 90)
    }
}

#Preview {
    EmptyBoardView(isFiltered: false)
        .frame(maxHeight: .infinity)
        .background(DocketTheme.ink)
}
