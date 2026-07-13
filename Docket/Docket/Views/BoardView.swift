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

    @State private var showingAdd = false
    @State private var showingShare = false
    @State private var editTarget: EditTarget?
    @State private var detailTarget: DetailTarget?
    @State private var filter = BoardFilter()

    private var filteredItems: [any SharedListItem] {
        filter.apply(to: store.items)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Rectangle()
                    .fill(DocketTheme.boardBackground)
                    .ignoresSafeArea()
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
                    transitionNamespace: toolbarTransitionNamespace,
                    onShare: prepareShare,
                    onAdd: { showingAdd = true }
                )
            }
            .overlay(alignment: .bottom) {
                if let message = store.errorMessage {
                    ErrorBanner(message: message) { store.errorMessage = nil }
                        .padding(.bottom, 8)
                }
            }
            .sheet(isPresented: $showingAdd) {
                ItemFormView()
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
            .navigationDestination(item: $detailTarget) { target in
                ItemDetailView(itemID: target.id)
            }
        }
    }

    // MARK: - Pieces

    private var boardContent: some View {
        ScrollView {
            VStack(spacing: 18) {
                BoardFilterBar(filter: $filter, categories: ItemCategory.supported)

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
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .refreshable { await store.refresh() }
    }

    private func card(for item: any SharedListItem) -> some View {
        BoardCard(
            item: item,
            subtitle: cardSubtitle(for: item),
            addedBy: store.displayName(for: item)
        )
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

    @ToolbarContentBuilder private var topToolbarItems: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text("The Board")
                .font(DocketTheme.display(20))
                .foregroundStyle(DocketTheme.cream)
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
