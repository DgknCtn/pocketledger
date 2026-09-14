/// Translates `RepositoryError` into copy a user can actually read. Raw
/// infrastructure errors (HTTP status codes, PostgreSQL error codes, Swift
/// error type names) must never reach this far — see the API
/// specification's "UI Is Never Aware of HTTP Status".
enum PresentationErrorMapper {
    static func message(for error: Error) -> String {
        guard let repositoryError = error as? RepositoryError else {
            return "Something went wrong. Please try again."
        }

        switch repositoryError {
        case .offline:
            return "You appear to be offline. Showing your most recent saved data."
        case .unauthorized:
            return "Your session expired. Please restart the app."
        case .notFound:
            return "That item couldn't be found. It may have already been removed."
        case .conflict:
            return "That change couldn't be saved. Please try again."
        case .serviceUnavailable:
            return "PocketLedger's servers are temporarily unavailable. Please try again shortly."
        case .corruptedData, .persistenceFailure:
            return "We couldn't load your saved data."
        case .accountHasTransactions:
            return "This account has transaction history and can't be deleted. Archive it instead."
        case .walletProfileMissing:
            return "Set up your wallet before continuing."
        case .unknown:
            return "Something went wrong. Please try again."
        }
    }
}
