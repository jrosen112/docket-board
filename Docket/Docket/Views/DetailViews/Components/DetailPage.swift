import CloudKit
import SwiftUI

struct DetailPage<Details: View>: View {
    @Environment(\.docketSurfacePalette) private var palette

    let item: any SharedListItem
    let addedBy: String
    let symbol: String
    let isEditing: Bool
    let allowsCategorySelection: Bool
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

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: DocketDetailTheme.Page.sectionSpacing) {
                        hero

                        DetailSectionCard(
                            title: "The particulars",
                            symbol: symbol,
                            accent: accent,
                            rotationDegrees: sectionRotation(for: "particulars")
                        ) {
                            details
                        }

                        DetailSectionCard(
                            title: "A note for later",
                            symbol: "text.quote",
                            accent: accent,
                            rotationDegrees: sectionRotation(for: "notes")
                        ) {
                            if isEditing {
                                TextField("Add a note…", text: $draft.notes, axis: .vertical)
                                    .font(DocketDetailTheme.Notes.font)
                                    .foregroundStyle(palette.bodyText)
                                    .lineSpacing(DocketDetailTheme.Notes.lineSpacing)
                                    .lineLimit(3...8)
                                    .textFieldStyle(.plain)
                                    .focused(focusedField, equals: .notes)
                                    .id(ItemDraftField.notes)
                            } else if let notes = item.notes, !notes.isEmpty {
                                Text(notes)
                                    .font(DocketDetailTheme.Notes.font)
                                    .foregroundStyle(palette.bodyText)
                                    .lineSpacing(DocketDetailTheme.Notes.lineSpacing)
                            } else {
                                Text("Tap to add a note…")
                                    .font(DocketDetailTheme.Empty.font)
                                    .foregroundStyle(palette.mutedText)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if !isEditing { onEdit(.notes) }
                        }
                        .accessibilityAddTraits(isEditing ? [] : .isButton)

                        if isEditing || item.photoData != nil {
                            boardPhotoSection
                        }

                        if let saveErrorMessage {
                            DetailSectionCard(
                                title: "Couldn't save",
                                symbol: "exclamationmark.triangle.fill",
                                accent: DocketDetailTheme.Edit.errorColor,
                                rotationDegrees: sectionRotation(for: "save-error")
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
                .onChange(of: focusedField.wrappedValue) { _, field in
                    guard let field else { return }
                    reveal(field, using: proxy)
                }
            }
        }
    }

    private func sectionRotation(for section: String) -> Double {
        DocketTheme.rotationDegrees(
            for: "\(item.id.recordName).detail.\(section)"
        ) * DocketDetailTheme.Card.rotationScale
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: DocketDetailTheme.Hero.contentSpacing) {
            if isEditing {
                ItemPhotoEditor(
                    photoData: $draft.photoData,
                    showsPhotoOnBoard: $draft.showsPhotoOnBoard,
                    accent: accent
                )
            } else if let photoData = item.photoData {
                ItemPhotoImage(data: photoData, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: DocketDetailTheme.Photo.detailMaximumHeight)
                    .background(DocketTheme.ink.opacity(0.08))
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: DocketDetailTheme.Photo.cornerRadius,
                            style: .continuous
                        )
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { onEdit(.photo) }
                    .accessibilityLabel("Item photo")
                    .accessibilityHint("Double tap to edit")
                    .accessibilityAddTraits(.isButton)
            }

            HStack(alignment: .center, spacing: DocketDetailTheme.Hero.headerSpacing) {
                Image(systemName: symbol)
                    .font(DocketDetailTheme.Hero.symbolFont)
                    .foregroundStyle(DocketDetailTheme.Hero.symbolForeground)
                    .frame(
                        width: DocketDetailTheme.Hero.symbolSize,
                        height: DocketDetailTheme.Hero.symbolSize
                    )
                    .background(Circle().fill(accent))

                if isEditing && allowsCategorySelection {
                    Picker(selection: $draft.category) {
                        ForEach(ItemCategory.supported, id: \.self) { category in
                            Text(category.label).tag(category)
                        }
                    } label: {
                        HStack(spacing: DocketDetailTheme.Edit.fieldSpacing) {
                            Text(draft.category.label.uppercased())
                            Image(systemName: "chevron.up.chevron.down")
                        }
                        .font(DocketDetailTheme.Hero.categoryFont)
                        .tracking(DocketDetailTheme.Hero.categoryTracking)
                        .foregroundStyle(accent)
                    }
                    .pickerStyle(.menu)
                    .tint(accent)
                } else {
                    Text(item.category.label.uppercased())
                        .font(DocketDetailTheme.Hero.categoryFont)
                        .tracking(DocketDetailTheme.Hero.categoryTracking)
                        .foregroundStyle(accent)
                }

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
                    .foregroundStyle(palette.primaryText)
                    .textFieldStyle(.plain)
                    .focused(focusedField, equals: .title)
                    .id(ItemDraftField.title)
            } else {
                Text(item.title)
                    .font(DocketDetailTheme.Hero.titleFont)
                    .foregroundStyle(palette.primaryText)
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
            .foregroundStyle(palette.mutedText)
        }
        .padding(DocketDetailTheme.Hero.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DocketDetailTheme.Hero.cornerRadius)
                .fill(palette.raisedPaper)
                .shadow(
                    color: palette.shadow,
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

    private var boardPhotoSection: some View {
        DetailSectionCard(
            title: "On the board",
            symbol: "rectangle.grid.2x2.fill",
            accent: accent,
            rotationDegrees: sectionRotation(for: "board-photo")
        ) {
            if isEditing {
                Toggle(isOn: $draft.showsPhotoOnBoard) {
                    VStack(alignment: .leading, spacing: DocketDetailTheme.Photo.toggleTextSpacing) {
                        Text("Show photo on board card")
                            .font(DocketDetailTheme.Fact.valueFont)
                            .foregroundStyle(palette.primaryText)
                        Text(
                            draft.photoData == nil
                                ? "Add a photo above to turn this on."
                                : "The card uses a compact, edge-to-edge crop."
                        )
                        .font(DocketDetailTheme.Photo.supportingFont)
                        .foregroundStyle(palette.mutedText)
                    }
                }
                .tint(accent)
                .disabled(draft.photoData == nil)
            } else {
                HStack(spacing: DocketDetailTheme.Fact.rowSpacing) {
                    Image(
                        systemName: item.showsPhotoOnBoard
                            ? "photo.fill.on.rectangle.fill"
                            : "rectangle.slash"
                    )
                    .font(DocketDetailTheme.Fact.symbolFont)
                    .foregroundStyle(accent)
                    .frame(width: DocketDetailTheme.Fact.symbolWidth)

                    Text(
                        item.showsPhotoOnBoard
                            ? "Photo shown on board card"
                            : "Photo kept in details only"
                    )
                    .font(DocketDetailTheme.Fact.valueFont)
                    .foregroundStyle(palette.primaryText)

                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.mutedText)
                }
                .contentShape(Rectangle())
                .onTapGesture { onEdit(.showsPhotoOnBoard) }
                .accessibilityAddTraits(.isButton)
            }
        }
    }

    private func reveal(_ field: ItemDraftField, using proxy: ScrollViewProxy) {
        withAnimation(DocketDetailTheme.Edit.visibilityAnimation) {
            proxy.scrollTo(field, anchor: .center)
        }

        // Focus begins while edit mode and the keyboard are both animating.
        // Re-center once those layouts settle so the final keyboard height,
        // rather than the pre-edit viewport, determines what stays visible.
        Task { @MainActor in
            try? await Task.sleep(for: DocketDetailTheme.Edit.visibilityDelay)
            guard focusedField.wrappedValue == field else { return }
            withAnimation(DocketDetailTheme.Edit.visibilityAnimation) {
                proxy.scrollTo(field, anchor: .center)
            }
        }
    }
}
