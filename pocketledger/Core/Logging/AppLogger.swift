import Foundation
import OSLog

/// Categorized `Logger` access points for the app.
///
/// Every subsystem logs through one of these categories instead of ad-hoc
/// `print()` calls. Sensitive values — access/refresh tokens, authorization
/// headers, transaction notes, full request/response bodies — must never be
/// passed to any of these loggers, including at `.debug` level.
enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "pocketledger"

    static let network = Logger(subsystem: subsystem, category: "network")
    static let persistence = Logger(subsystem: subsystem, category: "persistence")
    static let security = Logger(subsystem: subsystem, category: "security")
    static let session = Logger(subsystem: subsystem, category: "session")
    static let analytics = Logger(subsystem: subsystem, category: "analytics")
    static let general = Logger(subsystem: subsystem, category: "general")
}
