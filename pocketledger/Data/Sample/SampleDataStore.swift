import Foundation

/// The in-memory backing store shared by all three `Sample*Repository`
/// types in the demo environment. An `actor` purely for the same reason
/// `PersistenceActor` is — serializing mutable state access — not because
/// this is ever accessed from multiple real threads under load.
actor SampleDataStore {
    private var walletProfile: WalletProfile
    private var accountsByID: [UUID: Account]
    private var transactionsByID: [UUID: Transaction]

    init() {
        walletProfile = SampleDataFactory.walletProfile()
        accountsByID = Dictionary(uniqueKeysWithValues: SampleDataFactory.accounts().map { ($0.id, $0) })
        transactionsByID = Dictionary(uniqueKeysWithValues: SampleDataFactory.transactions().map { ($0.id, $0) })
    }

    // MARK: - Wallet profile

    func profile() -> WalletProfile {
        walletProfile
    }

    // MARK: - Accounts

    func allAccounts() -> [Account] {
        accountsByID.values.sorted { $0.createdAt < $1.createdAt }
    }

    func account(id: UUID) -> Account? {
        accountsByID[id]
    }

    func upsertAccount(_ account: Account) {
        accountsByID[account.id] = account
    }

    func deleteAccount(id: UUID) throws {
        let hasTransactions = transactionsByID.values.contains {
            $0.sourceAccountID == id || $0.destinationAccountID == id
        }
        guard !hasTransactions else { throw RepositoryError.accountHasTransactions }
        accountsByID[id] = nil
    }

    // MARK: - Transactions

    func allTransactions() -> [Transaction] {
        Array(transactionsByID.values)
    }

    func transaction(id: UUID) -> Transaction? {
        transactionsByID[id]
    }

    func upsertTransaction(_ transaction: Transaction) {
        transactionsByID[transaction.id] = transaction
    }

    func deleteTransaction(id: UUID) {
        transactionsByID[id] = nil
    }

    // MARK: - Reset

    /// Backs the PRD's "Reset Demo Data" profile action.
    func resetToInitialSampleData() {
        walletProfile = SampleDataFactory.walletProfile()
        accountsByID = Dictionary(uniqueKeysWithValues: SampleDataFactory.accounts().map { ($0.id, $0) })
        transactionsByID = Dictionary(uniqueKeysWithValues: SampleDataFactory.transactions().map { ($0.id, $0) })
    }
}
