import Foundation

struct SampleWalletProfileRepository: WalletProfileRepository {
    private let store: SampleDataStore

    init(store: SampleDataStore) {
        self.store = store
    }

    func cachedProfile() async throws -> WalletProfile? {
        await store.profile()
    }

    func refreshProfile() async throws -> WalletProfile? {
        await store.profile()
    }

    func createProfile(baseCurrency: CurrencyCode) async throws -> WalletProfile {
        await store.profile()
    }
}
