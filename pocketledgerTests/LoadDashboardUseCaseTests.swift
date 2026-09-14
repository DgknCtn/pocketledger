import Foundation
import Testing
@testable import pocketledger

struct LoadDashboardUseCaseTests {
    private let currency = CurrencyCode(rawValue: "TRY")!
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let fixedToday = try! LocalDate(parsing: "2026-09-14")

    private func account(id: UUID = UUID(), openingMinor: Int64 = 0, isArchived: Bool = false) -> Account {
        Account(
            id: id, name: "Test", kind: .bank,
            openingBalance: Money(minorUnits: openingMinor, currency: currency),
            isArchived: isArchived, archivedAt: isArchived ? now : nil, createdAt: now, updatedAt: now
        )
    }

    private func transaction(
        kind: TransactionKind,
        source: UUID,
        destination: UUID? = nil,
        amountMinor: Int64,
        category: TransactionCategory? = nil,
        date: String
    ) -> Transaction {
        Transaction(
            id: UUID(), kind: kind, sourceAccountID: source, destinationAccountID: destination,
            amount: Money(minorUnits: amountMinor, currency: currency), category: category,
            title: "T", note: nil, date: try! LocalDate(parsing: date), createdAt: now, updatedAt: now
        )
    }

    private func makeUseCase(
        accountRepository: FakeAccountRepository,
        transactionRepository: FakeTransactionRepository,
        walletProfileRepository: FakeWalletProfileRepository
    ) -> LoadDashboardUseCase {
        LoadDashboardUseCase(
            accountRepository: accountRepository,
            transactionRepository: transactionRepository,
            walletProfileRepository: walletProfileRepository,
            today: { [fixedToday] in fixedToday }
        )
    }

    @Test func totalBalanceSumsOnlyActiveAccounts() async throws {
        let active = account(openingMinor: 100_000)
        let archived = account(openingMinor: 999_000, isArchived: true)
        let accountRepository = FakeAccountRepository()
        accountRepository.refreshResult = [active, archived]
        let transactionRepository = FakeTransactionRepository()
        let walletProfileRepository = FakeWalletProfileRepository()
        walletProfileRepository.refreshed = WalletProfile(baseCurrency: currency)

        let snapshot = try await makeUseCase(
            accountRepository: accountRepository,
            transactionRepository: transactionRepository,
            walletProfileRepository: walletProfileRepository
        ).refresh()

        #expect(snapshot.totalBalance.minorUnits == 100_000)
        #expect(snapshot.accountSummaries.count == 1)
    }

    @Test func monthlyIncomeAndExpenseExcludeTransfersAndOtherMonths() async throws {
        let accountID = UUID()
        let otherAccountID = UUID()
        let accountRepository = FakeAccountRepository()
        accountRepository.refreshResult = [account(id: accountID)]

        let transactionRepository = FakeTransactionRepository()
        transactionRepository.refreshResult = [
            transaction(kind: .income, source: accountID, amountMinor: 500_000, date: "2026-09-01"),
            transaction(kind: .expense, source: accountID, amountMinor: 100_000, category: .food, date: "2026-09-10"),
            transaction(kind: .transfer, source: accountID, destination: otherAccountID, amountMinor: 999_000, date: "2026-09-05"),
            transaction(kind: .expense, source: accountID, amountMinor: 999_000, category: .food, date: "2026-08-10"),
        ]

        let walletProfileRepository = FakeWalletProfileRepository()
        walletProfileRepository.refreshed = WalletProfile(baseCurrency: currency)

        let snapshot = try await makeUseCase(
            accountRepository: accountRepository,
            transactionRepository: transactionRepository,
            walletProfileRepository: walletProfileRepository
        ).refresh()

        #expect(snapshot.monthlyIncome.minorUnits == 500_000)
        #expect(snapshot.monthlyExpense.minorUnits == 100_000)
    }

    @Test func previousMonthExpenseIsNilWhenThereIsNoPriorData() async throws {
        let accountID = UUID()
        let accountRepository = FakeAccountRepository()
        accountRepository.refreshResult = [account(id: accountID)]
        let transactionRepository = FakeTransactionRepository()
        transactionRepository.refreshResult = [
            transaction(kind: .expense, source: accountID, amountMinor: 100_000, category: .food, date: "2026-09-10"),
        ]
        let walletProfileRepository = FakeWalletProfileRepository()
        walletProfileRepository.refreshed = WalletProfile(baseCurrency: currency)

        let snapshot = try await makeUseCase(
            accountRepository: accountRepository,
            transactionRepository: transactionRepository,
            walletProfileRepository: walletProfileRepository
        ).refresh()

        #expect(snapshot.previousMonthExpense == nil)
    }

    @Test func previousMonthExpenseIsPopulatedWhenDataExists() async throws {
        let accountID = UUID()
        let accountRepository = FakeAccountRepository()
        accountRepository.refreshResult = [account(id: accountID)]
        let transactionRepository = FakeTransactionRepository()
        transactionRepository.refreshResult = [
            transaction(kind: .expense, source: accountID, amountMinor: 100_000, category: .food, date: "2026-08-10"),
        ]
        let walletProfileRepository = FakeWalletProfileRepository()
        walletProfileRepository.refreshed = WalletProfile(baseCurrency: currency)

        let snapshot = try await makeUseCase(
            accountRepository: accountRepository,
            transactionRepository: transactionRepository,
            walletProfileRepository: walletProfileRepository
        ).refresh()

        #expect(snapshot.previousMonthExpense?.minorUnits == 100_000)
    }

    @Test func recentTransactionsAreSortedNewestFirstAndCappedAtEight() async throws {
        let accountID = UUID()
        let accountRepository = FakeAccountRepository()
        accountRepository.refreshResult = [account(id: accountID)]
        let transactionRepository = FakeTransactionRepository()
        let dates = ["2026-09-01", "2026-09-02", "2026-09-03", "2026-09-04", "2026-09-05", "2026-09-06", "2026-09-07", "2026-09-08", "2026-09-09"]
        transactionRepository.refreshResult = dates.map {
            transaction(kind: .expense, source: accountID, amountMinor: 1_000, category: .food, date: $0)
        }
        let walletProfileRepository = FakeWalletProfileRepository()
        walletProfileRepository.refreshed = WalletProfile(baseCurrency: currency)

        let snapshot = try await makeUseCase(
            accountRepository: accountRepository,
            transactionRepository: transactionRepository,
            walletProfileRepository: walletProfileRepository
        ).refresh()

        #expect(snapshot.recentTransactions.count == 8)
        #expect(snapshot.recentTransactions.first?.date.isoString == "2026-09-09")
    }

    @Test func missingWalletProfileThrows() async {
        let accountRepository = FakeAccountRepository()
        let transactionRepository = FakeTransactionRepository()
        let walletProfileRepository = FakeWalletProfileRepository()

        await #expect(throws: RepositoryError.walletProfileMissing) {
            try await makeUseCase(
                accountRepository: accountRepository,
                transactionRepository: transactionRepository,
                walletProfileRepository: walletProfileRepository
            ).refresh()
        }
    }
}
