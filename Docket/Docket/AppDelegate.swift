//
//  AppDelegate.swift
//  Docket
//
//  Bridges UIKit-only lifecycle events into the SwiftUI app. CloudKit share
//  invitations arrive through a window scene delegate on scene-based apps.
//

import CloudKit
import UIKit
import UserNotifications

extension Notification.Name {
    static let docketOpenSpace = Notification.Name("docketOpenSpace")
}

nonisolated struct AcceptedCloudKitShare: Equatable, Sendable {
    let zoneID: CKRecordZone.ID
    let title: String
    let inviterName: String?

    init(
        zoneID: CKRecordZone.ID,
        title: String,
        inviterName: String? = nil
    ) {
        self.zoneID = zoneID
        self.title = title
        self.inviterName = inviterName
    }
}

nonisolated enum CloudKitShareAcceptanceEvent: Equatable, Sendable {
    case accepted(AcceptedCloudKitShare)
    case failed(message: String)
}

/// Accepts invitations and buffers their result until the SwiftUI store has
/// installed its handler. The buffer matters on a cold launch: scene connection
/// can deliver metadata before ContentView has appeared.
@MainActor
final class CloudKitShareAcceptanceRouter {
    static let shared = CloudKitShareAcceptanceRouter()

    typealias Handler = @MainActor (CloudKitShareAcceptanceEvent) -> Void

    private var handler: Handler?
    private var pendingEvents: [CloudKitShareAcceptanceEvent] = []
    private var acceptingShareIDs: Set<String> = []

    func install(handler: @escaping Handler) {
        self.handler = handler
        let pendingEvents = self.pendingEvents
        self.pendingEvents.removeAll()
        pendingEvents.forEach(handler)
    }

    func route(_ event: CloudKitShareAcceptanceEvent) {
        guard let handler else {
            pendingEvents.append(event)
            return
        }
        handler(event)
    }

    func accept(_ metadata: CKShare.Metadata) {
        let shareID = [
            metadata.containerIdentifier,
            metadata.share.recordID.zoneID.ownerName,
            metadata.share.recordID.recordName
        ].joined(separator: "|")
        guard acceptingShareIDs.insert(shareID).inserted else { return }

        let zoneID = metadata.share.recordID.zoneID
        let inviterName = Self.inviterName(from: metadata)
        let title = Self.boardTitle(from: metadata, inviterName: inviterName)
        let container = CKContainer(identifier: metadata.containerIdentifier)
        let operation = CKAcceptSharesOperation(shareMetadatas: [metadata])
        let configuration = CKOperation.Configuration()
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        operation.configuration = configuration

        operation.acceptSharesResultBlock = { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                self.acceptingShareIDs.remove(shareID)

                switch result {
                case .success:
                    self.route(
                        .accepted(
                            AcceptedCloudKitShare(
                                zoneID: zoneID,
                                title: title,
                                inviterName: inviterName
                            )
                        )
                    )
                case .failure(let error):
                    self.route(.failed(message: UserFacingError.message(for: error)))
                }
            }
        }

        container.add(operation)
    }

    private static func boardTitle(
        from metadata: CKShare.Metadata,
        inviterName: String?
    ) -> String {
        if let title = (metadata.share[CKShare.SystemFieldKey.title] as? String)?.orNil {
            return title
        }
        if let inviterName {
            return inviterName.hasSuffix("s")
                ? "\(inviterName)’ Board"
                : "\(inviterName)’s Board"
        }
        return "Shared Board"
    }

    private static func inviterName(from metadata: CKShare.Metadata) -> String? {
        guard let components = metadata.ownerIdentity.nameComponents else { return nil }
        return PersonNameComponentsFormatter.localizedString(
            from: components,
            style: .short,
            options: []
        ).orNil
    }
}

@MainActor
final class RemoteNotificationRouter {
    static let shared = RemoteNotificationRouter()

    var handler: ((CKDatabase.Scope) async -> Bool)?

    func route(_ scope: CKDatabase.Scope) async -> Bool {
        await handler?(scope) ?? false
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        application.registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: nil,
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard let notification = CKNotification(
            fromRemoteNotificationDictionary: userInfo
        ) as? CKDatabaseNotification else {
            completionHandler(.noData)
            return
        }

        Task { @MainActor in
            let receivedData = await RemoteNotificationRouter.shared.route(
                notification.databaseScope
            )
            completionHandler(receivedData ? .newData : .noData)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let spaceID = response.notification.request.content.userInfo["spaceID"] as? String else {
            return
        }
        NotificationCenter.default.post(
            name: .docketOpenSpace,
            object: nil,
            userInfo: ["spaceID": spaceID]
        )
    }

}

@MainActor
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        if let metadata = connectionOptions.cloudKitShareMetadata {
            CloudKitShareAcceptanceRouter.shared.accept(metadata)
        }
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        CloudKitShareAcceptanceRouter.shared.accept(cloudKitShareMetadata)
    }
}
