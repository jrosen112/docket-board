import SwiftUI

struct BoardManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.docketSurfacePalette) private var palette
    @Environment(BoardStore.self) private var store

    @State private var snapshots: [String: BoardManagementSnapshot] = [:]
    @State private var isLoading = true
    @State private var switchingBoardID: String?
    @State private var preparingShareID: String?
    @State private var deletingBoardID: String?
    @State private var deleteCandidate: Space?
    @State private var sharingSpace: Space?
    @State private var showingSharing = false
    @State private var showingCreateBoard = false

    var body: some View {
        NavigationStack {
            ZStack {
                Rectangle()
                    .fill(DocketTheme.boardBackground)
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DocketTheme.BoardManager.sectionSpacing) {
                        intro

                        if let errorMessage = store.errorMessage {
                            ErrorBanner(message: errorMessage) {
                                store.errorMessage = nil
                            }
                        }

                        sectionLabel("CURRENT BOARD")
                        activeBoardCard(store.space)

                        if !otherSpaces.isEmpty {
                            sectionLabel("OTHER BOARDS")

                            VStack(spacing: DocketTheme.BoardManager.rowSpacing) {
                                ForEach(otherSpaces) { space in
                                    boardRow(space)
                                }
                            }
                        }

                        createBoardButton
                    }
                    .frame(maxWidth: DocketTheme.BoardManager.maxContentWidth)
                    .padding(.horizontal, DocketTheme.BoardManager.horizontalPadding)
                    .padding(.top, DocketTheme.BoardManager.topPadding)
                    .padding(.bottom, DocketTheme.BoardManager.bottomPadding)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .refreshable { await reloadSnapshots() }
            }
            .navigationTitle("Boards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DocketTheme.ink, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task(id: store.spaces.map(\.id)) {
                await reloadSnapshots()
            }
            .sheet(isPresented: $showingCreateBoard) {
                CreateBoardView()
            }
            .sheet(
                isPresented: $showingSharing,
                onDismiss: {
                    store.clearPreparedShare()
                    sharingSpace = nil
                }
            ) {
                if let share = store.activeShare, let sharingSpace {
                    CloudSharingSheet(
                        share: share,
                        container: store.container,
                        onShareSaved: {
                            Task { await reloadSnapshots() }
                        },
                        onStoppedSharing: {
                            showingSharing = false
                            Task {
                                if !sharingSpace.isOwned {
                                    await store.finishLeavingBoard(sharingSpace)
                                }
                                await reloadSnapshots()
                            }
                        },
                        onFailure: { store.errorMessage = $0 }
                    )
                }
            }
            .alert(
                "Delete Board?",
                isPresented: Binding(
                    get: { deleteCandidate != nil },
                    set: { if !$0 { deleteCandidate = nil } }
                ),
                presenting: deleteCandidate
            ) { space in
                Button("Delete “\(space.title)”", role: .destructive) {
                    deleteCandidate = nil
                    deleteBoard(space)
                }
                Button("Cancel", role: .cancel) {
                    deleteCandidate = nil
                }
            } message: { space in
                Text(
                    "This permanently deletes every pin and removes the board for all participants. This can’t be undone."
                )
            }
        }
        .tint(DocketTheme.brass)
        .presentationDetents([.large])
    }

    private var intro: some View {
        HStack(alignment: .bottom, spacing: DocketTheme.BoardManager.introSpacing) {
            VStack(alignment: .leading, spacing: DocketTheme.BoardManager.introTextSpacing) {
                Text("YOUR COLLECTION")
                    .font(DocketTheme.BoardManager.eyebrowFont)
                    .tracking(DocketTheme.BoardManager.eyebrowTracking)
                    .foregroundStyle(DocketTheme.brass)

                Text("Pick up where you left off.")
                    .font(DocketTheme.BoardManager.headingFont)
                    .foregroundStyle(DocketTheme.cream)

                Text("Switch boards, bring someone in, or make room for a new plan.")
                    .font(DocketTheme.BoardManager.supportingFont)
                    .foregroundStyle(DocketTheme.BoardManager.supportingColor)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            VStack(spacing: 1) {
                Text("\(store.spaces.count)")
                    .font(DocketTheme.BoardManager.countFont)
                Text(store.spaces.count == 1 ? "BOARD" : "BOARDS")
                    .font(DocketTheme.BoardManager.countLabelFont)
                    .tracking(DocketTheme.BoardManager.countLabelTracking)
            }
            .foregroundStyle(DocketTheme.cream)
            .frame(
                width: DocketTheme.BoardManager.countBadgeSize,
                height: DocketTheme.BoardManager.countBadgeSize
            )
            .background(DocketTheme.cream.opacity(0.08), in: Circle())
            .overlay(Circle().stroke(DocketTheme.cream.opacity(0.1)))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(store.spaces.count) \(store.spaces.count == 1 ? "board" : "boards")")
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(DocketTheme.BoardManager.sectionLabelFont)
            .tracking(DocketTheme.BoardManager.sectionLabelTracking)
            .foregroundStyle(DocketTheme.BoardManager.sectionLabelColor)
            .padding(.leading, DocketTheme.BoardManager.sectionLabelLeadingPadding)
            .accessibilityAddTraits(.isHeader)
    }

    private func activeBoardCard(_ space: Space) -> some View {
        let snapshot = snapshots[space.id]

        return VStack(alignment: .leading, spacing: DocketTheme.BoardManager.activeCardSpacing) {
            HStack(alignment: .top, spacing: DocketTheme.BoardManager.cardHeaderSpacing) {
                VStack(alignment: .leading, spacing: DocketTheme.BoardManager.titleSpacing) {
                    HStack(spacing: DocketTheme.BoardManager.statusSpacing) {
                        Image(systemName: "circle.fill")
                            .font(DocketTheme.BoardManager.liveDotFont)
                        Text("ACTIVE NOW")
                            .font(DocketTheme.BoardManager.activeLabelFont)
                            .tracking(DocketTheme.BoardManager.activeLabelTracking)
                    }
                    .foregroundStyle(DocketTheme.BoardManager.activeColor)

                    Text(space.title)
                        .font(DocketTheme.BoardManager.activeTitleFont)
                        .foregroundStyle(palette.primaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Label(
                        space.isOwned ? "Owned by you" : "Shared with you",
                        systemImage: space.isOwned ? "person.fill" : "person.2.fill"
                    )
                    .font(DocketTheme.BoardManager.roleFont)
                    .foregroundStyle(palette.secondaryText)
                }

                Spacer(minLength: DocketTheme.BoardManager.cardHeaderSpacing)
                boardMenu(for: space)
            }

            Divider()
                .overlay(palette.divider)

            activeMetadata(snapshot)

            HStack(spacing: DocketTheme.BoardManager.actionSpacing) {
                Button {
                    openBoard(space)
                } label: {
                    Label("Back to Board", systemImage: "arrow.up.right")
                        .frame(maxWidth: .infinity)
                }
                .docketPrimaryActionStyle()
                .disabled(isBusy)

                Button {
                    openPeople(for: space)
                } label: {
                    if preparingShareID == space.id {
                        ProgressView()
                    } else {
                        Label("People", systemImage: "person.2")
                    }
                }
                .docketSecondaryActionStyle()
                .disabled(isBusy)
            }
        }
        .padding(DocketTheme.BoardManager.activeCardPadding)
        .background(
            palette.raisedPaper,
            in: RoundedRectangle(
                cornerRadius: DocketTheme.BoardManager.activeCardCornerRadius,
                style: .continuous
            )
        )
        .overlay(alignment: .top) {
            Circle()
                .fill(DocketTheme.brass)
                .frame(
                    width: DocketTheme.BoardManager.pinSize,
                    height: DocketTheme.BoardManager.pinSize
                )
                .shadow(color: .black.opacity(0.28), radius: 2, y: 1)
                .offset(y: DocketTheme.BoardManager.pinOffsetY)
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: DocketTheme.BoardManager.activeCardCornerRadius,
                style: .continuous
            )
            .stroke(DocketTheme.brass.opacity(0.22), lineWidth: 1)
        }
        .shadow(
            color: palette.shadow,
            radius: DocketTheme.BoardManager.activeShadowRadius,
            y: DocketTheme.BoardManager.activeShadowY
        )
        .opacity(deletingBoardID == space.id ? 0.55 : 1)
    }

    private func boardRow(_ space: Space) -> some View {
        let snapshot = snapshots[space.id]

        return HStack(spacing: DocketTheme.BoardManager.rowContentSpacing) {
            Button {
                openBoard(space)
            } label: {
                HStack(spacing: DocketTheme.BoardManager.rowContentSpacing) {
                    Image(systemName: space.isOwned ? "rectangle.stack.fill" : "person.2.fill")
                        .font(DocketTheme.BoardManager.rowIconFont)
                        .foregroundStyle(DocketTheme.brass)
                        .frame(
                            width: DocketTheme.BoardManager.rowIconSize,
                            height: DocketTheme.BoardManager.rowIconSize
                        )
                        .background(
                            DocketTheme.brass.opacity(0.12),
                            in: RoundedRectangle(
                                cornerRadius: DocketTheme.BoardManager.rowIconCornerRadius,
                                style: .continuous
                            )
                        )

                    VStack(alignment: .leading, spacing: DocketTheme.BoardManager.rowTextSpacing) {
                        Text(space.title)
                            .font(DocketTheme.BoardManager.rowTitleFont)
                            .foregroundStyle(palette.primaryText)
                            .lineLimit(1)

                        compactMetadata(for: snapshot, space: space)
                    }

                    Spacer(minLength: 0)

                    if switchingBoardID == space.id {
                        ProgressView()
                            .tint(DocketTheme.brass)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(DocketTheme.BoardManager.chevronFont)
                            .foregroundStyle(palette.mutedText)
                    }
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .disabled(isBusy)

            boardMenu(for: space)
        }
        .padding(DocketTheme.BoardManager.rowPadding)
        .background(
            palette.raisedPaper,
            in: RoundedRectangle(
                cornerRadius: DocketTheme.BoardManager.rowCornerRadius,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: DocketTheme.BoardManager.rowCornerRadius,
                style: .continuous
            )
            .stroke(palette.divider, lineWidth: 1)
        }
        .shadow(
            color: palette.shadow.opacity(DocketTheme.BoardManager.rowShadowOpacity),
            radius: DocketTheme.BoardManager.rowShadowRadius,
            y: DocketTheme.BoardManager.rowShadowY
        )
        .opacity(deletingBoardID == space.id ? 0.55 : 1)
    }

    private var createBoardButton: some View {
        Button {
            showingCreateBoard = true
        } label: {
            HStack(spacing: DocketTheme.BoardManager.createSpacing) {
                Image(systemName: "plus")
                    .font(DocketTheme.BoardManager.createIconFont)
                    .frame(
                        width: DocketTheme.BoardManager.createIconSize,
                        height: DocketTheme.BoardManager.createIconSize
                    )
                    .background(DocketTheme.brass.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: DocketTheme.BoardManager.createTextSpacing) {
                    Text("Start a new board")
                        .font(DocketTheme.BoardManager.createTitleFont)
                        .foregroundStyle(DocketTheme.cream)
                    Text("Give a fresh set of plans its own place.")
                        .font(DocketTheme.BoardManager.createSupportingFont)
                        .foregroundStyle(DocketTheme.BoardManager.supportingColor)
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.right")
                    .font(DocketTheme.BoardManager.chevronFont)
            }
            .foregroundStyle(DocketTheme.brass)
            .padding(DocketTheme.BoardManager.createPadding)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .background(DocketTheme.cream.opacity(0.045), in: RoundedRectangle(
            cornerRadius: DocketTheme.BoardManager.createCornerRadius,
            style: .continuous
        ))
        .overlay {
            RoundedRectangle(
                cornerRadius: DocketTheme.BoardManager.createCornerRadius,
                style: .continuous
            )
            .stroke(
                DocketTheme.brass.opacity(0.38),
                style: StrokeStyle(
                    lineWidth: DocketTheme.BoardManager.createBorderWidth,
                    dash: DocketTheme.BoardManager.createBorderDash
                )
            )
        }
        .disabled(isBusy)
    }

    @ViewBuilder
    private func activeMetadata(_ snapshot: BoardManagementSnapshot?) -> some View {
        if let snapshot {
            if snapshot.isAvailable {
                HStack(spacing: DocketTheme.BoardManager.statSpacing) {
                    stat(
                        value: "\(snapshot.itemCount)",
                        label: snapshot.itemCount == 1 ? "PIN" : "PINS",
                        symbol: "pin.fill"
                    )
                    stat(
                        value: "\(snapshot.participantCount)",
                        label: snapshot.participantCount == 1 ? "PERSON" : "PEOPLE",
                        symbol: "person.2.fill"
                    )

                    Spacer(minLength: 0)

                    if snapshot.participantCount > 0 {
                        Text(participantSummary(snapshot))
                            .font(DocketTheme.BoardManager.participantFont)
                            .foregroundStyle(palette.secondaryText)
                            .lineLimit(2)
                            .multilineTextAlignment(.trailing)
                    }
                }
            } else {
                unavailableMetadata
            }
        } else if isLoading {
            loadingMetadata
        }
    }

    private func stat(value: String, label: String, symbol: String) -> some View {
        HStack(spacing: DocketTheme.BoardManager.statContentSpacing) {
            Image(systemName: symbol)
                .font(DocketTheme.BoardManager.statIconFont)
                .foregroundStyle(DocketTheme.brass)

            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(DocketTheme.BoardManager.statValueFont)
                    .foregroundStyle(palette.primaryText)
                Text(label)
                    .font(DocketTheme.BoardManager.statLabelFont)
                    .tracking(DocketTheme.BoardManager.statLabelTracking)
                    .foregroundStyle(palette.mutedText)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) \(label.lowercased())")
    }

    @ViewBuilder
    private func compactMetadata(for snapshot: BoardManagementSnapshot?, space: Space) -> some View {
        if let snapshot {
            if snapshot.isAvailable {
                Text(compactSummary(snapshot, space: space))
                    .font(DocketTheme.BoardManager.metadataFont)
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(1)
            } else {
                Label("Details unavailable", systemImage: "icloud.slash")
                    .font(DocketTheme.BoardManager.metadataFont)
                    .foregroundStyle(DocketTheme.BoardManager.unavailableColor)
            }
        } else if isLoading {
            HStack(spacing: DocketTheme.BoardManager.loadingSpacing) {
                ProgressView()
                    .controlSize(.mini)
                Text("Loading details…")
            }
            .font(DocketTheme.BoardManager.metadataFont)
            .foregroundStyle(palette.secondaryText)
        } else {
            Text(space.isOwned ? "Owned by you" : "Shared with you")
                .font(DocketTheme.BoardManager.metadataFont)
                .foregroundStyle(palette.secondaryText)
        }
    }

    private var loadingMetadata: some View {
        HStack(spacing: DocketTheme.BoardManager.loadingSpacing) {
            ProgressView()
            Text("Loading board details…")
        }
        .font(DocketTheme.BoardManager.metadataFont)
        .foregroundStyle(palette.secondaryText)
    }

    private var unavailableMetadata: some View {
        Label("Board details are temporarily unavailable", systemImage: "icloud.slash")
            .font(DocketTheme.BoardManager.metadataFont)
            .foregroundStyle(DocketTheme.BoardManager.unavailableColor)
    }

    private func boardMenu(for space: Space) -> some View {
        Menu {
            Button {
                openPeople(for: space)
            } label: {
                Label(
                    space.isOwned ? "People & Invitations" : "People & Leave Board",
                    systemImage: "person.2"
                )
            }

            if space.isOwned {
                Divider()
                Button(role: .destructive) {
                    deleteCandidate = space
                } label: {
                    Label("Delete Board", systemImage: "trash")
                }
                .disabled(store.spaces.count <= 1)
            }
        } label: {
            if preparingShareID == space.id {
                ProgressView()
            } else {
                Image(systemName: "ellipsis")
                    .font(DocketTheme.BoardManager.menuFont)
                    .foregroundStyle(palette.secondaryText)
                    .frame(
                        width: DocketTheme.BoardManager.menuSize,
                        height: DocketTheme.BoardManager.menuSize
                    )
                    .background(palette.divider.opacity(0.55), in: Circle())
                    .contentShape(Circle())
            }
        }
        .disabled(isBusy)
        .accessibilityLabel("More options for \(space.title)")
    }

    private var otherSpaces: [Space] {
        store.spaces.filter { $0 != store.space }
    }

    private var isBusy: Bool {
        switchingBoardID != nil || preparingShareID != nil || deletingBoardID != nil
    }

    private func compactSummary(_ snapshot: BoardManagementSnapshot, space: Space) -> String {
        let role = space.isOwned ? "Yours" : "Shared"
        let pins = "\(snapshot.itemCount) \(snapshot.itemCount == 1 ? "pin" : "pins")"
        let people = "\(snapshot.participantCount) \(snapshot.participantCount == 1 ? "person" : "people")"
        return "\(role)  ·  \(pins)  ·  \(people)"
    }

    private func participantSummary(_ snapshot: BoardManagementSnapshot) -> String {
        guard !snapshot.participantNames.isEmpty else {
            return snapshot.participantCount == 1
                ? "1 iCloud participant"
                : "\(snapshot.participantCount) iCloud participants"
        }
        if snapshot.participantNames.count < snapshot.participantCount {
            let visible = snapshot.participantNames.prefix(3).joined(separator: ", ")
            return "\(visible) +\(snapshot.participantCount - snapshot.participantNames.count)"
        }
        if snapshot.participantNames.count <= 3 {
            return snapshot.participantNames.joined(separator: ", ")
        }
        let visible = snapshot.participantNames.prefix(3).joined(separator: ", ")
        return "\(visible) +\(snapshot.participantNames.count - 3)"
    }

    private func reloadSnapshots() async {
        isLoading = snapshots.isEmpty
        let loaded = await store.loadBoardManagementSnapshots()
        snapshots = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
        isLoading = false
    }

    private func openBoard(_ space: Space) {
        guard !isBusy else { return }
        if space == store.space {
            dismiss()
            return
        }
        switchingBoardID = space.id
        Task {
            await store.switchTo(space: space)
            switchingBoardID = nil
            if store.space == space { dismiss() }
        }
    }

    private func openPeople(for space: Space) {
        guard !isBusy else { return }
        preparingShareID = space.id
        Task {
            if await store.prepareShare(for: space) {
                sharingSpace = space
                showingSharing = true
            }
            preparingShareID = nil
        }
    }

    private func deleteBoard(_ space: Space) {
        guard !isBusy else { return }
        deletingBoardID = space.id
        Task {
            if await store.deleteBoard(space) {
                await reloadSnapshots()
            }
            deletingBoardID = nil
        }
    }
}

#Preview {
    BoardManagerView()
        .environment(BoardStore())
}
