import CloudKit
import UserNotifications

nonisolated struct BoardChangeNotice: Equatable, Sendable {
    let boardID: String
    let title: String
    let body: String
}

nonisolated protocol BoardNotificationService: Sendable {
    func prepare() async throws
    func post(_ notice: BoardChangeNotice) async throws
}

/// Installs one silent CloudKit database subscription for each database that
/// can contain a participating board. Silent pushes are only change signals;
/// BoardStore fetches and compares records before asking this service to show
/// a user-facing notification.
actor CloudKitBoardNotificationService: BoardNotificationService {
    private let containerIdentifier: String
    private let center: UNUserNotificationCenter

    init(
        containerIdentifier: String = "iCloud.jaredrosen.docket",
        center: UNUserNotificationCenter = .current()
    ) {
        self.containerIdentifier = containerIdentifier
        self.center = center
    }

    func prepare() async throws {
        _ = try await center.requestAuthorization(options: [.alert, .sound])
        let container = CKContainer(identifier: containerIdentifier)
        try await ensureSubscription(
            in: container.privateCloudDatabase,
            id: "docket-private-database-v1"
        )
        try await ensureSubscription(
            in: container.sharedCloudDatabase,
            id: "docket-shared-database-v1"
        )
    }

    func post(_ notice: BoardChangeNotice) async throws {
        let content = UNMutableNotificationContent()
        content.title = notice.title
        content.body = notice.body
        content.sound = .default
        content.userInfo = ["spaceID": notice.boardID]

        let request = UNNotificationRequest(
            identifier: "docket-board-change-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        try await center.add(request)
    }

    private func ensureSubscription(in database: CKDatabase, id: CKSubscription.ID) async throws {
        do {
            _ = try await database.subscription(for: id)
            return
        } catch let error as CKError where error.code == .unknownItem {
            let subscription = CKDatabaseSubscription(subscriptionID: id)
            let info = CKSubscription.NotificationInfo()
            info.shouldSendContentAvailable = true
            subscription.notificationInfo = info
            _ = try await database.save(subscription)
        }
    }
}

nonisolated struct NoopBoardNotificationService: BoardNotificationService {
    func prepare() async throws {}
    func post(_ notice: BoardChangeNotice) async throws {}
}
