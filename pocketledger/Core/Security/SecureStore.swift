import Foundation

/// The small set of secrets PocketLedger ever stores in the Keychain.
/// Transactions, accounts, analytics and every other financial value are
/// never Keychain content — see `SecureStore`'s documentation.
enum SecureKey: String, Sendable {
    case userSession
}

/// Abstracts secure, small-secret storage (Keychain in production) behind a
/// protocol so `SessionManager` can be tested without touching the real
/// Keychain.
///
/// This is deliberately narrow: it stores the session token blob only.
/// Financial data (accounts, transactions, analytics) never goes through
/// this type — the Keychain is not a database replacement.
protocol SecureStore: Sendable {
    func data(for key: SecureKey) throws -> Data?
    func save(_ data: Data, for key: SecureKey) throws
    func delete(_ key: SecureKey) throws
}
