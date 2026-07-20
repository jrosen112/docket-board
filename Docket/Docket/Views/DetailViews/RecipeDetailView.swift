import SwiftUI

struct RecipeDetailView: View {
    @Environment(\.docketSurfacePalette) private var palette

    let recipe: Recipe
    let addedBy: String
    let isEditing: Bool
    let allowsCategorySelection: Bool
    let saveErrorMessage: String?
    @Binding var draft: ItemDraft
    let focusedField: FocusState<ItemDraftField?>.Binding
    let onEdit: (ItemDraftField) -> Void

    @State private var checkedIngredients: Set<Int> = []

    var body: some View {
        DetailPage(
            item: recipe,
            addedBy: addedBy,
            symbol: "book.pages.fill",
            isEditing: isEditing,
            allowsCategorySelection: allowsCategorySelection,
            saveErrorMessage: saveErrorMessage,
            draft: $draft,
            focusedField: focusedField,
            onEdit: onEdit
        ) {
            if isEditing {
                editingFields
            } else {
                displayFields
            }
        }
    }

    private var editingFields: some View {
        VStack(alignment: .leading, spacing: 4) {
            DetailEditField(
                symbol: "link",
                label: "Recipe link",
                placeholder: "Instagram, TikTok, or website URL",
                field: .sourceURL,
                accent: recipe.category.accent,
                text: $draft.sourceURL,
                focusedField: focusedField,
                keyboardType: .URL
            )

            Divider().opacity(0.5)

            RecipeMultilineEditField(
                symbol: "cart.fill",
                label: "Shopping list",
                placeholder: "One ingredient per line",
                field: .ingredients,
                accent: recipe.category.accent,
                text: $draft.ingredients,
                focusedField: focusedField
            )

            Divider().opacity(0.5)

            RecipeMultilineEditField(
                symbol: "list.number",
                label: "Instructions",
                placeholder: "One step per line",
                field: .instructions,
                accent: recipe.category.accent,
                text: $draft.instructions,
                focusedField: focusedField
            )
        }
    }

    private var displayFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            sourceRow

            Divider().opacity(0.5)

            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("Shopping list", symbol: "cart.fill")

                if recipe.ingredients.isEmpty {
                    emptyButton("Tap to add ingredients", field: .ingredients)
                } else {
                    ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { index, ingredient in
                        Button {
                            if checkedIngredients.contains(index) {
                                checkedIngredients.remove(index)
                            } else {
                                checkedIngredients.insert(index)
                            }
                        } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Image(
                                    systemName: checkedIngredients.contains(index)
                                        ? "checkmark.circle.fill"
                                        : "circle"
                                )
                                .foregroundStyle(recipe.category.accent)

                                Text(ingredient)
                                    .font(DocketDetailTheme.Fact.valueFont)
                                    .foregroundStyle(palette.primaryText)
                                    .strikethrough(checkedIngredients.contains(index))
                                    .opacity(checkedIngredients.contains(index) ? 0.55 : 1)

                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Divider().opacity(0.5)

            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("Instructions", symbol: "list.number")

                if recipe.instructions.isEmpty {
                    emptyButton("Tap to add instructions", field: .instructions)
                } else {
                    ForEach(Array(recipe.instructions.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 11) {
                            Text("\(index + 1)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(recipe.category.accent, in: Circle())

                            Text(step)
                                .font(DocketDetailTheme.Fact.valueFont)
                                .foregroundStyle(palette.primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var sourceRow: some View {
        if let url = recipe.sourceLink {
            Link(destination: url) {
                HStack(spacing: DocketDetailTheme.Fact.rowSpacing) {
                    Image(systemName: sourceSymbol(for: url))
                        .font(DocketDetailTheme.Fact.symbolFont)
                        .foregroundStyle(recipe.category.accent)
                        .frame(width: DocketDetailTheme.Fact.symbolWidth)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Recipe link")
                            .font(DocketDetailTheme.Fact.labelFont)
                            .foregroundStyle(palette.secondaryText)
                        Text(sourceLabel(for: url))
                            .font(DocketDetailTheme.Fact.valueFont)
                            .foregroundStyle(palette.primaryText)
                    }

                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(recipe.category.accent)
                }
                .padding(.vertical, DocketDetailTheme.Fact.verticalPadding)
            }
        } else {
            DetailFactRow(
                symbol: "link",
                label: "Recipe link",
                value: recipe.sourceURL ?? "Add link",
                accent: recipe.category.accent,
                isPlaceholder: recipe.sourceURL == nil,
                onTap: { onEdit(.sourceURL) }
            )
        }
    }

    private func sectionLabel(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(DocketDetailTheme.Fact.labelFont)
            .foregroundStyle(palette.secondaryText)
    }

    private func emptyButton(_ title: String, field: ItemDraftField) -> some View {
        Button(title) { onEdit(field) }
            .font(DocketDetailTheme.Empty.font)
            .foregroundStyle(palette.mutedText)
            .buttonStyle(.plain)
    }

    private func sourceLabel(for url: URL) -> String {
        let host = url.host?.lowercased() ?? ""
        if host.contains("instagram.com") { return "Open in Instagram" }
        if host.contains("tiktok.com") { return "Open in TikTok" }
        return "Open original recipe"
    }

    private func sourceSymbol(for url: URL) -> String {
        let host = url.host?.lowercased() ?? ""
        return host.contains("instagram.com") || host.contains("tiktok.com")
            ? "play.rectangle.fill"
            : "safari.fill"
    }
}

private struct RecipeMultilineEditField: View {
    @Environment(\.docketSurfacePalette) private var palette

    let symbol: String
    let label: String
    let placeholder: String
    let field: ItemDraftField
    let accent: Color
    @Binding var text: String
    let focusedField: FocusState<ItemDraftField?>.Binding

    var body: some View {
        HStack(alignment: .top, spacing: DocketDetailTheme.Fact.rowSpacing) {
            Image(systemName: symbol)
                .font(DocketDetailTheme.Fact.symbolFont)
                .foregroundStyle(accent)
                .frame(width: DocketDetailTheme.Fact.symbolWidth)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: DocketDetailTheme.Edit.fieldSpacing) {
                Text(label)
                    .font(DocketDetailTheme.Edit.labelFont)
                    .foregroundStyle(palette.mutedText)

                TextField(placeholder, text: $text, axis: .vertical)
                    .font(DocketDetailTheme.Edit.inputFont)
                    .foregroundStyle(palette.primaryText)
                    .textFieldStyle(.plain)
                    .lineLimit(3...12)
                    .focused(focusedField, equals: field)
            }
        }
        .padding(.vertical, DocketDetailTheme.Edit.fieldVerticalPadding)
        .id(field)
    }
}
