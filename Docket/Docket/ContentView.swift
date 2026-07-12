//
//  ContentView.swift
//  Docket
//
//  Created by Jared Rosen on 7/12/26.
//
//  Top-level gate: show a loading state until the first CloudKit load finishes,
//  then either onboard a profile or show the board. Styling is intentionally
//  plain for now — the "corkboard" look is layered on later.
//

import SwiftUI

struct ContentView: View {
    @Environment(BoardStore.self) private var store

    var body: some View {
        Group {
            if !store.hasLoadedOnce {
                ProgressView("Loading…")
            } else if store.currentProfile == nil {
                ProfileSetupView()
            } else {
                BoardView()
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(BoardStore())
}
