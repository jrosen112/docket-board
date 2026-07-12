//
//  DocketApp.swift
//  Docket
//
//  Created by Jared Rosen on 7/12/26.
//

import SwiftUI
import CloudKit

@main
struct DocketApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = BoardStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .task { await store.bootstrap() }
                .onReceive(NotificationCenter.default.publisher(for: .docketDidAcceptShare)) { note in
                    guard let zoneID = note.userInfo?["zoneID"] as? CKRecordZone.ID else { return }
                    Task { await store.switchTo(space: Space(zoneID: zoneID, access: .joined)) }
                }
                .onReceive(NotificationCenter.default.publisher(for: .docketShareAcceptFailed)) { note in
                    store.errorMessage = note.userInfo?["error"] as? String
                }
        }
    }
}
