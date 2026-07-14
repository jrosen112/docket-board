import SwiftUI

struct ProfileSettingsView: View {
    @Environment(BoardStore.self) private var store
    @Environment(\.docketSurfacePalette) private var palette

    @State private var stats: ProfileStats?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isEditingName = false

    private var profileName: String {
        store.currentProfile?.displayName ?? "Your Profile"
    }

    private var initials: String {
        guard let profile = store.currentProfile else { return "?" }
        return [profile.firstName.first, profile.lastName.first]
            .compactMap { $0 }
            .map(String.init)
            .joined()
            .uppercased()
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(DocketTheme.boardBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: DocketTheme.ProfileSettings.sectionSpacing) {
                    identityCard
                    statsContent
                }
                .frame(maxWidth: DocketTheme.ProfileSettings.maxContentWidth)
                .padding(.horizontal, DocketTheme.ProfileSettings.horizontalPadding)
                .padding(.vertical, DocketTheme.ProfileSettings.verticalPadding)
                .frame(maxWidth: .infinity)
            }
            .refreshable { await loadStats() }
        }
        .navigationTitle("Profile & Stats")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(DocketTheme.ink, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await loadStats() }
        .sheet(isPresented: $isEditingName) {
            if let profile = store.currentProfile {
                ProfileNameEditorView(
                    firstName: profile.firstName,
                    lastName: profile.lastName
                )
            }
        }
    }

    private var identityCard: some View {
        HStack(spacing: DocketTheme.ProfileSettings.cardSpacing) {
            Text(initials)
                .font(DocketTheme.ProfileSettings.avatarFont)
                .foregroundStyle(DocketTheme.ink)
                .frame(
                    width: DocketTheme.ProfileSettings.avatarSize,
                    height: DocketTheme.ProfileSettings.avatarSize
                )
                .background(DocketTheme.brass, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(profileName)
                    .font(DocketTheme.ProfileSettings.nameFont)
                    .foregroundStyle(palette.primaryText)
                Label("Synced with iCloud", systemImage: "icloud.fill")
                    .font(DocketTheme.ProfileSettings.supportingFont)
                    .foregroundStyle(palette.secondaryText)
            }

            Spacer(minLength: 10)

            Button("Edit") { isEditingName = true }
                .buttonStyle(.borderedProminent)
                .tint(DocketTheme.brass)
                .foregroundStyle(DocketTheme.ink)
        }
        .padding(DocketTheme.ProfileSettings.cardPadding)
        .background(
            palette.raisedPaper,
            in: RoundedRectangle(
                cornerRadius: DocketTheme.ProfileSettings.cardCornerRadius,
                style: .continuous
            )
        )
        .overlay(alignment: .top) { pin }
        .shadow(
            color: DocketTheme.ProfileSettings.shadowColor,
            radius: DocketTheme.ProfileSettings.shadowRadius,
            y: DocketTheme.ProfileSettings.shadowY
        )
    }

    @ViewBuilder
    private var statsContent: some View {
        if isLoading && stats == nil {
            VStack(spacing: 12) {
                ProgressView()
                    .tint(DocketTheme.brass)
                Text("Gathering your boards…")
                    .font(.subheadline)
                    .foregroundStyle(DocketTheme.cream.opacity(0.65))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 44)
        } else if let stats {
            statsGrid(stats)
            favoriteCard(stats)
            boardBreakdown(stats)
        } else if let errorMessage {
            ContentUnavailableView {
                Label("Stats unavailable", systemImage: "icloud.slash")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("Try Again") { Task { await loadStats() } }
                    .docketPrimaryActionStyle()
            }
            .foregroundStyle(DocketTheme.cream)
        }
    }

    private func statsGrid(_ stats: ProfileStats) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: DocketTheme.ProfileSettings.gridSpacing),
                GridItem(.flexible())
            ],
            spacing: DocketTheme.ProfileSettings.gridSpacing
        ) {
            statTile(value: stats.itemCount, label: "Your pins", symbol: "pin.fill")
            statTile(value: stats.wantToGoCount, label: "Want to go", symbol: "sparkles")
            statTile(value: stats.plannedCount, label: "Planned", symbol: "calendar")
            statTile(value: stats.completedCount, label: "Done", symbol: "checkmark.circle.fill")
        }
    }

    private func statTile(value: Int, label: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DocketTheme.brass)
            Text(value.formatted())
                .font(DocketTheme.ProfileSettings.statValueFont)
                .foregroundStyle(palette.primaryText)
            Text(label)
                .font(DocketTheme.ProfileSettings.statLabelFont)
                .foregroundStyle(palette.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DocketTheme.ProfileSettings.tilePadding)
        .background(
            palette.raisedPaper,
            in: RoundedRectangle(
                cornerRadius: DocketTheme.ProfileSettings.tileCornerRadius,
                style: .continuous
            )
        )
    }

    private func favoriteCard(_ stats: ProfileStats) -> some View {
        HStack(spacing: 13) {
            Image(systemName: "heart.fill")
                .font(.title3)
                .foregroundStyle(DocketTheme.brass)

            VStack(alignment: .leading, spacing: 3) {
                Text("MOST PINNED")
                    .font(.caption2.weight(.bold))
                    .tracking(1.1)
                    .foregroundStyle(palette.secondaryText)
                Text(stats.favoriteCategory?.label ?? "Pin something to find out")
                    .font(DocketTheme.ProfileSettings.headingFont)
                    .foregroundStyle(palette.primaryText)
            }
            Spacer()
        }
        .padding(DocketTheme.ProfileSettings.cardPadding)
        .background(
            palette.raisedPaper,
            in: RoundedRectangle(
                cornerRadius: DocketTheme.ProfileSettings.cardCornerRadius,
                style: .continuous
            )
        )
    }

    private func boardBreakdown(_ stats: ProfileStats) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Across your boards")
                    .font(DocketTheme.ProfileSettings.headingFont)
                    .foregroundStyle(palette.primaryText)
                Spacer()
                Text("\(stats.loadedBoardCount) of \(stats.boardCount)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.secondaryText)
            }

            ForEach(Array(stats.boards.enumerated()), id: \.element.id) { index, board in
                if index > 0 {
                    Divider().overlay(palette.secondaryText.opacity(0.2))
                }
                HStack {
                    Text(board.title)
                        .foregroundStyle(palette.primaryText)
                    Spacer()
                    Text("\(board.itemCount) \(board.itemCount == 1 ? "pin" : "pins")")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.secondaryText)
                }
            }

            if stats.unavailableBoardCount > 0 {
                Label(
                    "\(stats.unavailableBoardCount) board \(stats.unavailableBoardCount == 1 ? "was" : "were") temporarily unavailable.",
                    systemImage: "exclamationmark.icloud.fill"
                )
                .font(DocketTheme.ProfileSettings.supportingFont)
                .foregroundStyle(DocketTheme.ProfileSettings.warningColor)
            }
        }
        .padding(DocketTheme.ProfileSettings.cardPadding)
        .background(
            palette.raisedPaper,
            in: RoundedRectangle(
                cornerRadius: DocketTheme.ProfileSettings.cardCornerRadius,
                style: .continuous
            )
        )
        .overlay(alignment: .top) { pin }
        .shadow(
            color: DocketTheme.ProfileSettings.shadowColor,
            radius: DocketTheme.ProfileSettings.shadowRadius,
            y: DocketTheme.ProfileSettings.shadowY
        )
    }

    private var pin: some View {
        Circle()
            .fill(DocketTheme.brass)
            .frame(
                width: DocketTheme.ProfileSettings.pinSize,
                height: DocketTheme.ProfileSettings.pinSize
            )
            .shadow(color: .black.opacity(0.3), radius: 1.5, y: 1)
            .offset(y: DocketTheme.ProfileSettings.pinOffsetY)
    }

    private func loadStats() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        switch await store.loadProfileStats() {
        case .loaded(let loaded): stats = loaded
        case .failed(let message): errorMessage = message
        }
        isLoading = false
    }
}

private struct ProfileNameEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(BoardStore.self) private var store
    @Environment(\.docketSurfacePalette) private var palette

    @State private var firstName: String
    @State private var lastName: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field { case firstName, lastName }

    init(firstName: String, lastName: String) {
        _firstName = State(initialValue: firstName)
        _lastName = State(initialValue: lastName)
    }

    private var canSave: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Rectangle()
                    .fill(DocketTheme.boardBackground)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("This updates how your name appears on every board and every item you’ve pinned.")
                            .font(.subheadline)
                            .foregroundStyle(palette.secondaryText)

                        TextField("First name", text: $firstName)
                            .textContentType(.givenName)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.next)
                            .focused($focusedField, equals: .firstName)
                            .onSubmit { focusedField = .lastName }

                        TextField("Last name (optional)", text: $lastName)
                            .textContentType(.familyName)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.done)
                            .focused($focusedField, equals: .lastName)
                            .onSubmit(save)
                    }
                    .textFieldStyle(.roundedBorder)
                    .padding(DocketTheme.ProfileSettings.cardPadding)
                    .background(
                        palette.raisedPaper,
                        in: RoundedRectangle(
                            cornerRadius: DocketTheme.ProfileSettings.cardCornerRadius,
                            style: .continuous
                        )
                    )

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(DocketTheme.ProfileSettings.warningColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Spacer()
                }
                .padding(DocketTheme.ProfileSettings.horizontalPadding)
                .padding(.top, DocketTheme.ProfileSettings.verticalPadding)
            }
            .navigationTitle("Edit Name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DocketTheme.ink, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: save) {
                        if isSaving { ProgressView() } else { Text("Save") }
                    }
                    .disabled(!canSave)
                }
            }
            .task { focusedField = .firstName }
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled(isSaving)
    }

    private func save() {
        guard canSave else { return }
        focusedField = nil
        errorMessage = nil
        isSaving = true
        Task {
            switch await store.updateCurrentUserName(
                firstName: firstName,
                lastName: lastName
            ) {
            case .updated:
                dismiss()
            case .partiallyUpdated(let count, let failedBoards):
                let names = failedBoards.joined(separator: ", ")
                errorMessage = "Updated on \(count) boards. Couldn’t update: \(names). Try saving again."
            case .failed(let message):
                errorMessage = message
            }
            isSaving = false
        }
    }
}
