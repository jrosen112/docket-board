import CoreGraphics
import XCTest

@testable import Docket

final class BoardLongPressLayoutTests: XCTestCase {
    /// Chrome totalling 328pt: a 54pt picker, a 42pt attribution row, a 196pt
    /// four-row menu, and three 12pt gaps.
    private func metrics(
        cardHeight: CGFloat,
        attributionHeight: CGFloat = 42,
        poster: BoardLongPressPosterMetrics? = nil
    ) -> BoardLongPressMetrics {
        BoardLongPressMetrics(
            pickerHeight: 54,
            cardHeight: cardHeight,
            attributionHeight: attributionHeight,
            menuHeight: 196,
            spacing: 12,
            screenMargin: 16,
            minimumCardScale: 0.62,
            poster: poster
        )
    }

    /// A 2:3 poster with a 180pt floor and a 480pt ceiling.
    private let poster = BoardLongPressPosterMetrics(
        aspectRatio: 2.0 / 3.0,
        minimumHeight: 180,
        maximumHeight: 480
    )

    /// iPhone-sized container, leaving 699pt of usable height.
    private func solve(
        cardHeight: CGFloat,
        attributionHeight: CGFloat = 42,
        containerHeight: CGFloat = 812,
        poster: BoardLongPressPosterMetrics? = nil
    ) -> BoardLongPressLayout {
        BoardLongPressLayoutSolver.solve(
            containerHeight: containerHeight,
            safeAreaTop: 47,
            safeAreaBottom: 34,
            metrics: metrics(
                cardHeight: cardHeight,
                attributionHeight: attributionHeight,
                poster: poster
            )
        )
    }

    func testCardKeepsFullSizeWhenTheColumnFits() {
        let layout = solve(cardHeight: 300)

        XCTAssertEqual(layout.cardScale, 1)
        XCTAssertEqual(layout.columnHeight, 628)
        XCTAssertEqual(layout.availableHeight, 699)
        XCTAssertFalse(layout.scrolls)
    }

    /// The whole point of the centered column: a card too tall for the screen
    /// gives up height so the picker and menu never have to move or shrink.
    func testTallCardShrinksToFitTheColumn() {
        let layout = solve(cardHeight: 500)

        XCTAssertEqual(layout.cardScale, 371.0 / 500.0, accuracy: 0.0001)
        XCTAssertEqual(layout.columnHeight, 699, accuracy: 0.0001)
        XCTAssertFalse(layout.scrolls)
    }

    func testCardAtExactlyTheAvailableHeightIsNotScaled() {
        // 699 available - 328 of chrome leaves exactly 371 for the card.
        let layout = solve(cardHeight: 371)

        XCTAssertEqual(layout.cardScale, 1)
        XCTAssertFalse(layout.scrolls)
    }

    func testShrinkingStopsAtTheFloorAndTheColumnScrolls() {
        let layout = solve(cardHeight: 1_200)

        XCTAssertEqual(layout.cardScale, 0.62)
        XCTAssertEqual(layout.columnHeight, 328 + 1_200 * 0.62, accuracy: 0.0001)
        XCTAssertTrue(layout.scrolls)
    }

    /// An item nobody has reacted to should not pay for the row it doesn't
    /// show, gap included.
    func testAbsentAttributionRowTakesItsSpacingWithIt() {
        let withChips = solve(cardHeight: 500)
        let withoutChips = solve(cardHeight: 500, attributionHeight: 0)

        XCTAssertEqual(
            withoutChips.cardScale * 500 - withChips.cardScale * 500,
            54,
            accuracy: 0.0001
        )
    }

    /// A short card on a small screen still can't push the chrome around; the
    /// column scrolls instead.
    func testChromeAloneOverflowingASmallScreenScrolls() {
        let layout = solve(cardHeight: 200, containerHeight: 480)

        XCTAssertEqual(layout.cardScale, 0.62)
        XCTAssertTrue(layout.scrolls)
    }

    /// Guards the rounding tolerance. At 599pt the card is a hair too tall to
    /// scale into place, so it lands on the floor scale and overflows by 0.38pt
    /// — noise, not a reason to start scrolling.
    func testColumnOverflowingWithinRoundingToleranceDoesNotScroll() {
        let layout = solve(cardHeight: 599)

        XCTAssertEqual(layout.cardScale, 0.62)
        XCTAssertGreaterThan(layout.columnHeight, layout.availableHeight)
        XCTAssertFalse(layout.scrolls)
    }

    func testDegenerateContainerDoesNotProduceNegativeRoom() {
        let layout = BoardLongPressLayoutSolver.solve(
            containerHeight: 0,
            safeAreaTop: 0,
            safeAreaBottom: 0,
            metrics: metrics(cardHeight: 300)
        )

        XCTAssertEqual(layout.availableHeight, 0)
        XCTAssertEqual(layout.cardScale, 0.62)
        XCTAssertTrue(layout.scrolls)
    }

    // MARK: Poster panel

    func testItemWithoutArtworkGetsNoPosterPanel() {
        XCTAssertNil(solve(cardHeight: 300).posterHeight)
    }

    /// The poster takes everything the card left behind rather than a fixed
    /// size, so a movie fills the screen it is given. Chrome here is 520 —
    /// 328 as usual plus the poster's 180pt floor and its gap — leaving 179 for
    /// the card, of which a 120pt card uses 120.
    func testPosterTakesTheRoomTheCardDidNotNeed() {
        let layout = solve(cardHeight: 120, poster: poster)

        XCTAssertEqual(layout.cardScale, 1)
        XCTAssertEqual(try XCTUnwrap(layout.posterHeight), 180 + 59, accuracy: 0.0001)
        XCTAssertEqual(layout.columnHeight, 699, accuracy: 0.0001)
        XCTAssertFalse(layout.scrolls)
    }

    /// The poster stops at its ceiling rather than taking every point the
    /// column can spare.
    func testPosterStopsAtItsCeiling() {
        let layout = solve(
            cardHeight: 200,
            attributionHeight: 0,
            containerHeight: 1_400,
            poster: poster
        )

        XCTAssertEqual(layout.posterHeight, 480)
        XCTAssertFalse(layout.scrolls)
    }

    /// A movie's card yields room to its own artwork: the poster's floor is
    /// charged before the card is sized, so the card scales rather than the
    /// poster dropping below the point of being worth showing.
    func testCardYieldsToThePostersFloorBeforeThePosterShrinks() {
        let layout = solve(cardHeight: 250, poster: poster)

        XCTAssertEqual(try XCTUnwrap(layout.posterHeight), 180)
        XCTAssertEqual(layout.cardScale, 179.0 / 250.0, accuracy: 0.0001)
        XCTAssertEqual(layout.columnHeight, 699, accuracy: 0.0001)
        XCTAssertFalse(layout.scrolls)
    }

    /// Once the card is at its floor and the poster at its own, there is
    /// nothing left to give and the column scrolls.
    func testColumnScrollsWhenNeitherCardNorPosterCanGiveMore() {
        let layout = solve(cardHeight: 600, containerHeight: 600, poster: poster)

        XCTAssertEqual(layout.cardScale, 0.62)
        XCTAssertEqual(try XCTUnwrap(layout.posterHeight), 180)
        XCTAssertTrue(layout.scrolls)
    }
}
