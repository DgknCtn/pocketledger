import Foundation
import Testing
@testable import pocketledger

@MainActor
struct TransactionListViewModelTests {
    private let currency = CurrencyCode(rawValue: "TRY")!
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func transaction(
        title: String = "Test",
        kind: TransactionKind = .expense,
        category: TransactionCategory? = .food,
        source: UUID = UUID()
    ) -> Transaction {
        Transaction(
            id: UUID(), kind: kind, sourceAccountID: source, destinationAccountID: nil,
            amount: Money(minorUnits: 1_000, currency: currency), category: category,
            title: title, note: nil, date: try! LocalDate(parsing: "2026-09-14"),
            createdAt: now, updatedAt: now
        )
    }

    private func makeViewModel(
        transactionRepository: FakeTransactionRepository = FakeTransactionRepository(),
        accountRepository: FakeAccountRepository = FakeAccountRepository(),
        walletProfileRepository: FakeWalletProfileRepository = FakeWalletProfileRepository()
    ) -> TransactionListViewModel {
        TransactionListViewModel(
            transactionRepository: transactionRepository,
            accountRepository: accountRepository,
            walletProfileRepository: walletProfileRepository,
            createTransactionUseCase: CreateTransactionUseCase(transactionRepository: transactionRepository),
            updateTransactionUseCase: UpdateTransactionUseCase(transactionRepository: transactionRepository)
        )
    }

    @Test func loadPopulatesTransactionsFromRefresh() async {
        let repository = FakeTransactionRepository()
        repository.refreshResult = [transaction()]
        let viewModel = makeViewModel(transactionRepository: repository)

        await viewModel.load()

        #expect(viewModel.phase == .loaded)
        #expect(viewModel.filteredTransactions.count == 1)
    }

    @Test func searchTextFiltersByTitleCaseInsensitively() async {
        let repository = FakeTransactionRepository()
        repository.refreshResult = [transaction(title: "Coffee Shop"), transaction(title: "Groceries")]
        let viewModel = makeViewModel(transactionRepository: repository)
        await viewModel.load()

        viewModel.searchText = "coffee"

        #expect(viewModel.filteredTransactions.map(\.title) == ["Coffee Shop"])
    }

    @Test func categoryFilterOnlyShowsMatchingTransactions() async {
        let repository = FakeTransactionRepository()
        repository.refreshResult = [
            transaction(title: "Lunch", category: .food),
            transaction(title: "Taxi", category: .transport),
        ]
        let viewModel = makeViewModel(transactionRepository: repository)
        await viewModel.load()

        viewModel.categoryFilter = .transport

        #expect(viewModel.filteredTransactions.map(\.title) == ["Taxi"])
        #expect(viewModel.hasActiveFilters)
    }

    @Test func kindFilterOnlyShowsMatchingTransactions() async {
        let repository = FakeTransactionRepository()
        repository.refreshResult = [
            transaction(title: "Salary", kind: .income, category: nil),
            transaction(title: "Lunch", kind: .expense, category: .food),
        ]
        let viewModel = makeViewModel(transactionRepository: repository)
        await viewModel.load()

        viewModel.kindFilter = .income

        #expect(viewModel.filteredTransactions.map(\.title) == ["Salary"])
    }

    @Test func clearFiltersResetsBothFilters() async {
        let viewModel = makeViewModel()
        viewModel.categoryFilter = .food
        viewModel.kindFilter = .expense

        viewModel.clearFilters()

        #expect(viewModel.categoryFilter == nil)
        #expect(viewModel.kindFilter == nil)
        #expect(!viewModel.hasActiveFilters)
    }

    @Test func refreshFailureWithExistingContentSetsANonBlockingNotice() async {
        let repository = FakeTransactionRepository()
        repository.refreshResult = [transaction()]
        let viewModel = makeViewModel(transactionRepository: repository)
        await viewModel.load()

        repository.refreshError = RepositoryError.offline
        await viewModel.refresh()

        #expect(viewModel.phase == .loaded)
        #expect(viewModel.refreshNotice != nil)
    }

    @Test func accountNameFallsBackToAPlaceholderWhenUnknown() {
        let viewModel = makeViewModel()

        #expect(viewModel.accountName(for: UUID()) == "Unknown Account")
    }
}
