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
                    LazyVStack(spacing: DocketTheme.BoardManager.cardSpacing) {
                        if let errorMessage = store.errorMessage {
                            ErrorBanner(message: errorMessage) {
                                store.errorMessage = nil
                            }
                        }

                        ForEach(store.spaces) { space in
                            boardCard(space)
                        }
                    }
                    .frame(maxWidth: DocketTheme.BoardManager.maxContentWidth)
                    .padding(.horizontal, DocketTheme.BoardManager.horizontalPadding)
                    .padding(.vertical, DocketTheme.BoardManager.verticalPadding)
                    .frame(maxWidth: .infinity)
                }
                .refreshable { await reloadSnapshots() }
            }
            .navigationTitle("Boards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DocketTheme.ink, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreateBoard = true
                    } label: {
                        Label("New Board", systemImage: "plus")
                    }
                    .disabled(isBusy)
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
        .presentationDetents([.large])
    }

    @ViewBuilder
    private func boardCard(_ space: Space) -> some View {
        let snapshot = snapshots[space.id]
        VStack(alignment: .leading, spacing: DocketTheme.BoardManager.headerSpacing) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: space.isOwned ? "person.crop.circle.fill" : "person.2.fill")
                    .font(.title3)
                    .foregroundStyle(DocketTheme.brass)
                    .frame(
                        width: DocketTheme.BoardManager.iconSize,
                        height: DocketTheme.BoardManager.iconSize
                    )
                    .background(
                        DocketTheme.brass.opacity(0.13),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(space.title)
                            .font(DocketTheme.BoardManager.titleFont)
                            .foregroundStyle(palette.primaryText)
                            .lineLimit(2)

                        if space == store.space {
                            Text("CURRENT")
                                .font(DocketTheme.BoardManager.currentFont)
                                .foregroundStyle(DocketTheme.ink)
                                .padding(.horizontal, DocketTheme.BoardManager.currentHorizontalPadding)
                                .padding(.vertical, DocketTheme.BoardManager.currentVerticalPadding)
                                .background(
                                    DocketTheme.brass,
                                    in: RoundedRectangle(
                                        cornerRadius: DocketTheme.BoardManager.currentCornerRadius,
                                        style: .continuous
                                    )
                                )
                        }
                    }

                    Text(space.isOwned ? "Owned by you" : "Shared with you")
                        .font(DocketTheme.BoardManager.roleFont)
                        .foregroundStyle(palette.secondaryText)
                }

                Spacer(minLength: 8)

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
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(palette.secondaryText)
                }
                .disabled(isBusy)
            }

            metadata(for: snapshot)

            HStack(spacing: DocketTheme.BoardManager.actionSpacing) {
                Button {
                    openBoard(space)
                } label: {
                    HStack {
                        if switchingBoardID == space.id {
                            ProgressView()
                        } else {
                            Image(systemName: space == store.space ? "checkmark" : "arrow.right")
                        }
                        Text(space == store.space ? "View Board" : "Open Board")
                    }
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
        .padding(DocketTheme.BoardManager.cardPadding)
        .background(
            palette.raisedPaper,
            in: RoundedRectangle(
                cornerRadius: DocketTheme.BoardManager.cardCornerRadius,
                style: .continuous
            )
        )
        .shadow(
            color: palette.shadow,
            radius: DocketTheme.BoardManager.shadowRadius,
            y: DocketTheme.BoardManager.shadowY
        )
        .opacity(deletingBoardID == space.id ? 0.55 : 1)
    }

    @ViewBuilder
    private func metadata(for snapshot: BoardManagementSnapshot?) -> some View {
        if let snapshot {
            if snapshot.isAvailable {
                VStack(alignment: .leading, spacing: DocketTheme.BoardManager.metadataSpacing) {
                    Label(
                        "\(snapshot.itemCount) \(snapshot.itemCount == 1 ? "pin" : "pins")",
                        systemImage: "pin.fill"
                    )
                    Label(participantSummary(snapshot), systemImage: "person.2.fill")
                }
                .font(DocketTheme.BoardManager.metadataFont)
                .foregroundStyle(palette.secondaryText)
            } else {
                Label("Board details are temporarily unavailable", systemImage: "icloud.slash")
                    .font(DocketTheme.BoardManager.metadataFont)
                    .foregroundStyle(DocketTheme.BoardManager.unavailableColor)
            }
        } else if isLoading {
            HStack(spacing: 8) {
                ProgressView()
                Text("Loading board details…")
            }
            .font(DocketTheme.BoardManager.metadataFont)
            .foregroundStyle(palette.secondaryText)
        }
    }

    private var isBusy: Bool {
        switchingBoardID != nil || preparingShareID != nil || deletingBoardID != nil
    }

    private func participantSummary(_ snapshot: BoardManagementSnapshot) -> String {
        guard !snapshot.participantNames.isEmpty else { return "No participant profiles yet" }
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
