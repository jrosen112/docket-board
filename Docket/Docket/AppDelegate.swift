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

extension Notification.Name {
    static let docketDidAcceptShare = Notification.Name("docketDidAcceptShare")
    static let docketShareAcceptFailed = Notification.Name("docketShareAcceptFailed")
}

final class AppDelegate: NSObject, UIApplicationDelegate {
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
                    NotificationCenter.default.post(
                        name: .docketDidAcceptShare,
                        object: nil,
                        userInfo: ["zoneID": zoneID]
                    )
                case .failure(let error):
                    NotificationCenter.default.post(
                        name: .docketShareAcceptFailed,
                        object: nil,
                        userInfo: ["error": error.localizedDescription]
                    )
                }
            }
        }

        container.add(operation)
    }
}
