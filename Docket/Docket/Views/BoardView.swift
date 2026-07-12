//
//  BoardView.swift
//  Docket
//
//  The board. A plain list for now (masonry / corkboard styling comes later);
//  the point at this stage is to prove data flows from CloudKit through the
//  store into the UI, and back out via Add / Delete / Share.
//

import SwiftUI

struct BoardView: View {
    @Environment(BoardStore.self) private var store

    @State private var showingAdd = false
    @State private var showingShare = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("The Board")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            Task {
                                await store.prepareShare()
                                showingShare = store.activeShare != nil
                            }
                        } label: {
                            Image(systemName: "person.crop.circle.badge.plus")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showingAdd = true } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .refreshable { await store.refresh() }
                .sheet(isPresented: $showingAdd) { AddItemView() }
                .sheet(isPresented: $showingShare) {
                    if let share = store.activeShare {
                        CloudSharingSheet(share: share, container: store.container)
                    }
                }
        }
    }

    @ViewBuilder private var content: some View {
        if store.items.isEmpty {
            ContentUnavailableView(
                "Nothing on the board yet",
                systemImage: "pin",
                description: Text("Tap + to add your first spot.")
            )
        } else {
            List {
                ForEach(store.items, id: \.id) { item in
                    ItemRow(item: item, addedBy: store.displayName(for: item))
                }
                .onDelete { indexSet in
                    let toDelete = indexSet.map { store.items[$0] }
                    Task { for item in toDelete { await store.delete(item) } }
                }
            }
        }
    }
}

private struct ItemRow: View {
    let item: any SharedListItem
    let addedBy: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title).font(.headline)
            HStack(spacing: 6) {
                Text(item.category.label)
                Text("·")
                Text(item.status.label)
                Spacer()
                Text(addedBy)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let notes = item.notes, !notes.isEmpty {
                Text(notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }
}
