import CloudKit

nonisolated enum BoardLoadState: Equatable {
    case loading
    case loaded
    case failed(message: String)
}

nonisolated enum StoreSaveResult: Equatable {
    case saved
    case conflict(message: String)
    case failed(message: String)
}

nonisolated enum ICloudRestoreResult: Equatable {
    case restored(boardCount: Int)
    case notFound
    case failed(message: String)
}

nonisolated struct BoardProfileStats: Identifiable, Equatable {
    let id: String
    let title: String
    let itemCount: Int
}

nonisolated struct BoardManagementSnapshot: Identifiable, Equatable, Sendable {
    let space: Space
    let itemCount: Int
    let participantNames: [String]
    let isAvailable: Bool

    var id: String { space.id }
}

nonisolated struct ProfileStats: Equatable {
    let boardCount: Int
    let loadedBoardCount: Int
    let itemCount: Int
    let wantToGoCount: Int
    let plannedCount: Int
    let completedCount: Int
    let favoriteCategory: ItemCategory?
    let boards: [BoardProfileStats]

    var unavailableBoardCount: Int { boardCount - loadedBoardCount }
}

nonisolated enum ProfileStatsLoadResult: Equatable {
    case loaded(ProfileStats)
    case failed(message: String)
}

nonisolated enum ProfileNameUpdateResult: Equatable {
    case updated(boardCount: Int)
    case partiallyUpdated(updatedBoardCount: Int, failedBoardTitles: [String])
    case failed(message: String)
}

nonisolated struct BoardInvitation: Identifiable, Equatable, Sendable {
    let space: Space
    let inviterName: String?

    var id: String { space.id }
}

nonisolated struct BoardItemNavigationRequest: Identifiable, Equatable, Sendable {
    let id: UUID
    let recordID: CKRecord.ID

    init(recordID: CKRecord.ID, id: UUID = UUID()) {
        self.id = id
        self.recordID = recordID
    }
}

nonisolated struct BoardRefreshSummary: Equatable, Sendable {
    let addedItemCount: Int

    var message: String {
        switch addedItemCount {
        case 0: "No new items"
        case 1: "1 item added"
        default: "\(addedItemCount) items added"
        }
    }
}
