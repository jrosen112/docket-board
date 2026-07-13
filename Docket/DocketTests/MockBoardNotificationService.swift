@testable import Docket

actor MockBoardNotificationService: BoardNotificationService {
    private(set) var prepareCount = 0
    private(set) var notices: [BoardChangeNotice] = []

    func prepare() async throws {
        prepareCount += 1
    }

    func post(_ notice: BoardChangeNotice) async throws {
        notices.append(notice)
    }

    func capturedNotices() -> [BoardChangeNotice] {
        notices
    }
}
