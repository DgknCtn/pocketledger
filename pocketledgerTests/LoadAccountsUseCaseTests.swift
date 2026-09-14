import Foundation
import Testing
@testable import pocketledger

struct LoadAccountsUseCaseTests {
    private let currency = CurrencyCode(rawValue: "TRY")!
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func account(openingMinor: Int64) -> Account {
        Account(
            id: UUID(), name: "Test", kind: .bank,
            openingBalance: Money(minorUnits: openingMinor, currency: currency),
            isArchived: false, archivedAt: nil, createdAt: now, updatedAt: now
        )
    }

    @Test func refreshPairsEachAccountWithItsDerivedBalance() async throws {
        let account = account(openingMinor: 10_000)
        let accountRepository = FakeAccountRepository()
        accountRepository.refreshResult = [account]

        let transactionRepository = FakeTransactionRepository()
        transactionRepository.refreshResult = [
            Transaction(
                id: UUID(), kind: .income, sourceAccountID: account.id, destinationAccountID: nil,
                amount: Money(minorUnits: 5_000, currency: currency), category: nil,
                title: "Bonus", note: nil, date: try LocalDate(parsing: "2026-09-14"),
                createdAt: now, updatedAt: now
            ),
        ]

        let useCase = LoadAccountsUseCase(accountRepository: accountRepository, transactionRepository: transactionRepository)
        let summaries = try await useCase.refresh()

        #expect(summaries.count == 1)
        #expect(summaries.first?.currentBalance.minorUnits == 15_000)
    }

    @Test func loadCachedUsesCachedDataFromBothRepositories() async throws {
        let account = account(openingMinor: 20_000)
        let accountRepository = FakeAccountRepository()
        accountRepository.cachedResult = [account]
        let transactionRepository = FakeTransactionRepository()
        transactionRepository.cachedResult = []

        let useCase = LoadAccountsUseCase(accountRepository: accountRepository, transactionRepository: transactionRepository)
        let summaries = try await useCase.loadCached()

        #expect(summaries.first?.currentBalance.minorUnits == 20_000)
    }

    @Test func refreshPropagatesRepositoryFailure() async {
        let accountRepository = FakeAccountRepository()
        accountRepository.refreshError = RepositoryError.offline
        let transactionRepository = FakeTransactionRepository()

        let useCase = LoadAccountsUseCase(accountRepository: accountRepository, transactionRepository: transactionRepository)

        await #expect(throws: RepositoryError.offline) {
            try await useCase.refresh()
        }
    }
}
