//
//  CloudSharingSheet.swift
//  Docket
//
//  Bridges UICloudSharingController into SwiftUI so the owner can send the
//  native CloudKit share invite for the shared zone.
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
