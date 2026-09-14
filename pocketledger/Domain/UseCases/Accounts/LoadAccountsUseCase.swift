/// Aggregates accounts with their derived current balance —
/// `AccountRepository` alone only knows about `Account`, not
/// `AccountSummary`, so this is real aggregation (see the Architecture
/// specification's "Not Every Function Needs a Use Case": this one earns
/// its place).
struct LoadAccountsUseCase {
    let accountRepository: AccountRepository
    let transactionRepository: TransactionRepository

    func loadCached() async throws -> [AccountSummary] {
        let accounts = try await accountRepository.cachedAccounts()
        let transactions = try await transactionRepository.cachedTransactions()
        return try summaries(for: accounts, transactions: transactions)
    }

    func refresh() async throws -> [AccountSummary] {
        async let accountsTask = accountRepository.refreshAccounts()
        async let transactionsTask = transactionRepository.refreshTransactions()
        let (accounts, transactions) = try await (accountsTask, transactionsTask)
        return try summaries(for: accounts, transactions: transactions)
    }

    private func summaries(for accounts: [Account], transactions: [Transaction]) throws -> [AccountSummary] {
        try accounts.map { account in
            AccountSummary(
                account: account,
                currentBalance: try AccountBalanceCalculator.balance(for: account, transactions: transactions)
            )
        }
    }
}
