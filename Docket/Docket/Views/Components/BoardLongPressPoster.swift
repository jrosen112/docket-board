//
//  BoardLongPressPoster.swift
//  Docket
//
//  A lifted movie's artwork, as its own panel under the title card.
//
//  The poster is not part of the card because it cannot fit inside one: a 2:3
//  poster at the surface's width is taller than most of a phone. Standing on
//  its own it can take whatever height the column has left over
//  (`BoardLongPressLayoutSolver`) and stay whole at any of them.
//
//  Dumb component — everything it shows arrives via init.
//

import SwiftUI

struct BoardLongPressPoster: View {
    let data: Data
    let height: CGFloat
    let title: String

    private var width: CGFloat {
        min(
            height * DocketTheme.BoardLongPress.posterAspectRatio,
            DocketTheme.BoardLongPress.surfaceWidth
        )
    }

    var body: some View {
        // `.fit` rather than `.fill`: artwork that is not exactly 2:3 should
        // letterbox against the backing rather than lose its edges.
        ItemPhotoImage(data: data, contentMode: .fit)
            .frame(width: width, height: height)
            .background(DocketTheme.BoardLongPress.posterBackground)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: DocketTheme.BoardLongPress.posterCornerRadius,
                    style: .continuous
                )
            )
            .boardLongPressShadow()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Poster for \(title)")
    }
}
