import Foundation
import Testing
@testable import pocketledger

@MainActor
struct AnalyticsViewModelTests {
    private let currency = CurrencyCode(rawValue: "TRY")!

    private func makeViewModel(
        transactionRepository: FakeTransactionRepository = FakeTransactionRepository(),
        walletProfileRepository: FakeWalletProfileRepository = FakeWalletProfileRepository()
    ) -> AnalyticsViewModel {
        if walletProfileRepository.refreshed == nil {
            walletProfileRepository.refreshed = WalletProfile(baseCurrency: currency)
        }
        return AnalyticsViewModel(
            transactionRepository: transactionRepository,
            walletProfileRepository: walletProfileRepository
        )
    }

    @Test func loadWithSuccessfulRefreshEndsUpLoaded() async {
        let viewModel = makeViewModel()

        await viewModel.load()

        #expect(viewModel.phase == .loaded)
        #expect(viewModel.snapshot != nil)
    }

    @Test func loadWithNoCacheAndFailingRefreshEndsUpFailed() async {
        let transactionRepository = FakeTransactionRepository()
        transactionRepository.refreshError = RepositoryError.serviceUnavailable
        let viewModel = makeViewModel(transactionRepository: transactionRepository)

        await viewModel.load()

        guard case .failed = viewModel.phase else {
            Issue.record("Expected .failed, got \(viewModel.phase)")
            return
        }
    }

    @Test func refreshFailureWithExistingSnapshotSetsANonBlockingNotice() async {
        let transactionRepository = FakeTransactionRepository()
        let viewModel = makeViewModel(transactionRepository: transactionRepository)
        await viewModel.load()
        #expect(viewModel.phase == .loaded)

        transactionRepository.refreshError = RepositoryError.offline
        await viewModel.refresh()

        #expect(viewModel.phase == .loaded)
        #expect(viewModel.refreshNotice != nil)
    }

    @Test func missingWalletProfileFailsRatherThanCrashing() async {
        // Deliberately bypasses makeViewModel's auto-seeded wallet profile.
        let viewModel = AnalyticsViewModel(
            transactionRepository: FakeTransactionRepository(),
            walletProfileRepository: FakeWalletProfileRepository()
        )

        await viewModel.load()

        guard case .failed = viewModel.phase else {
            Issue.record("Expected .failed, got \(viewModel.phase)")
            return
        }
    }
}
