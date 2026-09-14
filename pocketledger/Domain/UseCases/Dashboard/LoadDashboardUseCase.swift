/// Combines Account + Transaction + WalletProfile data into one
/// `DashboardSnapshot` — real cross-repository aggregation (total balance,
/// current-vs-previous-month totals with transfers excluded, recent
/// activity), which is exactly the kind of use case that earns its place
/// rather than being a passthrough (see the Architecture specification).
struct LoadDashboardUseCase {
    let accountRepository: AccountRepository
    let transactionRepository: TransactionRepository
    let walletProfileRepository: WalletProfileRepository
    var today: @Sendable () -> LocalDate = { .today() }

    func loadCached() async throws -> DashboardSnapshot {
        let accounts = try await accountRepository.cachedAccounts()
        let transactions = try await transactionRepository.cachedTransactions()
        guard let currency = try await walletProfileRepository.cachedProfile()?.baseCurrency else {
            throw RepositoryError.walletProfileMissing
        }
        return try makeSnapshot(accounts: accounts, transactions: transactions, currency: currency)
    }

    func refresh() async throws -> DashboardSnapshot {
        async let accountsTask = accountRepository.refreshAccounts()
        async let transactionsTask = transactionRepository.refreshTransactions()
        async let profileTask = walletProfileRepository.refreshProfile()
        let (accounts, transactions, profile) = try await (accountsTask, transactionsTask, profileTask)

        guard let currency = profile?.baseCurrency else {
            throw RepositoryError.walletProfileMissing
        }
        return try makeSnapshot(accounts: accounts, transactions: transactions, currency: currency)
    }

    private func makeSnapshot(
        accounts: [Account],
        transactions: [Transaction],
        currency: CurrencyCode
    ) throws -> DashboardSnapshot {
        let today = today()
        let activeAccounts = accounts.filter { !$0.isArchived }
        let summaries = try activeAccounts.map { account in
            AccountSummary(
                account: account,
                currentBalance: try AccountBalanceCalculator.balance(for: account, transactions: transactions)
            )
        }
        let totalBalance = try Money.sum(summaries.map(\.currentBalance), currency: currency)

        let currentMonth = CalendarMonth(date: today)
        let previousMonth = currentMonth.previous

        // Internal transfers are excluded from income/expense — they are
        // the user's own money moving between their own accounts, not new
        // income or spending (see the database specification).
        let currentMonthTransactions = transactions.filter { currentMonth.contains($0.date) }
        let previousMonthTransactions = transactions.filter { previousMonth.contains($0.date) }

        let monthlyIncome = try Money.sum(
            currentMonthTransactions.filter { $0.kind == .income }.map(\.amount),
            currency: currency
        )
        let monthlyExpense = try Money.sum(
            currentMonthTransactions.filter { $0.kind == .expense }.map(\.amount),
            currency: currency
        )

        let previousMonthExpenseAmounts = previousMonthTransactions.filter { $0.kind == .expense }.map(\.amount)
        let previousMonthExpense = previousMonthExpenseAmounts.isEmpty
            ? nil
            : try Money.sum(previousMonthExpenseAmounts, currency: currency)

        let recentTransactions = Array(
            transactions.sorted { lhs, rhs in
                lhs.date != rhs.date ? lhs.date > rhs.date : lhs.createdAt > rhs.createdAt
            }.prefix(8)
        )

        return DashboardSnapshot(
            totalBalance: totalBalance,
            accountSummaries: summaries,
            monthlyIncome: monthlyIncome,
            monthlyExpense: monthlyExpense,
            previousMonthExpense: previousMonthExpense,
            recentTransactions: recentTransactions
        )
    }
}
