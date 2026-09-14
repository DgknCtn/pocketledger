/// The infrastructure → semantic error mapping shared by every repository.
/// A caller with endpoint-specific PostgREST `code` handling (e.g. 23503 on
/// account delete meaning "has transactions") checks that *before* falling
/// back to this generic mapping.
enum NetworkErrorMapping {
    static func repositoryError(for error: Error) -> RepositoryError {
        if error is PersistenceError {
            return .persistenceFailure
        }

        guard let networkError = error as? NetworkError else {
            return .unknown
        }

        switch networkError {
        case .transport:
            return .offline
        case .unauthorized, .forbidden:
            return .unauthorized
        case .rateLimited, .server:
            return .serviceUnavailable
        case .decoding, .invalidResponse, .invalidRequest:
            return .corruptedData
        case .cancelled:
            return .unknown
        case .api(_, let code, _):
            switch code {
            case "23503", "23505":
                return .conflict
            default:
                return .unknown
            }
        }
    }
}
