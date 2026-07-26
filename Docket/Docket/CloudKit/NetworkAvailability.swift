import Foundation
import Network

nonisolated enum NetworkAvailability: Equatable, Sendable {
    case available
    case unavailable
    case unknown
}

nonisolated protocol NetworkAvailabilityProviding: Sendable {
    func availability() async -> NetworkAvailability
}

nonisolated final class SystemNetworkAvailability: NetworkAvailabilityProviding, @unchecked Sendable {
    static let shared = SystemNetworkAvailability()

    private let monitor = NWPathMonitor()
    private let lock = NSLock()
    private var latestAvailability: NetworkAvailability = .unknown

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.setAvailability(for: path.status)
        }
        monitor.start(queue: DispatchQueue(label: "docket.network-availability"))
    }

    func availability() async -> NetworkAvailability {
        let current = lock.withLock { latestAvailability }
        guard current == .unknown else { return current }

        // Give a newly-started monitor one short window to publish its first
        // path. If it still has no answer, let CloudKit try rather than falsely
        // declaring an online user offline.
        try? await Task.sleep(for: .milliseconds(250))
        return lock.withLock { latestAvailability }
    }

    private func setAvailability(for status: NWPath.Status) {
        let availability: NetworkAvailability =
            switch status {
            case .satisfied: .available
            case .unsatisfied, .requiresConnection: .unavailable
            @unknown default: .unknown
            }
        lock.withLock { latestAvailability = availability }
    }

    deinit {
        monitor.cancel()
    }
}

nonisolated enum BoardConnectivityError: LocalizedError {
    case offline

    var errorDescription: String? {
        "You're offline. Reconnect and try again."
    }
}
