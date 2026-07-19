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

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.dateTimeStyle = .named
        return formatter
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                Rectangle()
                    .fill(DocketTheme.boardBackground)
                    .ignoresSafeArea()

                List {
                    if let errorMessage = store.errorMessage {
                        ErrorBanner(message: errorMessage) {
                            store.errorMessage = nil
                        }
                        .modifier(BoardManagerRow())
                    }

                    boardCard(store.space, isActive: true)
                        .modifier(BoardManagerRow())
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            swipeButtons(for: store.space)
                        }

                    if !otherSpaces.isEmpty {
                        Text("YOUR BOARDS")
                            .font(DocketTheme.BoardManager.sectionLabelFont)
                            .tracking(DocketTheme.BoardManager.sectionLabelTracking)
                            .foregroundStyle(DocketTheme.BoardManager.sectionLabelColor)
                            .accessibilityAddTraits(.isHeader)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(
                                top: DocketTheme.BoardManager.sectionLabelTopPadding,
                                leading: DocketTheme.BoardManager.horizontalPadding
                                    + DocketTheme.BoardManager.sectionLabelLeadingPadding,
                                bottom: 0,
                                trailing: DocketTheme.BoardManager.horizontalPadding
                            ))

                        ForEach(otherSpaces) { space in
                            boardCard(space, isActive: false)
                                .modifier(BoardManagerRow())
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    swipeButtons(for: space)
                                }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .contentMargins(
                    .top,
                    DocketTheme.BoardManager.topPadding
                        - DocketTheme.BoardManager.rowOverhangHeadroom,
                    for: .scrollContent
                )
                .contentMargins(
                    .bottom,
                    DocketTheme.BoardManager.bottomPadding,
                    for: .scrollContent
                )
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

                ToolbarSpacer(.flexible, placement: .bottomBar)

                ToolbarItem(id: "docket.boards.new", placement: .bottomBar) {
                    Button {
                        showingCreateBoard = true
                    } label: {
                        Label("New Board", systemImage: "plus")
                    }
                    .docketPrimaryActionStyle()
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
                Text("Deletes every pin for all participants. This can't be undone.")
            }
        }
        .tint(DocketTheme.brass)
        .presentationDetents([.large])
    }

    private func boardCard(_ space: Space, isActive: Bool) -> some View {
        let snapshot = snapshots[space.id]

        return HStack(alignment: .top, spacing: DocketTheme.BoardManager.cardHeaderSpacing) {
            Button {
                openBoard(space)
            } label: {
                VStack(alignment: .leading, spacing: DocketTheme.BoardManager.titleSpacing) {
                    Text(space.title)
                        .font(
                            isActive
                                ? DocketTheme.BoardManager.activeTitleFont
                                : DocketTheme.BoardManager.rowTitleFont
                        )
                        .foregroundStyle(palette.primaryText)
                        .lineLimit(isActive ? 2 : 1)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)

                    metadataLine(for: snapshot, space: space)

                    if !isActive, let latest = snapshot?.latestUpdate {
                        latestUpdateLine(latest)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .disabled(isBusy)

            if switchingBoardID == space.id || preparingShareID == space.id {
                ProgressView()
                    .tint(DocketTheme.brass)
            }
        }
        .padding(
            isActive
                ? DocketTheme.BoardManager.activeCardPadding
                : DocketTheme.BoardManager.rowPadding
        )
        .background(
            palette.raisedPaper,
            in: RoundedRectangle(
                cornerRadius: cardCornerRadius(isActive: isActive),
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: cardCornerRadius(isActive: isActive),
                style: .continuous
            )
            .stroke(
                isActive ? DocketTheme.brass.opacity(0.22) : palette.divider,
                lineWidth: 1
            )
        }
        .overlay {
            if isActive {
                Circle()
                    .fill(DocketTheme.brass)
                    .frame(
                        width: DocketTheme.BoardManager.pinSize,
                        height: DocketTheme.BoardManager.pinSize
                    )
                    .shadow(color: .black.opacity(0.28), radius: 2, y: 1)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .offset(y: DocketTheme.BoardManager.pinOffsetY)
            } else {
                WashiTape(boardKey: space.id)
            }
        }
        .shadow(
            color: isActive
                ? palette.shadow
                : palette.shadow.opacity(DocketTheme.BoardManager.rowShadowOpacity),
            radius: isActive
                ? DocketTheme.BoardManager.activeShadowRadius
                : DocketTheme.BoardManager.rowShadowRadius,
            y: isActive
                ? DocketTheme.BoardManager.activeShadowY
                : DocketTheme.BoardManager.rowShadowY
        )
        .opacity(deletingBoardID == space.id ? 0.55 : 1)
        .frame(maxWidth: DocketTheme.BoardManager.maxContentWidth)
        .frame(maxWidth: .infinity)
    }

    private func cardCornerRadius(isActive: Bool) -> CGFloat {
        isActive
            ? DocketTheme.BoardManager.activeCardCornerRadius
            : DocketTheme.BoardManager.rowCornerRadius
    }

    @ViewBuilder
    private func swipeButtons(for space: Space) -> some View {
        if space.isOwned, store.spaces.count > 1 {
            Button(role: .destructive) {
                deleteCandidate = space
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }

        Button {
            openPeople(for: space)
        } label: {
            Label("People", systemImage: "person.2")
        }
        .tint(DocketTheme.brass)
    }

    @ViewBuilder
    private func metadataLine(for snapshot: BoardManagementSnapshot?, space: Space) -> some View {
        if let snapshot {
            if snapshot.isAvailable {
                Text(summary(for: snapshot))
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
                Text("Loading…")
            }
            .font(DocketTheme.BoardManager.metadataFont)
            .foregroundStyle(palette.secondaryText)
        } else {
            Text(space.isOwned ? "Owned by you" : "Shared with you")
                .font(DocketTheme.BoardManager.metadataFont)
                .foregroundStyle(palette.secondaryText)
        }
    }

    private func latestUpdateLine(_ latest: BoardLatestUpdate) -> some View {
        HStack(spacing: DocketTheme.BoardManager.latestSpacing) {
            Circle()
                .fill(latest.category.accent)
                .frame(
                    width: DocketTheme.BoardManager.latestDotSize,
                    height: DocketTheme.BoardManager.latestDotSize
                )

            Text(latestSummary(latest))
                .font(DocketTheme.BoardManager.metadataFont)
                .foregroundStyle(palette.secondaryText)
                .lineLimit(1)
        }
    }

    private var otherSpaces: [Space] {
        store.spaces.filter { $0 != store.space }
    }

    private var isBusy: Bool {
        switchingBoardID != nil || preparingShareID != nil || deletingBoardID != nil
    }

    private func summary(for snapshot: BoardManagementSnapshot) -> String {
        let pins = switch snapshot.itemCount {
        case 0: "No pins yet"
        case 1: "1 pin"
        default: "\(snapshot.itemCount) pins"
        }
        return "\(pins) · \(companionSummary(snapshot))"
    }

    /// Names the other people on the board ("with Sarah"), falling back to a
    /// count when CloudKit hasn't surfaced display names.
    private func companionSummary(_ snapshot: BoardManagementSnapshot) -> String {
        guard snapshot.participantCount > 1 else { return "just you" }
        let ownName = store.currentProfile?.displayName
        let others = snapshot.participantNames.filter { $0 != ownName }
        guard !others.isEmpty else {
            return "\(snapshot.participantCount) people"
        }
        let firstNames = others.map { name in
            name.split(separator: " ").first.map(String.init) ?? name
        }
        switch firstNames.count {
        case 1: return "with \(firstNames[0])"
        case 2: return "with \(firstNames[0]) & \(firstNames[1])"
        default: return "with \(firstNames[0]) +\(firstNames.count - 1)"
        }
    }

    private func latestSummary(_ latest: BoardLatestUpdate) -> String {
        var summary = "Latest update: \(latest.title)"
        if let author = latest.authorName,
           author != store.currentProfile?.displayName,
           let first = author.split(separator: " ").first {
            summary += " by \(first)"
        }
        let when = Self.relativeDateFormatter.localizedString(
            for: latest.date,
            relativeTo: .now
        )
        return "\(summary) · \(when)"
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

/// Shared row chrome for Board Manager's transparent, separator-free list:
/// clear background plus symmetric headroom so card decorations (pin, tape)
/// can overhang without clipping.
private struct BoardManagerRow: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(
                top: DocketTheme.BoardManager.rowOverhangHeadroom,
                leading: DocketTheme.BoardManager.horizontalPadding,
                bottom: DocketTheme.BoardManager.rowOverhangHeadroom,
                trailing: DocketTheme.BoardManager.horizontalPadding
            ))
    }
}

#Preview {
    BoardManagerView()
        .environment(BoardStore())
}
