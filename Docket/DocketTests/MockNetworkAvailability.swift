@testable import Docket

actor MockNetworkAvailability: NetworkAvailabilityProviding {
    private var currentAvailability: NetworkAvailability

    init(_ availability: NetworkAvailability = .available) {
        currentAvailability = availability
    }

    func availability() -> NetworkAvailability {
        currentAvailability
    }

    func set(_ availability: NetworkAvailability) {
        currentAvailability = availability
    }
}
