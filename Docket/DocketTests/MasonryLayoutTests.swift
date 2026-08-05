import CoreGraphics
import XCTest

@testable import Docket

/// The board's column count is derived from available width, so these pin the
/// two things that matter: a phone keeps its original two-column board, and a
/// wider screen gains columns instead of inflating cards.
final class MasonryLayoutTests: XCTestCase {
    private let layout = MasonryLayout(
        targetColumnWidth: DocketTheme.BoardItems.targetColumnWidth,
        minimumColumns: DocketTheme.BoardItems.minimumColumns,
        spacing: DocketTheme.BoardItems.columnSpacing
    )

    /// Board width for a device: screen width minus the board's 16pt margins.
    private func boardWidth(screen: CGFloat) -> CGFloat { screen - 32 }

    func testPhoneWidthsKeepTwoColumns() {
        for screen: CGFloat in [375, 390, 393, 402, 430, 440] {
            XCTAssertEqual(
                layout.columnCount(totalWidth: boardWidth(screen: screen)),
                2,
                "screen width \(screen) should stay a two-column board"
            )
        }
    }

    /// The target width is derived from this case, so it should land exactly.
    func testStandardPhoneColumnWidthMatchesTarget() {
        XCTAssertEqual(
            layout.columnWidth(totalWidth: boardWidth(screen: 390)),
            DocketTheme.BoardItems.targetColumnWidth,
            accuracy: 0.001
        )
    }

    func testTabletWidthsGainColumns() {
        // iPad mini portrait and landscape, and an 11" iPad portrait.
        XCTAssertEqual(layout.columnCount(totalWidth: boardWidth(screen: 744)), 4)
        XCTAssertEqual(layout.columnCount(totalWidth: boardWidth(screen: 1133)), 6)
        XCTAssertEqual(layout.columnCount(totalWidth: boardWidth(screen: 834)), 4)
    }

    /// The whole point: cards on a tablet stay close to phone size.
    func testTabletColumnWidthStaysNearTarget() {
        for screen: CGFloat in [744, 834, 1024, 1133, 1366] {
            let width = layout.columnWidth(totalWidth: boardWidth(screen: screen))
            XCTAssertEqual(
                width,
                DocketTheme.BoardItems.targetColumnWidth,
                accuracy: DocketTheme.BoardItems.targetColumnWidth * 0.25,
                "screen width \(screen) produced a \(width)pt card"
            )
        }
    }

    func testNarrowWidthsFallBackToMinimumColumns() {
        XCTAssertEqual(layout.columnCount(totalWidth: 300), 2)
        XCTAssertEqual(layout.columnCount(totalWidth: 120), 2)
        XCTAssertEqual(layout.columnCount(totalWidth: 0), 2)
    }

    func testDegenerateWidthsDoNotProduceInvalidColumnCounts() {
        XCTAssertEqual(layout.columnCount(totalWidth: -100), 2)
        XCTAssertEqual(layout.columnCount(totalWidth: .infinity), 2)
        XCTAssertEqual(layout.columnCount(totalWidth: .nan), 2)
        XCTAssertGreaterThanOrEqual(layout.columnWidth(totalWidth: 40), 0)
    }
}
