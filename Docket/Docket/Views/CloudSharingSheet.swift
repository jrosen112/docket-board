//
//  CloudSharingSheet.swift
//  Docket
//
//  Bridges UICloudSharingController into SwiftUI. CloudKit presents owner
//  membership controls or participant view/leave controls for the same share.
//

import SwiftUI
import CloudKit
import UIKit

struct CloudSharingSheet: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.availablePermissions = [.allowReadWrite, .allowPrivate]
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}
}
