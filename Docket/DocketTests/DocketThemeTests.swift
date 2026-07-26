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

    func testSparseMovieCardsUseShorterPosterRatio() {
        XCTAssertEqual(DocketTheme.BoardCard.moviePosterAspectRatio(forCueCount: 0), 3.0 / 4.0)
        XCTAssertEqual(DocketTheme.BoardCard.moviePosterAspectRatio(forCueCount: 2), 3.0 / 4.0)
        XCTAssertEqual(DocketTheme.BoardCard.moviePosterAspectRatio(forCueCount: 3), 2.0 / 3.0)
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
}
