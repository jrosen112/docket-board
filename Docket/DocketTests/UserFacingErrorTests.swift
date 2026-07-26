import CloudKit
import XCTest

@testable import Docket

final class UserFacingErrorTests: XCTestCase {
    func testNetworkFailureUsesShortOfflineMessage() {
        XCTAssertEqual(
            UserFacingError.message(for: CKError(.networkFailure)),
            "You're offline. Reconnect and try again."
        )
    }

    func testAuthenticationFailureExplainsRequiredAction() {
        XCTAssertEqual(
            UserFacingError.message(for: CKError(.notAuthenticated)),
            "Sign in to iCloud in Settings, then try again."
        )
    }

    func testUnexpectedCloudKitFailureDoesNotLeakTechnicalDescription() {
        let message = UserFacingError.message(for: CKError(.internalError))

        XCTAssertEqual(message, "Something went wrong with iCloud. Please try again.")
        XCTAssertFalse(message.contains("CKError"))
    }
}
