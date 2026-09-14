/// The error body PostgREST returns for a failed Data API request.
///
/// Callers must branch on `code` (a stable PostgreSQL/PostgREST SQLSTATE-ish
/// identifier, e.g. `"23503"` for a foreign-key violation) — never on
/// `message`, which is free-form text not meant for programmatic matching.
struct PostgRESTErrorDTO: Decodable, Sendable {
    let code: String
    let details: String?
    let hint: String?
    let message: String
}
