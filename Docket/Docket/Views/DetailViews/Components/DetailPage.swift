import CloudKit
import SwiftUI

struct DetailPage<Details: View>: View {
    let item: any SharedListItem
    let addedBy: String
    let symbol: String
    @ViewBuilder let details: Details

    private var accent: Color { item.category.accent }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(DocketTheme.boardBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: DocketDetailTheme.Page.sectionSpacing) {
                    hero

                    DetailSectionCard(
                        title: "The particulars",
                        symbol: symbol,
                        accent: accent
                    ) {
                        details
                    }

                    if let notes = item.notes, !notes.isEmpty {
                        DetailSectionCard(
                            title: "A note for later",
                            symbol: "text.quote",
                            accent: accent
                        ) {
                            Text(notes)
                                .font(DocketDetailTheme.Notes.font)
                                .foregroundStyle(DocketDetailTheme.Notes.color)
                                .lineSpacing(DocketDetailTheme.Notes.lineSpacing)
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding(.horizontal, DocketDetailTheme.Page.horizontalPadding)
                .padding(.top, DocketDetailTheme.Page.topPadding)
                .padding(.bottom, DocketDetailTheme.Page.bottomPadding)
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: DocketDetailTheme.Hero.contentSpacing) {
            HStack(alignment: .center, spacing: DocketDetailTheme.Hero.headerSpacing) {
                Image(systemName: symbol)
                    .font(DocketDetailTheme.Hero.symbolFont)
                    .foregroundStyle(DocketDetailTheme.Hero.symbolForeground)
                    .frame(
                        width: DocketDetailTheme.Hero.symbolSize,
                        height: DocketDetailTheme.Hero.symbolSize
                    )
                    .background(Circle().fill(accent))

                Text(item.category.label.uppercased())
                    .font(DocketDetailTheme.Hero.categoryFont)
                    .tracking(DocketDetailTheme.Hero.categoryTracking)
                    .foregroundStyle(accent)

                Spacer()
                StatusChip(status: item.status)
            }

            Text(item.title)
                .font(DocketDetailTheme.Hero.titleFont)
                .foregroundStyle(DocketDetailTheme.Hero.titleColor)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: DocketDetailTheme.Hero.metadataSpacing) {
                Label(addedBy, systemImage: "person.crop.circle.fill")
                Spacer(minLength: DocketDetailTheme.Hero.metadataMinimumSpacing)
                Text(item.dateAdded, format: .dateTime.month(.abbreviated).day().year())
            }
            .font(DocketDetailTheme.Hero.metadataFont)
            .foregroundStyle(DocketDetailTheme.Hero.metadataColor)
        }
        .padding(DocketDetailTheme.Hero.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DocketDetailTheme.Hero.cornerRadius)
                .fill(DocketDetailTheme.Hero.paper)
                .shadow(
                    color: DocketDetailTheme.Hero.shadowColor,
                    radius: DocketDetailTheme.Hero.shadowRadius,
                    x: DocketDetailTheme.Hero.shadowX,
                    y: DocketDetailTheme.Hero.shadowY
                )
        )
        .overlay(alignment: .top) {
            Circle()
                .fill(DocketDetailTheme.Hero.pinColor)
                .overlay(
                    Circle().stroke(
                        DocketDetailTheme.Hero.pinStrokeColor,
                        lineWidth: DocketDetailTheme.Hero.pinStrokeWidth
                    )
                )
                .frame(
                    width: DocketDetailTheme.Hero.pinSize,
                    height: DocketDetailTheme.Hero.pinSize
                )
                .shadow(
                    color: DocketDetailTheme.Hero.pinShadowColor,
                    radius: DocketDetailTheme.Hero.pinShadowRadius,
                    x: DocketDetailTheme.Hero.pinShadowX,
                    y: DocketDetailTheme.Hero.pinShadowY
                )
                .offset(y: DocketDetailTheme.Hero.pinOffset)
        }
        .rotationEffect(
            .degrees(
                DocketTheme.rotationDegrees(for: item.id.recordName)
                    * DocketDetailTheme.Hero.rotationScale
            )
        )
    }
}
