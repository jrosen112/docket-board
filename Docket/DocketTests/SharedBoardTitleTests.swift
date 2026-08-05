import Foundation
import XCTest

@testable import Docket

/// Invite acceptance and later-device discovery share this resolution, so a
/// joined board keeps one name across a user's devices instead of degrading to
/// a generic "Shared Board" on the second one.
final class SharedBoardTitleTests: XCTestCase {
    func testShareTitleWinsOverOwnerName() {
        XCTAssertEqual(
            SharedBoardTitle.resolve(shareTitle: "Date Nights", ownerName: "Dana"),
            "Date Nights"
        )
    }

    func testBlankShareTitleFallsBackToOwnerName() {
        XCTAssertEqual(
            SharedBoardTitle.resolve(shareTitle: "   ", ownerName: "Dana"),
            "Dana’s Board"
        )
        XCTAssertEqual(
            SharedBoardTitle.resolve(shareTitle: nil, ownerName: "Dana"),
            "Dana’s Board"
        )
    }

    func testOwnerNameEndingInSTakesBarePossessive() {
        XCTAssertEqual(
            SharedBoardTitle.resolve(shareTitle: nil, ownerName: "Chris"),
            "Chris’ Board"
        )
    }

    func testNothingResolvableLeavesTheFallbackToTheCaller() {
        XCTAssertNil(SharedBoardTitle.resolve(shareTitle: nil, ownerName: nil))
        XCTAssertNil(SharedBoardTitle.resolve(shareTitle: "", ownerName: " "))
    }

    func testOwnerNameFormatsIdentityComponents() {
        var components = PersonNameComponents()
        components.givenName = "Dana"
        components.familyName = "Nguyen"

        XCTAssertEqual(SharedBoardTitle.ownerName(from: components), "Dana")
        XCTAssertNil(SharedBoardTitle.ownerName(from: nil))
        XCTAssertNil(SharedBoardTitle.ownerName(from: PersonNameComponents()))
    }
}
