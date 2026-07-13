import CloudKit
import SwiftUI

struct DetailPage<Details: View>: View {
    let item: any SharedListItem
    let addedBy: String
    let symbol: String
    let isEditing: Bool
    let saveErrorMessage: String?
    @Binding var draft: ItemDraft
    let focusedField: FocusState<ItemDraftField?>.Binding
    let onEdit: (ItemDraftField) -> Void
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

                    DetailSectionCard(
                        title: "A note for later",
                        symbol: "text.quote",
                        accent: accent
                    ) {
                        if isEditing {
                            TextField("Add a note…", text: $draft.notes, axis: .vertical)
                                .font(DocketDetailTheme.Notes.font)
                                .foregroundStyle(DocketDetailTheme.Notes.color)
                                .lineSpacing(DocketDetailTheme.Notes.lineSpacing)
                                .lineLimit(3...8)
                                .textFieldStyle(.plain)
                                .focused(focusedField, equals: .notes)
                        } else if let notes = item.notes, !notes.isEmpty {
                            Text(notes)
                                .font(DocketDetailTheme.Notes.font)
                                .foregroundStyle(DocketDetailTheme.Notes.color)
                                .lineSpacing(DocketDetailTheme.Notes.lineSpacing)
                        } else {
                            Text("Tap to add a note…")
                                .font(DocketDetailTheme.Empty.font)
                                .foregroundStyle(DocketDetailTheme.Empty.color)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if !isEditing { onEdit(.notes) }
                    }
                    .accessibilityAddTraits(isEditing ? [] : .isButton)

                    if let saveErrorMessage {
                        DetailSectionCard(
                            title: "Couldn't save",
                            symbol: "exclamationmark.triangle.fill",
                            accent: DocketDetailTheme.Edit.errorColor
                        ) {
                            Text(saveErrorMessage)
                                .font(DocketDetailTheme.Fact.labelFont)
                                .foregroundStyle(DocketDetailTheme.Edit.errorColor)
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
                if isEditing {
                    Picker("Status", selection: $draft.status) {
                        ForEach(ItemStatus.allCases, id: \.self) { status in
                            Text(status.label).tag(status)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .tint(draft.status.chipColor)
                } else {
                    StatusChip(status: item.status)
                        .contentShape(Rectangle())
                        .onTapGesture { onEdit(.status) }
                }
            }

            if isEditing {
                TextField("Title", text: $draft.title, axis: .vertical)
                    .font(DocketDetailTheme.Hero.titleFont)
                    .foregroundStyle(DocketDetailTheme.Hero.titleColor)
                    .textFieldStyle(.plain)
                    .focused(focusedField, equals: .title)
            } else {
                Text(item.title)
                    .font(DocketDetailTheme.Hero.titleFont)
                    .foregroundStyle(DocketDetailTheme.Hero.titleColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentShape(Rectangle())
                    .onTapGesture { onEdit(.title) }
                    .accessibilityAddTraits(.isButton)
            }

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
