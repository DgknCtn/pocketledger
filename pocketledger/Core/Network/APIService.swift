import Foundation

/// Which Supabase API surface a request targets. PocketLedger talks to
/// Supabase's REST endpoints directly via `URLSession` — never the Supabase
/// Swift SDK — so the two base paths are modeled explicitly here.
enum APIService: Sendable {
    case auth
    case data

    func baseURL(supabaseURL: URL) -> URL {
        switch self {
        case .auth:
            supabaseURL.appendingPathComponent("auth/v1")
        case .data:
            supabaseURL.appendingPathComponent("rest/v1")
        }
    }
}
