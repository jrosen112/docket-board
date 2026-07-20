import CloudKit
import Foundation

extension BoardStore {
    /// A fresh record ID in this space's zone, for building a new item.
    func newItemID() -> CKRecord.ID { service.newRecordID() }

    /// Saves a new or edited item. Edited items carry their CloudKit change
    /// tag (systemFields), so concurrent-edit conflicts surface as errors
    /// rather than silently clobbering the other person's change.
    ///
    /// Failures ride back in the result rather than `errorMessage` so the
    /// board-level save pill can morph into a retry action without also
    /// leaving a second, unrelated error banner behind.
    @discardableResult
    func save(_ item: any SharedListItem) async -> StoreSaveResult {
        let requestedSpace = space
        let requestedService = service
        do {
            try await requireNetwork()
            let savedRecord = try await requestedService.save(item.toRecord())
            if space == requestedSpace,
               let savedItem = RecordDecoder.item(from: savedRecord) {
                if let index = items.firstIndex(where: { $0.id == savedItem.id }) {
                    items[index] = savedItem
                } else {
                    items.append(savedItem)
                }
                items.sort { $0.dateAdded > $1.dateAdded }
                remember(items: items, in: requestedSpace)
                _ = await refresh()
            }
            return .saved
        } catch {
            if Self.isConflict(error) {
                return .conflict(
                    message: "Someone else edited this item. Reload the board to see their version, then try your edit again."
                )
            }
            return .failed(message: Self.message(for: error))
        }
    }

    @discardableResult
    func delete(_ item: any SharedListItem) async -> StoreDeleteResult {
        do {
            try await requireNetwork()
            try await service.delete(item.id)
            items.removeAll { $0.id == item.id }
            return .deleted
        } catch {
            let message = Self.message(for: error)
            errorMessage = message
            return .failed(message: message)
        }
    }

    /// Display name for whoever added an item.
    func displayName(for item: any SharedListItem) -> String {
        profiles.first { $0.id.recordName == item.addedBy.recordID.recordName }?.displayName ?? "—"
    }

    #if DEBUG
    /// Populates the board with SampleData so UI iteration doesn't require
    /// re-entering items by hand. Saved once, then a single refresh.
    func seedSampleData() async {
        guard let me = currentProfile else { return }
        do {
            try await requireNetwork()
            for item in SampleData.items(addedBy: me.reference, in: service.space.zoneID) {
                try await service.save(item.toRecord())
            }
            await refresh()
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    /// Removes ONLY seeded records (sample- ID prefix); real items untouched.
    func deleteSampleData() async {
        let samples = items.filter { SampleData.isSample($0.id) }
        do {
            try await requireNetwork()
            for item in samples {
                try await service.delete(item.id)
            }
            await refresh()
        } catch {
            errorMessage = Self.message(for: error)
        }
    }
    #endif
}
