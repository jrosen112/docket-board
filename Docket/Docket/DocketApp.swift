//
//  DocketApp.swift
//  Docket
//
//  Created by Jared Rosen on 7/12/26.
//

import SwiftUI

@main
struct DocketApp: App {
    @State private var store = BoardStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .task { await store.bootstrap() }
        }
    }
}
