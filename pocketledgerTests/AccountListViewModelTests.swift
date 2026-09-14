import Foundation
import Testing
@testable import pocketledger

@MainActor
struct AccountListViewModelTests {
    private let currency = CurrencyCode(rawValue: "TRY")!
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func account(name: String = "Main") -> Account {
        Account(
            id: UUID(), name: name, kind: .bank,
            openingBalance: Money(minorUnits: 10_000, currency: currency),
            isArchived: false, archivedAt: nil, createdAt: now, updatedAt: now
        )
    }

    private func makeViewModel(
        accountRepository: FakeAccountRepository = FakeAccountRepository(),
        transactionRepository: FakeTransactionRepository = FakeTransactionRepository(),
        walletProfileRepository: FakeWalletProfileRepository = FakeWalletProfileRepository()
    ) -> AccountListViewModel {
        AccountListViewModel(
            loadAccountsUseCase: LoadAccountsUseCase(
                accountRepository: accountRepository, transactionRepository: transactionRepository
            ),
            createAccountUseCase: CreateAccountUseCase(accountRepository: accountRepository),
            updateAccountUseCase: UpdateAccountUseCase(accountRepository: accountRepository),
            accountRepository: accountRepository,
            walletProfileRepository: walletProfileRepository
        )
    }

    @Test func loadWithNoCacheAndSuccessfulRefreshEndsUpLoaded() async {
        let accountRepository = FakeAccountRepository()
        accountRepository.refreshResult = [account()]
        let viewModel = makeViewModel(accountRepository: accountRepository)

        await viewModel.load()

        #expect(viewModel.phase == .loaded)
        #expect(viewModel.summaries.count == 1)
    }

    @Test func loadWithNoCacheAndFailingRefreshEndsUpFailed() async {
        let accountRepository = FakeAccountRepository()
        accountRepository.refreshError = RepositoryError.serviceUnavailable
        let viewModel = makeViewModel(accountRepository: accountRepository)

        await viewModel.load()

        guard case .failed = viewModel.phase else {
            Issue.record("Expected .failed, got \(viewModel.phase)")
            return
        }
    }

    @Test func cachedContentIsShownImmediatelyBeforeRefreshCompletes() async {
        let cachedAccount = account(name: "Cached")
        let accountRepository = FakeAccountRepository()
        accountRepository.cachedResult = [cachedAccount]
        accountRepository.refreshResult = [cachedAccount]
        let viewModel = makeViewModel(accountRepository: accountRepository)

        await viewModel.load()

        #expect(viewModel.summaries.map(\.account.name) == ["Cached"])
    }

    @Test func refreshFailureWithExistingContentSetsANonBlockingNoticeInstead() async {
        let accountRepository = FakeAccountRepository()
        accountRepository.cachedResult = [account()]
        accountRepository.refreshResult = [account()]
        let viewModel = makeViewModel(accountRepository: accountRepository)
        await viewModel.load()
        #expect(viewModel.phase == .loaded)

        accountRepository.refreshError = RepositoryError.offline
        await viewModel.refresh()

        // Content-bearing phase is preserved; the failure becomes a notice.
        #expect(viewModel.phase == .loaded)
        #expect(viewModel.refreshNotice != nil)
    }

    @Test func successfulRefreshClearsAPreviousNotice() async {
        let accountRepository = FakeAccountRepository()
        accountRepository.cachedResult = [account()]
        accountRepository.refreshResult = [account()]
        let viewModel = makeViewModel(accountRepository: accountRepository)
        await viewModel.load()
        accountRepository.refreshError = RepositoryError.offline
        await viewModel.refresh()
        #expect(viewModel.refreshNotice != nil)

        accountRepository.refreshError = nil
        await viewModel.refresh()

        #expect(viewModel.refreshNotice == nil)
    }

    @Test func deleteFailureReturnsAUserFacingMessageAndDoesNotCrash() async {
        let accountRepository = FakeAccountRepository()
        let target = account()
        accountRepository.deleteError = RepositoryError.accountHasTransactions
        let viewModel = makeViewModel(accountRepository: accountRepository)

        let message = await viewModel.delete(target)

        #expect(message != nil)
    }

    @Test func loadIfNeededOnlyLoadsOnce() async {
        let accountRepository = FakeAccountRepository()
        accountRepository.refreshResult = [account()]
        let viewModel = makeViewModel(accountRepository: accountRepository)

        await viewModel.loadIfNeeded()
        accountRepository.refreshResult = [] // would change the result if loaded again
        await viewModel.loadIfNeeded()

        #expect(viewModel.summaries.count == 1)
    }
}
