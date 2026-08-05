//
//  ProfileAvatar.swift
//  Docket
//
//  One person as a circle: their profile picture when there is one, their
//  initials on brass when there isn't. `imageData` is always nil today — the
//  `profilePicture` CKAsset does not exist yet — so every avatar renders as
//  initials. Wiring it later upgrades every avatar in the app at once.
//
//  Dumb component — everything it shows arrives via init.
//

import SwiftUI
import UIKit

struct ProfileAvatar: View {
    let initials: String
    var imageData: Data?
    var size: CGFloat = DocketTheme.Avatar.defaultSize
    /// Ring drawn around the circle so overlapping avatars stay separable.
    var ringColor: Color?

    var body: some View {
        content
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay {
                if let ringColor {
                    Circle()
                        .strokeBorder(ringColor, lineWidth: DocketTheme.Avatar.ringWidth)
                }
            }
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        if let imageData, let image = UIImage(data: imageData) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Text(initials)
                .font(.system(size: size * DocketTheme.Avatar.initialsScale, weight: .semibold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .foregroundStyle(DocketTheme.ink)
                .frame(width: size, height: size)
                .background(DocketTheme.brass)
        }
    }
}
