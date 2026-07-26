import CloudKit
import XCTest

@testable import Docket

final class CloudKitFetchAccumulatorTests: XCTestCase {
    func testSnapshotContainsEverySuccessfulRecord() {
        let accumulator = CloudKitFetchAccumulator()
        let first = CKRecord(recordType: "Test", recordID: CKRecord.ID(recordName: "first"))
        let second = CKRecord(recordType: "Test", recordID: CKRecord.ID(recordName: "second"))

        accumulator.append(first)
        accumulator.append(second)
        let snapshot = accumulator.snapshot()

        XCTAssertEqual(Set(snapshot.records.map(\.recordID)), [first.recordID, second.recordID])
        XCTAssertNil(snapshot.error)
    }

    func testSnapshotPreservesFirstPartialFailure() {
        let accumulator = CloudKitFetchAccumulator()
        let first = CKError(.networkFailure)
        let second = CKError(.notAuthenticated)

        accumulator.record(first)
        accumulator.record(second)
        let snapshot = accumulator.snapshot()

        XCTAssertEqual((snapshot.error as? CKError)?.code, .networkFailure)
    }
}
