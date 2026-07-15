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
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppPreferences.darkerThemeKey) private var darkerThemeEnabled =
        AppPreferences.defaultDarkerThemeEnabled
    @State private var store: BoardStore

    init() {
        let store = BoardStore()
        _store = State(initialValue: store)
        RemoteNotificationRouter.shared.handler = { scope in
            await store.handleRemoteDatabaseChange(scope: scope)
        }
        CloudKitShareAcceptanceRouter.shared.install { event in
            switch event {
            case .accepted(let acceptedShare):
                Task {
                    await store.openAcceptedShare(
                        Space(
                            zoneID: acceptedShare.zoneID,
                            access: .joined,
                            title: acceptedShare.title
                        ),
                        inviterName: acceptedShare.inviterName
                    )
                }
            case .failed(let message):
                store.shareAcceptanceErrorMessage = message
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(
                    \.docketSurfacePalette,
                    darkerThemeEnabled ? .darker : .standard
                )
                .task { await store.bootstrap() }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    Task { await store.applicationBecameActive() }
                }
                .onReceive(
                    NotificationCenter.default.publisher(for: .CKAccountChanged)
                ) { _ in
                    Task { await store.handleICloudAccountChange() }
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
