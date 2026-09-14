import Foundation

/// Tunable local-security parameters, kept out of `AppLockController`'s
/// logic so the threshold is a configuration value, not a hard-coded
/// constant buried in a conditional (see the Architecture specification).
struct SecurityPolicy: Sendable {
    /// How long the app may sit backgrounded before returning to the
    /// foreground requires re-authentication.
    var reauthenticationInterval: TimeInterval = 30
}
