/// Failures from the local SwiftData cache layer. These are distinct from
/// `RepositoryError` (added once repositories exist): a persistence
/// failure does not necessarily mean the operation as a whole failed — see
/// the Architecture specification's "remote succeeds, local save fails"
/// scenario, where the repository logs this and treats the cache as stale
/// rather than surfacing it to the user.
enum PersistenceError: Error, Sendable, Equatable {
    case saveFailed
    case fetchFailed
    /// A cached record could not be mapped back to its domain type (e.g. an
    /// unrecognized `kindRawValue`) — local data corruption, not something
    /// a user action can cause in a correctly-functioning app.
    case corruptedRecord
}
