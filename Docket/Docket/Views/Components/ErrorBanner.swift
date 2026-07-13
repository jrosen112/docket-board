//
//  ErrorBanner.swift
//  Docket
//
//  Dismissable error strip shown over the board when a CloudKit call fails.
//  Dumb: message in, dismiss callback out.
//

import SwiftUI

struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DocketTheme.brass)
            Text(message)
                .font(.footnote)
                .foregroundStyle(DocketTheme.cream)
                .lineLimit(3)
            Spacer(minLength: 4)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DocketTheme.cream.opacity(0.7))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: 0x3A2A28))
                .stroke(DocketTheme.brass.opacity(0.4), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
}

#Preview {
    ErrorBanner(message: "Couldn't reach iCloud. Check your connection.") {}
        .padding(.vertical)
        .background(DocketTheme.ink)
}
