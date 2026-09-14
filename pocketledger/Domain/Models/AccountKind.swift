/// The kind of financial container an `Account` represents.
///
/// Raw values match the remote `accounts.kind` check constraint exactly.
/// There is deliberately no `cards` table — a credit card is just an
/// `Account` of kind `.creditCard`, whose balance is a signed net balance
/// (negative = amount owed).
enum AccountKind: String, Sendable, CaseIterable, Codable {
    case bank
    case cash
    case creditCard = "credit_card"
}
