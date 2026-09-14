import Foundation

/// Errors surfaced when required build-time configuration is missing or
/// malformed. This is intentionally distinct from `NetworkError` /
/// `RepositoryError` (added in later phases) — it represents a
/// misconfigured build, not a runtime/network failure.
enum AppConfigurationError: Error, Equatable, Sendable {
    case missingValue(key: String)
    case invalidURL(key: String, value: String)
}

/// Reads environment-dependent, non-secret configuration values.
///
/// Values originate from `Config/Debug.xcconfig` / `Config/Release.xcconfig`
/// (via `INFOPLIST_KEY_*` build settings), never from literals in source.
/// This intentionally only reads the Supabase *publishable* key — the
/// secret/service-role key must never exist in this app.
struct AppConfiguration: Sendable {
    let supabaseURL: URL
    let supabasePublishableKey: String

    init(bundle: Bundle = .main) throws {
        let urlString = try Self.string(for: "SupabaseURL", in: bundle)
        guard let url = URL(string: urlString) else {
            throw AppConfigurationError.invalidURL(key: "SupabaseURL", value: urlString)
        }

        self.supabaseURL = url
        self.supabasePublishableKey = try Self.string(for: "SupabasePublishableKey", in: bundle)
    }

    private static func string(for key: String, in bundle: Bundle) throws -> String {
        guard
            let value = bundle.object(forInfoDictionaryKey: key) as? String,
            !value.isEmpty
        else {
            throw AppConfigurationError.missingValue(key: key)
        }

        return value
    }
}
