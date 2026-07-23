import CloudKit
import Foundation

nonisolated struct ShareBoard: Identifiable, Hashable {
    enum Access: String, Codable {
        case owned
        case joined
    }

    let zoneName: String
    let ownerName: String
    let access: Access
    let title: String
    let profileRecordName: String

    var id: String { "\(access.rawValue):\(ownerName)/\(zoneName)" }
    var zoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: zoneName, ownerName: ownerName)
    }
}

nonisolated enum ShareBoardCatalog {
    static let suiteName = "group.jared.rosen.docket"
    private static let catalogKey = "docket.spaces.v2"

    private struct StoredBoard: Codable {
        let zoneName: String
        let ownerName: String
        let access: ShareBoard.Access
        let title: String

        var id: String { "\(access.rawValue):\(ownerName)/\(zoneName)" }
    }

    static func load() -> [ShareBoard] {
        guard let defaults = UserDefaults(suiteName: suiteName),
            let data = defaults.data(forKey: catalogKey),
            let storedBoards = try? JSONDecoder().decode([StoredBoard].self, from: data)
        else { return [] }

        return storedBoards.compactMap { board in
            let profileKey = "docket.currentProfileRecordName.\(board.id)"
            guard let profileRecordName = defaults.string(forKey: profileKey) else { return nil }
            return ShareBoard(
                zoneName: board.zoneName,
                ownerName: board.ownerName,
                access: board.access,
                title: board.title,
                profileRecordName: profileRecordName
            )
        }
        .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }
}

nonisolated enum ShareRecipeService {
    private static let containerIdentifier = "iCloud.jaredrosen.docket"

    static func save(
        title: String,
        sourceURL: URL,
        ingredients: [String],
        instructions: [String],
        photoData: Data?,
        to board: ShareBoard
    ) async throws {
        let container = CKContainer(identifier: containerIdentifier)
        let database =
            board.access == .owned
            ? container.privateCloudDatabase
            : container.sharedCloudDatabase
        let recordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: board.zoneID)
        let profileID = CKRecord.ID(recordName: board.profileRecordName, zoneID: board.zoneID)
        let record = CKRecord(recordType: "Recipe", recordID: recordID)
        record["title"] = title
        record["status"] = "wantToGo"
        record["addedBy"] = CKRecord.Reference(recordID: profileID, action: .none)
        record["dateAdded"] = Date.now
        record["sourceURL"] = sourceURL.absoluteString
        let photoAsset = makePhotoAsset(from: photoData)
        record["showsPhotoOnBoard"] = photoAsset != nil
        record["itemPhoto"] = photoAsset
        if !ingredients.isEmpty {
            record["ingredients"] = ingredients as CKRecordValue
        }
        if !instructions.isEmpty {
            record["instructions"] = instructions as CKRecordValue
        }
        _ = try await database.save(record)
    }

    private static func makePhotoAsset(from data: Data?) -> CKAsset? {
        guard let data else { return nil }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DocketShareAssets", isDirectory: true)
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            let fileURL =
                directory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("jpg")
            try data.write(to: fileURL, options: .atomic)
            return CKAsset(fileURL: fileURL)
        } catch {
            return nil
        }
    }

    static func message(for error: Error) -> String {
        guard let cloudError = error as? CKError else {
            return "The recipe couldn't be saved. Please try again."
        }
        return switch cloudError.code {
        case .notAuthenticated:
            "Sign in to iCloud, then try again."
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited:
            "Docket couldn't reach iCloud. Check your connection and try again."
        case .permissionFailure:
            "You no longer have permission to add to that board."
        case .zoneNotFound, .unknownItem:
            "That board is no longer available. Open Docket to refresh your boards."
        default:
            "The recipe couldn't be saved. Please try again."
        }
    }
}
