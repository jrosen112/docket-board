import SwiftUI

struct BoardFilterSheet: View {
    @Binding var filter: BoardFilter
    let categories: [ItemCategory]
    let cuisines: [String]
    let onCancel: () -> Void
    let onApply: () -> Void

    private var columns: [GridItem] {
        [
            GridItem(
                .adaptive(minimum: DocketTheme.FilterSheet.gridMinimumWidth),
                spacing: DocketTheme.FilterSheet.gridSpacing
            )
        ]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Rectangle()
                    .fill(DocketTheme.boardBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: DocketTheme.FilterSheet.sectionSpacing) {
                        categorySection
                        statusSection
                        if !cuisines.isEmpty || !filter.cuisines.isEmpty {
                            cuisineSection
                        }
                    }
                    .padding(.horizontal, DocketTheme.FilterSheet.pageHorizontalPadding)
                    .padding(.top, DocketTheme.FilterSheet.pageTopPadding)
                    .padding(.bottom, DocketTheme.FilterSheet.pageBottomPadding)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DocketTheme.ink, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }

                ToolbarItem(placement: .bottomBar) {
                    Button("Reset") { filter.clear() }
                        .disabled(!filter.isActive)
                }

                ToolbarSpacer(.flexible, placement: .bottomBar)

                ToolbarItem(placement: .bottomBar) {
                    Button("Show items", action: onApply)
                        .docketPrimaryActionStyle()
                }
            }
        }
    }

    private var categorySection: some View {
        filterSection(
            title: "Categories",
            selectionSummary: filter.categories.isEmpty
                ? "All categories"
                : "\(filter.categories.count) selected"
        ) {
            LazyVGrid(columns: columns, spacing: DocketTheme.FilterSheet.gridSpacing) {
                ForEach(categories, id: \.self) { category in
                    FilterChoiceTile(
                        label: category.label,
                        symbol: category.symbol,
                        accent: category.accent,
                        isSelected: filter.categories.contains(category),
                        action: { filter.toggle(category) }
                    )
                }
            }
        }
    }

    private var statusSection: some View {
        filterSection(
            title: "Status",
            selectionSummary: filter.statuses.isEmpty
                ? "Any status"
                : "\(filter.statuses.count) selected"
        ) {
            LazyVGrid(columns: columns, spacing: DocketTheme.FilterSheet.gridSpacing) {
                ForEach(ItemStatus.allCases, id: \.self) { status in
                    FilterChoiceTile(
                        label: status.label,
                        symbol: status.symbol,
                        accent: status.chipColor,
                        isSelected: filter.statuses.contains(status),
                        action: { filter.toggle(status) }
                    )
                }
            }
        }
    }

    private var cuisineSection: some View {
        filterSection(
            title: "Cuisines",
            selectionSummary: filter.cuisines.isEmpty
                ? "Any cuisine"
                : "\(filter.cuisines.count) selected"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Menu {
                    Section("Match any selected cuisine") {
                        ForEach(cuisines, id: \.self) { cuisine in
                            Toggle(
                                cuisine,
                                isOn: Binding(
                                    get: { filter.contains(cuisine: cuisine) },
                                    set: { _ in filter.toggle(cuisine: cuisine) }
                                )
                            )
                            .menuActionDismissBehavior(.disabled)
                        }
                    }
                } label: {
                    HStack(spacing: DocketTheme.FilterSheet.tileSpacing) {
                        Image(systemName: "fork.knife")
                            .foregroundStyle(DocketTheme.brass)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Choose cuisines")
                                .font(DocketTheme.FilterSheet.tileFont)
                            Text("Only cuisines used on this board")
                                .font(.caption)
                                .foregroundStyle(DocketTheme.FilterSheet.selectionSummaryColor)
                        }

                        Spacer(minLength: 8)

                        Text("\(cuisines.count)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(DocketTheme.brass)

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2.weight(.bold))
                    }
                    .padding(.horizontal, DocketTheme.FilterSheet.tileHorizontalPadding)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    .foregroundStyle(DocketTheme.FilterSheet.unselectedForeground)
                    .background(
                        RoundedRectangle(
                            cornerRadius: DocketTheme.FilterSheet.tileCornerRadius,
                            style: .continuous
                        )
                        .fill(DocketTheme.FilterSheet.unselectedFill)
                    )
                    .overlay(
                        RoundedRectangle(
                            cornerRadius: DocketTheme.FilterSheet.tileCornerRadius,
                            style: .continuous
                        )
                        .stroke(DocketTheme.FilterSheet.unselectedBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                if !filter.cuisines.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(
                                filter.cuisines.sorted {
                                    $0.localizedStandardCompare($1) == .orderedAscending
                                },
                                id: \.self
                            ) { cuisine in
                                Button {
                                    filter.toggle(cuisine: cuisine)
                                } label: {
                                    HStack(spacing: 6) {
                                        Text(cuisine)
                                        Image(systemName: "xmark")
                                            .font(.caption2.weight(.bold))
                                    }
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 7)
                                    .foregroundStyle(DocketTheme.ink)
                                    .background(DocketTheme.brass, in: Capsule())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Remove \(cuisine) filter")
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
    }

    private func filterSection<Content: View>(
        title: String,
        selectionSummary: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DocketTheme.FilterSheet.sectionHeaderSpacing) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(DocketTheme.FilterSheet.sectionTitleFont)
                    .foregroundStyle(DocketTheme.FilterSheet.sectionTitleColor)

                Spacer()

                Text(selectionSummary)
                    .font(DocketTheme.FilterSheet.selectionSummaryFont)
                    .foregroundStyle(DocketTheme.FilterSheet.selectionSummaryColor)
            }

            content()
        }
    }
}

private struct FilterChoiceTile: View {
    let label: String
    let symbol: String
    let accent: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DocketTheme.FilterSheet.tileSpacing) {
                Image(systemName: symbol)
                Text(label)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if isSelected {
                    Image(systemName: "checkmark")
                }
            }
            .font(DocketTheme.FilterSheet.tileFont)
            .padding(.horizontal, DocketTheme.FilterSheet.tileHorizontalPadding)
            .padding(.vertical, DocketTheme.FilterSheet.tileVerticalPadding)
            .frame(
                maxWidth: .infinity,
                minHeight: DocketTheme.FilterSheet.tileMinimumHeight,
                alignment: .leading
            )
            .foregroundStyle(
                isSelected ? DocketTheme.ink : DocketTheme.FilterSheet.unselectedForeground
            )
            .background(
                RoundedRectangle(
                    cornerRadius: DocketTheme.FilterSheet.tileCornerRadius,
                    style: .continuous
                )
                .fill(isSelected ? accent : DocketTheme.FilterSheet.unselectedFill)
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: DocketTheme.FilterSheet.tileCornerRadius,
                    style: .continuous
                )
                .stroke(
                    isSelected ? accent.opacity(0) : DocketTheme.FilterSheet.unselectedBorder,
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

extension ItemStatus {
    fileprivate var symbol: String {
        switch self {
        case .wantToGo: "bookmark.fill"
        case .planned: "calendar.badge.checkmark"
        case .completed: "checkmark.circle.fill"
        }
    }
}
