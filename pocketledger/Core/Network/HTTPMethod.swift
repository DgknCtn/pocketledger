/// The HTTP verbs PocketLedger needs. Supabase's Data API also supports
/// `PUT`, but P0 never uses it, so it is intentionally left out.
enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case delete = "DELETE"
}
