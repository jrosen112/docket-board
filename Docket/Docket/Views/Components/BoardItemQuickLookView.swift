import SwiftUI

/// Rich context-menu preview for scanning an item without opening its detail page.
struct BoardItemQuickLookView: View {
    @Environment(\.docketSurfacePalette) private var palette

    let item: any SharedListItem
    let addedBy: String

    private var accent: Color { item.category.accent }
    private var facts: [ItemQuickLookFact] { quickLookFacts(for: item) }
    private var fullWidthFacts: [ItemQuickLookFact] {
        facts.filter(\.prefersFullWidth)
    }
    private var compactFacts: [ItemQuickLookFact] {
        facts.filter { !$0.prefersFullWidth }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DocketDetailTheme.QuickLook.sectionSpacing) {
            header

            Text(item.title)
                .font(DocketDetailTheme.QuickLook.titleFont)
                .foregroundStyle(palette.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(3)

            if !facts.isEmpty {
                Divider()
                    .overlay(palette.divider)

                factLayout
            }

            if let notes = item.notes?.orNil {
                Divider()
                    .overlay(palette.divider)

                HStack(alignment: .top, spacing: DocketDetailTheme.QuickLook.noteSpacing) {
                    Image(systemName: "text.quote")
                        .font(DocketDetailTheme.QuickLook.noteSymbolFont)
                        .foregroundStyle(accent)

                    Text(notes)
                        .font(DocketDetailTheme.QuickLook.notesFont)
                        .foregroundStyle(palette.bodyText)
                        .lineSpacing(DocketDetailTheme.QuickLook.noteLineSpacing)
                        .lineLimit(5)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            footer
        }
        .padding(DocketDetailTheme.QuickLook.padding)
        .padding(.leading, DocketDetailTheme.QuickLook.contentLeadingExtraPadding)
        .frame(
            width: DocketDetailTheme.QuickLook.width,
            alignment: .leading
        )
        .background(
            RoundedRectangle(
                cornerRadius: DocketDetailTheme.QuickLook.cornerRadius,
                style: .continuous
            )
            .fill(palette.raisedPaper)
        )
        .overlay(alignment: .leading) {
            Capsule()
                .fill(accent)
                .frame(width: DocketDetailTheme.QuickLook.stripeWidth)
                .padding(.vertical, DocketDetailTheme.QuickLook.stripeVerticalPadding)
                .padding(.leading, DocketDetailTheme.QuickLook.stripeLeadingPadding)
        }
        .overlay(alignment: .top) {
            Circle()
                .fill(DocketTheme.brass)
                .overlay(Circle().stroke(.black.opacity(0.25), lineWidth: 0.5))
                .frame(
                    width: DocketDetailTheme.QuickLook.pinSize,
                    height: DocketDetailTheme.QuickLook.pinSize
                )
                .offset(y: DocketDetailTheme.QuickLook.pinOffset)
        }
        .contentShape(
            RoundedRectangle(
                cornerRadius: DocketDetailTheme.QuickLook.cornerRadius,
                style: .continuous
            )
        )
    }

    private var header: some View {
        HStack(spacing: DocketDetailTheme.QuickLook.headerSpacing) {
            Image(systemName: item.category.symbol)
                .font(DocketDetailTheme.QuickLook.categorySymbolFont)
                .foregroundStyle(.white)
                .frame(
                    width: DocketDetailTheme.QuickLook.categorySymbolSize,
                    height: DocketDetailTheme.QuickLook.categorySymbolSize
                )
                .background(Circle().fill(accent))

            Text(item.category.label.uppercased())
                .font(DocketDetailTheme.QuickLook.categoryFont)
                .tracking(DocketDetailTheme.QuickLook.categoryTracking)
                .foregroundStyle(accent)

            Spacer(minLength: 8)
            StatusChip(status: item.status, category: item.category)
        }
    }

    private func factCell(_ fact: ItemQuickLookFact) -> some View {
        VStack(alignment: .leading, spacing: DocketDetailTheme.QuickLook.factTextSpacing) {
            Text(fact.label.uppercased())
                .font(DocketDetailTheme.QuickLook.factLabelFont)
                .tracking(DocketDetailTheme.QuickLook.factLabelTracking)
                .foregroundStyle(palette.mutedText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(fact.value)
                .font(DocketDetailTheme.QuickLook.factValueFont)
                .foregroundStyle(palette.primaryText)
                .lineLimit(fact.prefersFullWidth ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var factLayout: some View {
        VStack(alignment: .leading, spacing: DocketDetailTheme.QuickLook.factGroupSpacing) {
            ForEach(fullWidthFacts) { fact in
                factCell(fact)
            }

            if !fullWidthFacts.isEmpty && !compactFacts.isEmpty {
                Divider()
                    .overlay(palette.divider)
            }

            if !compactFacts.isEmpty {
                HStack(
                    alignment: .top,
                    spacing: DocketDetailTheme.QuickLook.factSpacing
                ) {
                    ForEach(compactFacts.indices, id: \.self) { index in
                        if index > compactFacts.startIndex {
                            Divider()
                                .overlay(palette.divider)
                        }
                        factCell(compactFacts[index])
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: DocketDetailTheme.QuickLook.footerSpacing) {
            Label(addedBy, systemImage: "person.crop.circle.fill")
                .lineLimit(1)
            Spacer(minLength: 10)
            Text(item.dateAdded, format: .dateTime.month(.abbreviated).day().year())
        }
        .font(DocketDetailTheme.QuickLook.footerFont)
        .foregroundStyle(palette.mutedText)
    }
}
