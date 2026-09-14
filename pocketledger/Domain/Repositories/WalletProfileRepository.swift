/// Domain-owned boundary for reading/creating the user's wallet profile.
///
/// The Domain layer only knows "give me the wallet profile" — it has no
/// knowledge of Supabase, REST, or SwiftData. A concrete implementation is
/// added in a later phase (Repositories & Remote/Local Coordination); this
/// protocol exists now so Domain code can depend on the abstraction rather
/// than a future concrete type.
protocol WalletProfileRepository: Sendable {
    func cachedProfile() async throws -> WalletProfile?
    func refreshProfile() async throws -> WalletProfile?
    func createProfile(baseCurrency: CurrencyCode) async throws -> WalletProfile
}
