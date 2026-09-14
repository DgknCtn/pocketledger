import Foundation
import Testing
@testable import pocketledger

@MainActor
struct DashboardViewModelTests {
    private let currency = CurrencyCode(rawValue: "TRY")!
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func account() -> Account {
        Account(
            id: UUID(), name: "Main", kind: .bank,
            openingBalance: Money(minorUnits: 10_000, currency: currency),
            isArchived: false, archivedAt: nil, createdAt: now, updatedAt: now
        )
    }

    private func makeViewModel(
        accountRepository: FakeAccountRepository = FakeAccountRepository(),
        transactionRepository: FakeTransactionRepository = FakeTransactionRepository(),
        walletProfileRepository: FakeWalletProfileRepository = FakeWalletProfileRepository()
    ) -> DashboardViewModel {
        if walletProfileRepository.refreshed == nil {
            walletProfileRepository.refreshed = WalletProfile(baseCurrency: currency)
        }
        return DashboardViewModel(
            loadDashboardUseCase: LoadDashboardUseCase(
                accountRepository: accountRepository,
                transactionRepository: transactionRepository,
                walletProfileRepository: walletProfileRepository
            )
        )
    }

    @Test func loadWithSuccessfulRefreshEndsUpLoadedWithASnapshot() async {
        let accountRepository = FakeAccountRepository()
        accountRepository.refreshResult = [account()]
        let viewModel = makeViewModel(accountRepository: accountRepository)

        await viewModel.load()

        #expect(viewModel.phase == .loaded)
        #expect(viewModel.snapshot != nil)
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

    @Test func refreshFailureWithExistingSnapshotPreservesItAndSetsANotice() async {
        let accountRepository = FakeAccountRepository()
        accountRepository.refreshResult = [account()]
        let viewModel = makeViewModel(accountRepository: accountRepository)
        await viewModel.load()
        #expect(viewModel.phase == .loaded)

        accountRepository.refreshError = RepositoryError.offline
        await viewModel.refresh()

        #expect(viewModel.phase == .loaded)
        #expect(viewModel.snapshot != nil)
        #expect(viewModel.refreshNotice != nil)
    }

    @Test func loadIfNeededOnlyLoadsOnce() async {
        let accountRepository = FakeAccountRepository()
        accountRepository.refreshResult = [account()]
        let viewModel = makeViewModel(accountRepository: accountRepository)

        await viewModel.loadIfNeeded()
        accountRepository.refreshResult = []
        await viewModel.loadIfNeeded()

        #expect(viewModel.snapshot?.accountSummaries.count == 1)
    }
}
