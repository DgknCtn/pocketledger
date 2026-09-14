/// Semantic errors a repository can produce — infrastructure failures
/// (`NetworkError`, `PersistenceError`) translated into meanings the
/// Presentation layer can turn into user-facing copy without ever seeing an
/// HTTP status code or a PostgreSQL error code.
enum RepositoryError: Error, Sendable, Equatable {
    case offline
    case unauthorized
    case notFound
    case conflict
    case serviceUnavailable
    case corruptedData
    case persistenceFailure
    /// The account has transaction history — the server's foreign-key
    /// constraint refused the delete (see the database specification's
    /// account delete policy: archive instead).
    case accountHasTransactions
    /// No wallet profile exists yet for this user — onboarding hasn't
    /// created one, so a base currency can't be resolved for mapping.
    case walletProfileMissing
    case unknown
}
