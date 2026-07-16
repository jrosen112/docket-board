import CloudKit
import XCTest
@testable import Docket

@MainActor
final class ShareAcceptanceRouterTests: XCTestCase {
    func testNotificationDeepLinkWaitsForColdLaunchHandler() {
        let router = BoardDeepLinkRouter()
        let link = BoardDeepLink(
            spaceID: "joined:owner/board",
            itemRecordName: "movie-heat"
        )
        var received: [BoardDeepLink] = []

        router.route(link)
        XCTAssertTrue(received.isEmpty)

        router.install { received.append($0) }

        XCTAssertEqual(received, [link])
    }

    func testEventWaitsForHandlerDuringColdLaunch() {
        let router = CloudKitShareAcceptanceRouter()
        let event = CloudKitShareAcceptanceEvent.accepted(
            AcceptedCloudKitShare(
                zoneID: CKRecordZone.ID(
                    zoneName: "SharedSpace-test",
                    ownerName: "owner"
                ),
                title: "Weekend Plans"
            )
        )
        var receivedEvents: [CloudKitShareAcceptanceEvent] = []

        router.route(event)
        XCTAssertTrue(receivedEvents.isEmpty)

        router.install { receivedEvents.append($0) }

        XCTAssertEqual(receivedEvents, [event])
    }

    func testInstalledHandlerReceivesEventImmediately() {
        let router = CloudKitShareAcceptanceRouter()
        let event = CloudKitShareAcceptanceEvent.failed(message: "Try again")
        var receivedEvents: [CloudKitShareAcceptanceEvent] = []
        router.install { receivedEvents.append($0) }

        router.route(event)

        XCTAssertEqual(receivedEvents, [event])
    }
}
