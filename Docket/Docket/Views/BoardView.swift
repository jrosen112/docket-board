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
    @State private var editTarget: EditTarget?
    @State private var detailTarget: DetailTarget?
    @State private var filter = BoardFilter()
    @State private var scrollNoteProgress: CGFloat = 0
    @State private var refreshNotice: BoardRefreshNotice?

    private var filteredItems: [any SharedListItem] {
        filter.apply(to: store.items)
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
            .sheet(item: $addTarget) { target in
                NewItemView(itemID: target.id, dateAdded: target.dateAdded)
                    .navigationTransition(
                        .zoom(
                            sourceID: BoardToolbarTransitionID.add,
                            in: toolbarTransitionNamespace
                        )
                    )
            }
            .sheet(item: $editTarget) { target in
                ItemFormView(editing: target.item)
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
                ItemDetailView(itemID: target.id)
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
            MasonryLayout(columns: 2, spacing: 14) {
                ForEach(filteredItems, id: \.id) { item in
                    card(for: item)
                }
            }
            // Breathing room so pins/tilts don't clip at the edges.
            .padding(.top, 6)
        }
    }

    private func card(for item: any SharedListItem) -> some View {
        BoardCard(
            item: item,
            subtitle: cardSubtitle(for: item),
            addedBy: store.displayName(for: item)
        )
        .matchedTransitionSource(id: item.id, in: boardTransitionNamespace)
        .onTapGesture { detailTarget = DetailTarget(id: item.id) }
        .contextMenu {
            Button {
                editTarget = EditTarget(item: item)
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive) {
                Task { await store.delete(item) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
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
            refreshNotice = BoardRefreshNotice(summary: summary)
        }
    }

    private func dismissRefreshNotice() {
        withAnimation(
            .easeIn(duration: DocketTheme.RefreshPill.removalDuration)
        ) {
            refreshNotice = nil
        }
    }

    @ViewBuilder
    private var boardOverlay: some View {
        VStack(spacing: DocketTheme.RefreshPill.overlaySpacing) {
            if let message = store.errorMessage {
                ErrorBanner(message: message) { store.errorMessage = nil }
            }

            if let notice = refreshNotice {
                BoardRefreshPill(
                    summary: notice.summary,
                    onDismiss: dismissRefreshNotice
                )
                .id(notice.id)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task(id: notice.id) {
                    do {
                        try await Task.sleep(for: DocketTheme.RefreshPill.visibleDuration)
                    } catch {
                        return
                    }
                    dismissRefreshNotice()
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

/// Wraps an item for .sheet(item:) — existentials can't satisfy Identifiable's
/// generic constraint directly.
private struct EditTarget: Identifiable {
    let item: any SharedListItem
    var id: CKRecord.ID { item.id }
}

private struct DetailTarget: Identifiable, Hashable {
    let id: CKRecord.ID
}

private struct AddTarget: Identifiable {
    let id: CKRecord.ID
    let dateAdded: Date
}

private struct BoardRefreshNotice: Identifiable {
    let id = UUID()
    let summary: BoardRefreshSummary
}
