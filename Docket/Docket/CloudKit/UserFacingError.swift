import CloudKit
import Foundation

nonisolated enum UserFacingError {
    static func message(for error: Error) -> String {
        if let connectivityError = error as? BoardConnectivityError {
            return connectivityError.localizedDescription
        }
        if let serviceError = error as? CloudKitServiceError {
            return serviceError.localizedDescription
        }
        if let cloudError = error as? CKError {
            return message(for: cloudError)
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost,
                .cannotConnectToHost, .cannotFindHost, .timedOut:
                return "You're offline. Reconnect and try again."
            default:
                break
            }
        }
        return "Something went wrong with iCloud. Please try again."
    }

    private static func message(for error: CKError) -> String {
        if error.code == .partialFailure,
            let nestedError = error.partialErrorsByItemID?.values.first
        {
            return message(for: nestedError)
        }

        switch error.code {
        case .networkUnavailable, .networkFailure:
            return "You're offline. Reconnect and try again."
        case .serviceUnavailable, .requestRateLimited, .zoneBusy,
            .accountTemporarilyUnavailable:
            return "iCloud is temporarily unavailable. Try again in a moment."
        case .notAuthenticated:
            return "Sign in to iCloud in Settings, then try again."
        case .quotaExceeded:
            return "Your iCloud storage is full. Free up some space, then try again."
        case .permissionFailure:
            return "You don't have permission to make that change."
        case .participantMayNeedVerification:
            return
                "This invitation was sent to contact information that isn't linked to your iCloud account. Open the invitation again to verify it."
        case .unknownItem, .zoneNotFound, .userDeletedZone:
            return "This board is no longer available."
        default:
            return "Something went wrong with iCloud. Please try again."
        }
    }
}
