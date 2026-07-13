//
//  DocketApp.swift
//  Docket
//
//  Created by Jared Rosen on 7/12/26.
//

import SwiftUI
import CloudKit

@main
@MainActor
struct DocketApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store: BoardStore

    init() {
        let store = BoardStore()
        _store = State(initialValue: store)
        RemoteNotificationRouter.shared.handler = { scope in
            await store.handleRemoteDatabaseChange(scope: scope)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .task { await store.bootstrap() }
                .onReceive(NotificationCenter.default.publisher(for: .docketDidAcceptShare)) { note in
                    guard let zoneID = note.userInfo?["zoneID"] as? CKRecordZone.ID else { return }
                    let title = note.userInfo?["title"] as? String
                    Task {
                        await store.switchTo(
                            space: Space(zoneID: zoneID, access: .joined, title: title)
                        )
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .docketShareAcceptFailed)) { note in
                    store.errorMessage = note.userInfo?["error"] as? String
                }
                .onReceive(NotificationCenter.default.publisher(for: .docketOpenSpace)) { note in
                    guard
                        let spaceID = note.userInfo?["spaceID"] as? String,
                        let space = store.spaces.first(where: { $0.id == spaceID })
                    else { return }
                    Task { await store.switchTo(space: space) }
                }
        }
    }
}
