//
//  CloudSharingSheet.swift
//  Docket
//
//  Bridges UICloudSharingController into SwiftUI. CloudKit presents owner
//  membership controls or participant view/leave controls for the same share.
//

import CloudKit
import SwiftUI
import UIKit

struct CloudSharingSheet: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer
    var onShareSaved: () -> Void = {}
    var onStoppedSharing: () -> Void = {}
    var onFailure: (String) -> Void = { _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            title: share[CKShare.SystemFieldKey.title] as? String,
            onShareSaved: onShareSaved,
            onStoppedSharing: onStoppedSharing,
            onFailure: onFailure
        )
    }

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.availablePermissions = [.allowReadWrite, .allowPrivate]
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        let title: String?
        let onShareSaved: () -> Void
        let onStoppedSharing: () -> Void
        let onFailure: (String) -> Void

        init(
            title: String?,
            onShareSaved: @escaping () -> Void,
            onStoppedSharing: @escaping () -> Void,
            onFailure: @escaping (String) -> Void
        ) {
            self.title = title
            self.onShareSaved = onShareSaved
            self.onStoppedSharing = onStoppedSharing
            self.onFailure = onFailure
        }

        func itemTitle(for csc: UICloudSharingController) -> String? { title }

        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            onShareSaved()
        }

        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            onStoppedSharing()
        }

        func cloudSharingController(
            _ csc: UICloudSharingController,
            failedToSaveShareWithError error: any Error
        ) {
            onFailure(UserFacingError.message(for: error))
        }
    }
}
