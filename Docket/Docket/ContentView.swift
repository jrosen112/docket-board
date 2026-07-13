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
            switch store.loadState {
            case .loading:
                loadingView
            case .failed(let message):
                loadFailureView(message: message)
            case .loaded:
                if store.currentProfile == nil {
                    ProfileSetupView()
                } else {
                    BoardView()
                }
            }
        }
        .tint(DocketTheme.brass)
    }

    private var loadingView: some View {
        ZStack {
            Rectangle()
                .fill(DocketTheme.boardBackground)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "pin.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(DocketTheme.brass)
                Text("Docket")
                    .font(DocketTheme.display(24))
                    .foregroundStyle(DocketTheme.cream)
                ProgressView()
                    .tint(DocketTheme.cream)
            }
        }
    }

    private func loadFailureView(message: String) -> some View {
        ZStack {
            Rectangle()
                .fill(DocketTheme.boardBackground)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "icloud.slash")
                    .font(.system(size: 32))
                    .foregroundStyle(DocketTheme.brass)
                Text("Couldn't load your board")
                    .font(DocketTheme.display(22))
                    .foregroundStyle(DocketTheme.cream)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(DocketTheme.cream.opacity(0.75))
                    .multilineTextAlignment(.center)
                Button("Try Again") {
                    Task { await store.bootstrap() }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(28)
        }
    }
}

#Preview {
    ContentView()
        .environment(BoardStore())
}
