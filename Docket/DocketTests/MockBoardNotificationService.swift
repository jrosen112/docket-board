@testable import Docket

actor MockBoardNotificationService: BoardNotificationService {
    private(set) var prepareCount = 0
    private(set) var notices: [BoardChangeNotice] = []
    private var prepareError: Error?

    func prepare() async throws {
        prepareCount += 1
        if let prepareError { throw prepareError }
    }

    func post(_ notice: BoardChangeNotice) async throws {
        notices.append(notice)
    }

    func capturedNotices() -> [BoardChangeNotice] {
        notices
    }

    func setPrepareError(_ error: Error?) {
        prepareError = error
    }
}
