import SwiftUI

struct CuisineEditRow: View {
    @Environment(\.docketSurfacePalette) private var palette

    let accent: Color
    let availableCuisines: [String]
    @Binding var cuisines: [String]
    let focusedField: FocusState<ItemDraftField?>.Binding

    @State private var query = ""

    private var suggestions: [String] {
        Array(
            CuisineCatalog.suggestions(
                matching: query,
                selected: cuisines,
                available: availableCuisines
            )
            .prefix(query.trimmed.isEmpty ? 8 : 6)
        )
    }

    private var canAddQuery: Bool {
        guard let candidate = CuisineCatalog.normalizedName(query) else { return false }
        let key = CuisineCatalog.comparisonKey(candidate)
        return !cuisines.contains { CuisineCatalog.comparisonKey($0) == key }
    }

    var body: some View {
        HStack(alignment: .top, spacing: DocketDetailTheme.Fact.rowSpacing) {
            Image(systemName: "takeoutbag.and.cup.and.straw.fill")
                .font(DocketDetailTheme.Fact.symbolFont)
                .foregroundStyle(accent)
                .frame(width: DocketDetailTheme.Fact.symbolWidth)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 9) {
                Text("Cuisines")
                    .font(DocketDetailTheme.Edit.labelFont)
                    .foregroundStyle(palette.mutedText)

                if !cuisines.isEmpty {
                    CuisineFlowLayout(spacing: 7) {
                        ForEach(cuisines, id: \.self) { cuisine in
                            Button {
                                remove(cuisine)
                            } label: {
                                Label(cuisine, systemImage: "xmark")
                                    .labelStyle(CuisineRemoveLabelStyle())
                            }
                            .buttonStyle(CuisineChipButtonStyle(accent: accent, isSelected: true))
                            .accessibilityLabel("Remove \(cuisine)")
                        }
                    }
                }

                HStack(spacing: 8) {
                    TextField("Type or choose a cuisine", text: $query)
                        .font(DocketDetailTheme.Edit.inputFont)
                        .foregroundStyle(palette.primaryText)
                        .textFieldStyle(.plain)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .focused(focusedField, equals: .cuisine)
                        .submitLabel(.done)
                        .onSubmit(addQuery)

                    Button(action: addQuery) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(accent)
                    .disabled(!canAddQuery)
                    .opacity(canAddQuery ? 1 : 0.35)
                    .accessibilityLabel("Add cuisine")
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 9)
                .background(palette.primaryText.opacity(0.055), in: RoundedRectangle(cornerRadius: 9))

                if !suggestions.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: 7) {
                            ForEach(suggestions, id: \.self) { suggestion in
                                Button(suggestion) { add(suggestion) }
                                    .buttonStyle(
                                        CuisineChipButtonStyle(accent: accent, isSelected: false)
                                    )
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .accessibilityLabel("Cuisine suggestions")
                }
            }
        }
        .padding(.vertical, DocketDetailTheme.Edit.fieldVerticalPadding)
        .id(ItemDraftField.cuisine)
    }

    private func addQuery() {
        guard let cuisine = CuisineCatalog.normalizedName(query), canAddQuery else { return }
        add(cuisine)
    }

    private func add(_ cuisine: String) {
        cuisines = CuisineCatalog.normalized(cuisines + [cuisine])
        query = ""
    }

    private func remove(_ cuisine: String) {
        let key = CuisineCatalog.comparisonKey(cuisine)
        cuisines.removeAll { CuisineCatalog.comparisonKey($0) == key }
    }
}

struct CuisineDisplayRow: View {
    @Environment(\.docketSurfacePalette) private var palette

    let cuisines: [String]
    let accent: Color
    let onTap: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: DocketDetailTheme.Fact.rowSpacing) {
            Image(systemName: "takeoutbag.and.cup.and.straw.fill")
                .font(DocketDetailTheme.Fact.symbolFont)
                .foregroundStyle(accent)
                .frame(width: DocketDetailTheme.Fact.symbolWidth)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 6) {
                Text("Cuisines")
                    .font(DocketDetailTheme.Fact.labelFont)
                    .foregroundStyle(palette.secondaryText)

                if cuisines.isEmpty {
                    Text("Add cuisine")
                        .font(DocketDetailTheme.Fact.valueFont)
                        .foregroundStyle(palette.mutedText)
                        .italic()
                } else {
                    CuisineFlowLayout(spacing: 7) {
                        ForEach(cuisines, id: \.self) { cuisine in
                            Text(cuisine)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(palette.primaryText)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(accent.opacity(0.15), in: Capsule())
                                .overlay(Capsule().stroke(accent.opacity(0.28), lineWidth: 1))
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, DocketDetailTheme.Fact.verticalPadding)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Double tap to edit cuisines")
    }
}

private struct CuisineChipButtonStyle: ButtonStyle {
    @Environment(\.docketSurfacePalette) private var palette

    let accent: Color
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .foregroundStyle(palette.primaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                isSelected ? accent.opacity(0.18) : palette.primaryText.opacity(0.06),
                in: Capsule()
            )
            .overlay(
                Capsule().stroke(
                    isSelected ? accent.opacity(0.38) : palette.primaryText.opacity(0.12),
                    lineWidth: 1
                )
            )
            .opacity(configuration.isPressed ? 0.65 : 1)
    }
}

private struct CuisineRemoveLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.title
            configuration.icon.font(.caption2.weight(.bold))
        }
    }
}

/// A small wrapping layout keeps cuisine chips compact without requiring a
/// fixed number of columns or truncating custom names.
private struct CuisineFlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let arrangement = arrange(
            proposal: ProposedViewSize(width: bounds.width, height: proposal.height),
            subviews: subviews
        )
        for (index, point) in arrangement.points.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> Arrangement {
        let maximumWidth = proposal.width ?? .infinity
        var points: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var usedWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maximumWidth {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            usedWidth = max(usedWidth, x - spacing)
        }

        return Arrangement(
            points: points,
            size: CGSize(width: usedWidth, height: subviews.isEmpty ? 0 : y + lineHeight)
        )
    }

    private struct Arrangement {
        let points: [CGPoint]
        let size: CGSize
    }
}
