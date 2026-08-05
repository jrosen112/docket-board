//
//  DocketThemeTests.swift
//  DocketTests
//
//  The theme's one piece of real logic: deterministic card rotation.
//

import XCTest

@testable import Docket

final class DocketThemeTests: XCTestCase {

    func testSkeletonShimmerProgressRepeatsWithinUnitRange() {
        let quarterCycle = Date(
            timeIntervalSinceReferenceDate: DocketTheme.BoardSkeleton.shimmerDuration * 2.25
        )

        XCTAssertEqual(
            DocketTheme.BoardSkeleton.shimmerProgress(at: quarterCycle),
            0.25,
            accuracy: 0.0001
        )
    }

    func testRotationIsDeterministicForSameKey() {
        // hashValue is process-seeded; this must NOT be — a card's tilt should
        // survive refreshes and relaunches.
        let key = UUID().uuidString
        XCTAssertEqual(
            DocketTheme.rotationDegrees(for: key),
            DocketTheme.rotationDegrees(for: key)
        )
    }

    func testRotationStaysWithinTiltRange() {
        for _ in 0..<200 {
            let degrees = DocketTheme.rotationDegrees(for: UUID().uuidString)
            XCTAssertGreaterThanOrEqual(degrees, -1.5)
            XCTAssertLessThanOrEqual(degrees, 1.5)
        }
    }

    func testDifferentKeysProduceVariedTilts() {
        // Not all cards should lean the same way.
        let tilts = Set((0..<50).map { DocketTheme.rotationDegrees(for: "card-\($0)") })
        XCTAssertGreaterThan(tilts.count, 10)
    }

    func testScrollNoteIsHiddenBeforeFadeRange() {
        XCTAssertEqual(DocketTheme.BoardScrollNote.progress(for: 0), 0)
        XCTAssertEqual(
            DocketTheme.BoardScrollNote.progress(
                for: DocketTheme.BoardScrollNote.fadeStart - 1
            ),
            0
        )
    }

    func testScrollNoteFadesProgressively() {
        let midpoint =
            DocketTheme.BoardScrollNote.fadeStart
            + DocketTheme.BoardScrollNote.fadeDistance / 2
        XCTAssertEqual(DocketTheme.BoardScrollNote.progress(for: midpoint), 0.5)
    }

    func testScrollNoteStaysVisiblePastFadeRange() {
        let beyondFade =
            DocketTheme.BoardScrollNote.fadeStart
            + DocketTheme.BoardScrollNote.fadeDistance
            + 1_000
        XCTAssertEqual(DocketTheme.BoardScrollNote.progress(for: beyondFade), 1)
    }

    // MARK: Long-press surface

    /// The lifted card is a `BoardItemQuickLookView` at its own fixed width, and
    /// the picker, chips, and menu are laid out at the surface width. If those
    /// ever drift apart the column stops reading as one object.
    func testLongPressSurfaceMatchesTheLiftedCardWidth() {
        XCTAssertEqual(
            DocketTheme.BoardLongPress.surfaceWidth,
            DocketDetailTheme.QuickLook.width
        )
    }

    /// The picker has to fit the narrowest supported phone even in its widest
    /// state: six standard kinds, the user's own custom pick, a divider and `+`.
    func testWidestPickerBarFitsTheNarrowestPhone() {
        let tokens = DocketTheme.BoardLongPress.self
        let slots = CGFloat(BoardReactionKind.standard.count + 2)
        let width =
            slots * tokens.pickerButtonSize
            + (slots - 1) * tokens.pickerSpacing
            + tokens.pickerPadding * 2
            // Divider rule plus the padding on either side of it.
            + 5

        XCTAssertLessThanOrEqual(width, 375 - tokens.screenMargin * 2)
    }
}
