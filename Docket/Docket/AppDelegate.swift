//
//  AppDelegate.swift
//  Docket
//
//  Exists solely to receive the CloudKit share-acceptance callback, which has
//  no SwiftUI equivalent. When the invitee taps the share link, iOS launches
//  the app and calls us with the share metadata; we accept it, then broadcast
//  the shared zone so the store can switch into participant mode.
//

import CloudKit
import UIKit
import UserNotifications

extension Notification.Name {
    static let docketDidAcceptShare = Notification.Name("docketDidAcceptShare")
    static let docketShareAcceptFailed = Notification.Name("docketShareAcceptFailed")
    static let docketOpenSpace = Notification.Name("docketOpenSpace")
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
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        let container = CKContainer(identifier: "iCloud.jaredrosen.docket")
        let operation = CKAcceptSharesOperation(shareMetadatas: [cloudKitShareMetadata])

        operation.acceptSharesResultBlock = { result in
            Task { @MainActor in
                switch result {
                case .success:
                    // For a zone-wide share, the share record lives in the owner's
                    // shared zone — exactly the zone the participant should target.
                    let zoneID = cloudKitShareMetadata.share.recordID.zoneID
                    let title = Self.boardTitle(from: cloudKitShareMetadata)
                    NotificationCenter.default.post(
                        name: .docketDidAcceptShare,
                        object: nil,
                        userInfo: ["zoneID": zoneID, "title": title]
                    )
                case .failure(let error):
                    NotificationCenter.default.post(
                        name: .docketShareAcceptFailed,
                        object: nil,
                        userInfo: ["error": UserFacingError.message(for: error)]
                    )
                }
            }
        }

        container.add(operation)
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

    private static func boardTitle(from metadata: CKShare.Metadata) -> String {
        if let components = metadata.ownerIdentity.nameComponents {
            let ownerName = PersonNameComponentsFormatter.localizedString(
                from: components,
                style: .short,
                options: []
            )
            if !ownerName.isEmpty {
                return ownerName.hasSuffix("s")
                    ? "\(ownerName)’ Board"
                    : "\(ownerName)’s Board"
            }
        }
        if let title = metadata.share[CKShare.SystemFieldKey.title] as? String,
           !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return title
        }
        return "Shared Board"
    }
}
