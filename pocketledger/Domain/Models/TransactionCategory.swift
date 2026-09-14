/// The fixed set of P0 expense categories.
///
/// Categories are intentionally not a separate, user-editable entity in
/// P0 — they are a small closed set, so a `categories` table/type would add
/// complexity without a real requirement behind it yet (see the Database
/// specification's "no categories table" decision).
enum TransactionCategory: String, Sendable, CaseIterable, Codable {
    case food
    case transport
    case shopping
    case bills
    case entertainment
}
