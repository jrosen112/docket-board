//
//  BoardReactionKindTests.swift
//  DocketTests
//
//  Reactions are no longer a closed set — the long-press picker's `+` can
//  produce any emoji — so the guard against non-emoji reaching a field that is
//  rendered as a glyph is validation rather than the type system.
//

import XCTest

@testable import Docket

final class BoardReactionKindTests: XCTestCase {

    func testStandardKindsSurviveTheirOwnValidation() {
        for kind in BoardReactionKind.standard {
            XCTAssertNotNil(
                BoardReactionKind(rawValue: kind.rawValue),
                "\(kind.rawValue) is offered by the picker but fails validation"
            )
            XCTAssertTrue(kind.isStandard)
            XCTAssertNotEqual(kind.label, kind.rawValue, "standard kinds have spoken names")
        }
    }

    func testAcceptsEmojiOutsideTheStandardSet() {
        let pizza = BoardReactionKind(rawValue: "🍕")

        XCTAssertEqual(pizza?.rawValue, "🍕")
        XCTAssertFalse(try XCTUnwrap(pizza).isStandard)
        // No name of ours to give, so VoiceOver reads the glyph.
        XCTAssertEqual(pizza?.label, "🍕")
    }

    /// Multi-scalar emoji are one grapheme cluster and have to be accepted
    /// whole, not mistaken for several characters.
    func testAcceptsMultiScalarEmoji() {
        for emoji in ["❤️‍🔥", "🇺🇸", "👩‍👩‍👦", "🌶️", "1️⃣"] {
            XCTAssertNotNil(BoardReactionKind(rawValue: emoji), emoji)
        }
    }

    func testRejectsAnythingThatIsNotExactlyOneEmoji() {
        for candidate in ["", " ", "a", "7", "hello", "🍕🍕", "🍕!", "<b>"] {
            XCTAssertNil(
                BoardReactionKind(rawValue: candidate),
                "\(candidate) should not be usable as a reaction"
            )
        }
    }

    func testSurroundingWhitespaceIsTrimmedRatherThanRejected() {
        XCTAssertEqual(BoardReactionKind(rawValue: " 🍕\n")?.rawValue, "🍕")
    }

    /// A typo in the catalog would silently drop an emoji from the grid rather
    /// than fail, so the count is checked against the source list.
    func testEveryCatalogEmojiIsValidAndDistinct() {
        let kinds = BoardEmojiCatalog.kinds

        XCTAssertEqual(
            kinds.count,
            BoardEmojiCatalog.rawEmoji.count,
            "an entry in the catalog is not a single valid emoji"
        )
        XCTAssertEqual(Set(kinds).count, kinds.count, "the grid repeats an emoji")
    }
}
