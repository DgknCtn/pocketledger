/// The user's single wallet-level setting: the base currency every account
/// and transaction is denominated in.
///
/// P0 is single-currency by design (see the Database specification) — once
/// any account or transaction exists, the base currency becomes immutable,
/// which is enforced by the (future) `WalletProfileRepository`
/// implementation, not by this model.
struct WalletProfile: Equatable, Sendable {
    let baseCurrency: CurrencyCode
}
