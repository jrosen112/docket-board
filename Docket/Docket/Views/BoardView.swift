//
//  BoardView.swift
//  Docket
//
//  The board screen. Pure composition: background + filter bar + masonry of
//  cards + toolbar + sheets. All visuals live in components/DocketTheme; the
//  only state here is screen-local (sheet flags, filter selection).
//

import SwiftUI
import CloudKit

struct BoardView: View {
    @Environment(BoardStore.self) private var store
    @Namespace private var toolbarTransitionNamespace
    @Namespace private var boardTransitionNamespace

    @State private var addTarget: AddTarget?
    @State private var showingShare = false
    @State private var showingCreateBoard = false
    @State private var detailTarget: DetailTarget?
    @State private var filter = BoardFilter()
    @State private var scrollNoteProgress: CGFloat = 0
    @State private var boardNotice: BoardNotice?
    @State private var pendingAddedItemID: CKRecord.ID?
    @State private var revealingAddedItemID: CKRecord.ID?
    @State private var isAddedItemRevealed = true

    private var filteredItems: [any SharedListItem] {
        filter.apply(to: store.items)
    }

    private var filteredItemIDs: [CKRecord.ID] {
        filteredItems.map(\.id)
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
                    isOwner: store.isOwner,
                    isEnabled: !store.isSwitchingBoard,
                    transitionNamespace: toolbarTransitionNamespace,
                    onShare: prepareShare,
                    onAdd: beginAdding
                )
            }
            .overlay(alignment: .bottom) { boardOverlay }
            .sheet(item: $addTarget, onDismiss: presentAddedNoticeIfNeeded) { target in
                NewItemView(
                    itemID: target.id,
                    dateAdded: target.dateAdded,
                    onSaved: { pendingAddedItemID = target.id }
                )
                    .navigationTransition(
                        .zoom(
                            sourceID: BoardToolbarTransitionID.add,
                            in: toolbarTransitionNamespace
                        )
                    )
            }
            .sheet(isPresented: $showingShare) {
                if let share = store.activeShare {
                    CloudSharingSheet(share: share, container: store.container)
                        .navigationTransition(
                            .zoom(
                                sourceID: BoardToolbarTransitionID.share,
                                in: toolbarTransitionNamespace
                            )
                        )
                }
            }
            .sheet(isPresented: $showingCreateBoard) {
                CreateBoardView()
            }
            .navigationDestination(item: $detailTarget) { target in
                ItemDetailView(
                    itemID: target.id,
                    startsEditing: target.startsEditing
                )
                    .navigationTransition(
                        .zoom(sourceID: target.id, in: boardTransitionNamespace)
                    )
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
            EmptyBoardView(isFiltered: filter.isActive && !store.items.isEmpty)
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
                Task { await store.delete(item) }
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

    private func prepareShare() {
        Task {
            await store.prepareShare()
            showingShare = store.activeShare != nil
        }
    }

    private func beginAdding() {
        addTarget = AddTarget(id: store.newItemID(), dateAdded: .now)
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
                systemImage: summary.addedItemCount == 0 ? "checkmark" : "plus"
            )
        }
    }

    private func presentAddedNoticeIfNeeded() {
        guard let itemID = pendingAddedItemID else { return }
        pendingAddedItemID = nil
        presentNotice(message: "Added to board", systemImage: "pin.fill")

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

    private func presentNotice(message: String, systemImage: String) {
        withAnimation(
            .spring(
                response: DocketTheme.RefreshPill.insertionResponse,
                dampingFraction: DocketTheme.RefreshPill.insertionDamping
            )
        ) {
            boardNotice = BoardNotice(message: message, systemImage: systemImage)
        }
    }

    private func dismissBoardNotice() {
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
                    onDismiss: dismissBoardNotice
                )
                .id(notice.id)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task(id: notice.id) {
                    do {
                        try await Task.sleep(for: DocketTheme.RefreshPill.visibleDuration)
                    } catch {
                        return
                    }
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
                spaces: store.spaces,
                isEnabled: !store.isSwitchingBoard
            ) { space in
                Task { await store.switchTo(space: space) }
            } onCreate: {
                showingCreateBoard = true
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
}

private struct BoardNotice: Identifiable {
    let id = UUID()
    let message: String
    let systemImage: String
}
