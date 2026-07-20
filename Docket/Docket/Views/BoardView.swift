//
//  BoardView.swift
//  Docket
//
//  The board screen. Pure composition: background + filter bar + masonry of
//  cards + toolbar + sheets. All visuals live in components/DocketTheme; the
//  only state here is screen-local (sheet flags, filter selection).
//

import CloudKit
import SwiftUI

struct BoardView: View {
    @Environment(BoardStore.self) private var store
    @Environment(\.dismissSearch) private var dismissSearch
    @Namespace private var toolbarTransitionNamespace
    @Namespace private var boardTransitionNamespace

    @State private var addTarget: AddTarget?
    @State private var showingSettings = false
    @State private var showingBoardManager = false
    @State private var detailTarget: DetailTarget?
    @State private var filter = BoardFilter()
    @State private var searchQuery = ""
    @State private var scrollNoteProgress: CGFloat = 0
    @State private var boardNotice: BoardNotice?
    @State private var pendingSave: PendingBoardSave?
    @State private var deleteCandidate: BoardDeleteCandidate?
    @State private var revealingAddedItemID: CKRecord.ID?
    @State private var isAddedItemRevealed = true

    private var filteredItems: [any SharedListItem] {
        filter.apply(to: store.items).filter {
            itemMatchesBoardSearch($0, query: searchQuery)
        }
    }

    private var isSearching: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var filteredItemIDs: [CKRecord.ID] {
        filteredItems.map(\.id)
    }

    private var deleteAlertTitle: String {
        guard let deleteCandidate else { return "Delete Item?" }
        return "Delete “" + deleteCandidate.title + "”?"
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Rectangle()
                    .fill(DocketTheme.boardBackground)
                    .ignoresSafeArea()
                BoardScrollNote(
                    progress: store.isSwitchingBoard ? 0 : scrollNoteProgress,
                    createdCount: store.currentUserItemCount,
                    totalCount: store.items.count
                )
                boardContent
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DocketTheme.ink, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                topToolbarItems
                BoardBottomToolbar(
                    isAddEnabled: !store.isSwitchingBoard,
                    transitionNamespace: toolbarTransitionNamespace,
                    onSettings: { showingSettings = true },
                    onAdd: beginAdding(category:)
                )
            }
            .searchable(
                text: $searchQuery,
                placement: .toolbar,
                prompt: "Search board"
            )
            .onSubmit(of: .search) {
                guard !isSearching else { return }
                dismissSearch()
            }
            .overlay(alignment: .bottom) { boardOverlay }
            .sheet(item: $addTarget) { target in
                NewItemView(
                    itemID: target.id,
                    dateAdded: target.dateAdded,
                    initialCategory: target.category,
                    onSave: { beginSave($0, kind: .pinning) }
                )
                .navigationTransition(
                    .zoom(
                        sourceID: BoardToolbarTransitionID.add,
                        in: toolbarTransitionNamespace
                    )
                )
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .navigationTransition(
                        .zoom(
                            sourceID: BoardToolbarTransitionID.settings,
                            in: toolbarTransitionNamespace
                        )
                    )
            }
            .sheet(isPresented: $showingBoardManager) {
                BoardManagerView()
            }
            .navigationDestination(item: $detailTarget) { target in
                ItemDetailView(
                    itemID: target.id,
                    onSave: { beginSave($0, kind: .editing) },
                    onDelete: presentDeletedNotice(title:),
                    startsEditing: target.startsEditing
                )
                .navigationTransition(
                    .zoom(sourceID: target.id, in: boardTransitionNamespace)
                )
            }
            .alert(
                deleteAlertTitle,
                isPresented: Binding(
                    get: { deleteCandidate != nil },
                    set: { if !$0 { deleteCandidate = nil } }
                ),
                presenting: deleteCandidate
            ) { candidate in
                Button("Delete", role: .destructive) {
                    deleteCandidate = nil
                    performDelete(candidate)
                }
                Button("Cancel", role: .cancel) {
                    deleteCandidate = nil
                }
            } message: { _ in
                Text("This removes the item from the shared board for everyone. This can't be undone.")
            }
            .task(id: store.itemNavigationRequest?.id) {
                guard let request = store.itemNavigationRequest else { return }
                detailTarget = DetailTarget(id: request.recordID)
                store.consumeItemNavigationRequest(request.id)
            }
        }
    }

    // MARK: - Pieces

    private var boardContent: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    boardItems
                        .padding(.top, 10)
                        .padding(.bottom, 32)
                } header: {
                    BoardFilterHeader(
                        filter: $filter,
                        categories: ItemCategory.supported
                    )
                }
            }
            .padding(.horizontal, 16)
        }
        .refreshable { await refreshBoard() }
        .onScrollGeometryChange(
            for: CGFloat.self,
            of: { geometry in
                let offset = geometry.contentOffset.y + geometry.contentInsets.top
                return DocketTheme.BoardScrollNote.progress(for: offset)
            },
            action: { _, progress in
                scrollNoteProgress = progress
            }
        )
    }

    private var boardItems: some View {
        ZStack(alignment: .top) {
            if store.isSwitchingBoard {
                BoardSkeletonView()
                    .transition(.opacity)
            } else {
                loadedBoardItems
                    .transition(.opacity)
            }
        }
        .animation(
            .easeInOut(duration: DocketTheme.BoardSkeleton.contentTransitionDuration),
            value: store.isSwitchingBoard
        )
    }

    @ViewBuilder
    private var loadedBoardItems: some View {
        if filteredItems.isEmpty {
            EmptyBoardView(
                isFiltered: (filter.isActive || isSearching) && !store.items.isEmpty,
                isSearching: isSearching && !store.items.isEmpty
            )
        } else {
            MasonryLayout(
                columns: 2,
                spacing: 14,
                contentOverflow: DocketTheme.BoardCard.transitionCaptureInset
            ) {
                ForEach(filteredItems, id: \.id) { item in
                    card(for: item)
                }
            }
            .animation(DocketTheme.BoardItems.changeAnimation, value: filteredItemIDs)
            // Breathing room so pins/tilts don't clip at the edges.
            .padding(.top, 6)
        }
    }

    private func card(for item: any SharedListItem) -> some View {
        let captureInset = DocketTheme.BoardCard.transitionCaptureInset

        return BoardCard(
            item: item,
            subtitle: cardSubtitle(for: item),
            addedBy: store.displayName(for: item)
        )
        // Capture visual overflow from the pin, shadow, and card rotation.
        // MasonryLayout accounts for this inset without moving the paper.
        .padding(captureInset)
        .contentShape(.interaction, Rectangle().inset(by: captureInset))
        .contentShape(
            .contextMenuPreview,
            BoardCardPreviewShape(
                captureInset: captureInset,
                rotationDegrees: DocketTheme.rotationDegrees(for: item.id.recordName)
            )
        )
        .matchedTransitionSource(id: item.id, in: boardTransitionNamespace)
        .onTapGesture { detailTarget = DetailTarget(id: item.id) }
        .contextMenu {
            Button {
                detailTarget = DetailTarget(id: item.id, startsEditing: true)
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive) {
                deleteCandidate = BoardDeleteCandidate(item: item)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        } preview: {
            BoardItemQuickLookView(
                item: item,
                addedBy: store.displayName(for: item)
            )
        }
        .scaleEffect(
            revealingAddedItemID == item.id && !isAddedItemRevealed
                ? DocketTheme.BoardItems.insertionScale
                : 1
        )
        .opacity(revealingAddedItemID == item.id && !isAddedItemRevealed ? 0 : 1)
        .transition(
            .asymmetric(
                insertion: .scale(scale: DocketTheme.BoardItems.insertionScale)
                    .combined(with: .opacity),
                removal: .scale(scale: DocketTheme.BoardItems.removalScale)
                    .combined(with: .opacity)
            )
        )
    }

    private func beginAdding(category: ItemCategory) {
        addTarget = AddTarget(
            id: store.newItemID(),
            dateAdded: .now,
            category: category
        )
    }

    private func performDelete(_ candidate: BoardDeleteCandidate) {
        Task { @MainActor in
            guard case .deleted = await store.delete(candidate.item) else { return }
            presentDeletedNotice(title: candidate.title)
        }
    }

    private func presentDeletedNotice(title: String) {
        withAnimation(DocketDetailTheme.Edit.modeAnimation) {
            boardNotice = BoardNotice(
                message: "Deleted \(title)",
                systemImage: "trash",
                dismissalID: UUID()
            )
        }
    }

    private func refreshBoard() async {
        guard let summary = await store.refresh() else { return }
        withAnimation(
            .spring(
                response: DocketTheme.RefreshPill.insertionResponse,
                dampingFraction: DocketTheme.RefreshPill.insertionDamping
            )
        ) {
            boardNotice = BoardNotice(
                message: summary.message,
                systemImage: summary.addedItemCount == 0 ? "checkmark" : "plus",
                dismissalID: UUID()
            )
        }
    }

    private func revealAddedItem(_ itemID: CKRecord.ID) {
        guard filteredItemIDs.contains(itemID) else { return }
        revealingAddedItemID = itemID
        isAddedItemRevealed = false

        Task { @MainActor in
            try? await Task.sleep(for: DocketTheme.BoardItems.revealDelay)
            guard revealingAddedItemID == itemID else { return }

            withAnimation(DocketTheme.BoardItems.changeAnimation) {
                isAddedItemRevealed = true
            }

            try? await Task.sleep(for: DocketTheme.BoardItems.revealCleanupDelay)
            guard revealingAddedItemID == itemID else { return }
            revealingAddedItemID = nil
        }
    }

    private func beginSave(
        _ item: any SharedListItem,
        kind: BoardSaveKind
    ) {
        performSave(
            PendingBoardSave(
                id: UUID(),
                item: item,
                kind: kind,
                requiresRebase: false
            )
        )
    }

    private func retryPendingSave() {
        guard let pendingSave else { return }
        performSave(pendingSave)
    }

    private func performSave(_ initialSave: PendingBoardSave) {
        pendingSave = initialSave
        withAnimation(DocketDetailTheme.Edit.modeAnimation) {
            boardNotice = BoardNotice(
                id: initialSave.id,
                message: initialSave.kind.progressMessage,
                systemImage: "arrow.trianglehead.2.clockwise",
                isProgress: true
            )
        }

        Task { @MainActor in
            var save = initialSave

            if save.requiresRebase {
                _ = await store.refresh()
                guard let latest = store.items.first(where: { $0.id == save.item.id }),
                    let rebased = ItemDraft(item: save.item).applying(to: latest)
                else {
                    presentSaveFailure(for: save, requiresRebase: true)
                    return
                }
                save = PendingBoardSave(
                    id: save.id,
                    item: rebased,
                    kind: save.kind,
                    requiresRebase: false
                )
                pendingSave = save
            }

            let minimumDelay = Task {
                try? await Task.sleep(for: DocketTheme.RefreshPill.minimumSaveDuration)
            }
            let result = await store.save(save.item)
            await minimumDelay.value

            guard pendingSave?.id == save.id else { return }
            switch result {
            case .saved:
                pendingSave = nil
                withAnimation(DocketDetailTheme.Edit.modeAnimation) {
                    boardNotice = BoardNotice(
                        id: save.id,
                        message: save.kind.successMessage,
                        systemImage: save.kind.successSymbol,
                        dismissalID: UUID()
                    )
                }
                if save.kind == .pinning {
                    revealAddedItem(save.item.id)
                }
            case .conflict:
                presentSaveFailure(for: save, requiresRebase: true)
            case .failed:
                presentSaveFailure(for: save, requiresRebase: false)
            }
        }
    }

    private func presentSaveFailure(
        for save: PendingBoardSave,
        requiresRebase: Bool
    ) {
        pendingSave = PendingBoardSave(
            id: save.id,
            item: save.item,
            kind: save.kind,
            requiresRebase: requiresRebase
        )
        withAnimation(DocketDetailTheme.Edit.modeAnimation) {
            boardNotice = BoardNotice(
                id: save.id,
                message: save.kind.failureMessage,
                systemImage: "arrow.clockwise",
                isRetryable: true
            )
        }
    }

    private func dismissBoardNotice() {
        if boardNotice?.isRetryable == true {
            pendingSave = nil
        }
        withAnimation(
            .easeIn(duration: DocketTheme.RefreshPill.removalDuration)
        ) {
            boardNotice = nil
        }
    }

    @ViewBuilder
    private var boardOverlay: some View {
        VStack(spacing: DocketTheme.RefreshPill.overlaySpacing) {
            if let message = store.errorMessage {
                ErrorBanner(message: message) { store.errorMessage = nil }
            }

            if let notice = boardNotice {
                BoardNoticePill(
                    message: notice.message,
                    systemImage: notice.systemImage,
                    isProgress: notice.isProgress,
                    isRetryable: notice.isRetryable,
                    onRetry: retryPendingSave,
                    onDismiss: dismissBoardNotice
                )
                .id(notice.id)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task(id: notice.dismissalID) {
                    guard let dismissalID = notice.dismissalID else { return }
                    do {
                        try await Task.sleep(for: DocketTheme.RefreshPill.visibleDuration)
                    } catch {
                        return
                    }
                    guard boardNotice?.dismissalID == dismissalID else { return }
                    dismissBoardNotice()
                }
            }
        }
        .padding(.bottom, DocketTheme.RefreshPill.bottomPadding)
    }

    @ToolbarContentBuilder private var topToolbarItems: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            BoardSwitcher(
                currentSpace: store.space,
                isEnabled: !store.isSwitchingBoard
            ) {
                showingBoardManager = true
            }
        }
        #if DEBUG
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        Task { await store.seedSampleData() }
                    } label: {
                        Label("Seed sample data", systemImage: "sparkles")
                    }
                    Button(role: .destructive) {
                        Task { await store.deleteSampleData() }
                    } label: {
                        Label("Delete sample data", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(DocketTheme.brass.opacity(0.7))
                }
            }
        #endif
    }
}

private struct DetailTarget: Identifiable, Hashable {
    let id: CKRecord.ID
    var startsEditing = false
}

private struct AddTarget: Identifiable {
    let id: CKRecord.ID
    let dateAdded: Date
    let category: ItemCategory
}

private struct BoardDeleteCandidate {
    let item: any SharedListItem
    let title: String

    init(item: any SharedListItem) {
        self.item = item
        self.title = item.title
    }
}

private struct BoardNotice: Identifiable {
    var id = UUID()
    let message: String
    let systemImage: String
    var isProgress = false
    var isRetryable = false
    var dismissalID: UUID?
}

private enum BoardSaveKind: Equatable {
    case pinning
    case editing

    var progressMessage: String {
        switch self {
        case .pinning: "Pinning…"
        case .editing: "Saving…"
        }
    }

    var successMessage: String {
        switch self {
        case .pinning: "Pinned to board"
        case .editing: "Saved"
        }
    }

    var failureMessage: String {
        switch self {
        case .pinning: "Couldn't pin — tap to retry"
        case .editing: "Couldn't save — tap to retry"
        }
    }

    var successSymbol: String {
        switch self {
        case .pinning: "pin.fill"
        case .editing: "checkmark"
        }
    }
}

private struct PendingBoardSave {
    let id: UUID
    let item: any SharedListItem
    let kind: BoardSaveKind
    let requiresRebase: Bool
}
