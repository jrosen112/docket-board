//
//  BoardFilterBar.swift
//  Docket
//
//  Compact pinned trigger for the multi-select filter sheet.
//

import SwiftUI

struct BoardFilterBar: View {
    let filter: BoardFilter
    let onShowFilters: () -> Void
    let onClear: () -> Void

    private var buttonTitle: String {
        filter.isActive ? "Filters (\(filter.selectionCount))" : "No Filters"
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(action: onShowFilters) {
                HStack(spacing: DocketTheme.BoardFilterHeader.barSpacing) {
                    filterLabel
                    Spacer(minLength: DocketTheme.BoardFilterHeader.minimumButtonSpacing)
                }
                .padding(DocketTheme.BoardFilterHeader.contentPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                filter.isActive
                    ? "Open filters, \(filter.selectionCount) selected"
                    : "Open filters, none selected"
            )

            Button("CLEAR", action: onClear)
                .font(DocketTheme.BoardFilterHeader.clearFont)
                .tracking(DocketTheme.BoardFilterHeader.clearTracking)
                .padding(.horizontal, DocketTheme.BoardFilterHeader.clearHorizontalPadding)
                .padding(.vertical, DocketTheme.BoardFilterHeader.clearVerticalPadding)
                .foregroundStyle(DocketTheme.ink)
                .background(Capsule().fill(DocketTheme.brass))
                .buttonStyle(.plain)
                .disabled(!filter.isActive)
                .opacity(filter.isActive ? 1 : DocketTheme.BoardFilterHeader.disabledOpacity)
                .padding(.trailing, DocketTheme.BoardFilterHeader.contentPadding)
        }
    }

    private var filterLabel: some View {
        HStack(spacing: DocketTheme.BoardFilterHeader.buttonSpacing) {
            Image(systemName: "line.3.horizontal.decrease")
            Text(buttonTitle)
        }
        .font(DocketTheme.BoardFilterHeader.buttonFont)
        .padding(.horizontal, DocketTheme.BoardFilterHeader.buttonHorizontalPadding)
        .padding(.vertical, DocketTheme.BoardFilterHeader.buttonVerticalPadding)
        .foregroundStyle(
            filter.isActive
                ? DocketTheme.ink
                : DocketTheme.cream.opacity(0.9)
        )
        .background(
            Capsule().fill(
                filter.isActive
                    ? DocketTheme.brass
                    : DocketTheme.cream.opacity(0.1)
            )
        )
    }
}

#Preview {
    BoardFilterBar(filter: BoardFilter(), onShowFilters: {}, onClear: {})
        .padding()
        .background(DocketTheme.ink)
}
