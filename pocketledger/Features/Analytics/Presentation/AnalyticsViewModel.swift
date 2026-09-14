import Foundation

enum AnalyticsPhase: Equatable {
    case loading
    case loaded
    case failed(String)
}

@MainActor
@Observable
final class AnalyticsViewModel {
    private(set) var snapshot: AnalyticsSnapshot?
    private(set) var phase: AnalyticsPhase = .loading
    private(set) var refreshNotice: String?

    private let transactionRepository: TransactionRepository
    private let walletProfileRepository: WalletProfileRepository
    private var hasLoadedOnce = false

    init(transactionRepository: TransactionRepository, walletProfileRepository: WalletProfileRepository) {
        self.transactionRepository = transactionRepository
        self.walletProfileRepository = walletProfileRepository
    }

    func loadIfNeeded() async {
        guard !hasLoadedOnce else { return }
        await load()
    }

    func load() async {
        phase = .loading

        if let transactions = try? await transactionRepository.cachedTransactions(),
           let profile = (try? await walletProfileRepository.cachedProfile()) ?? nil,
           let cached = try? AnalyticsCalculator.calculate(transactions: transactions, currency: profile.baseCurrency) {
            snapshot = cached
            phase = .loaded
        }

        await refresh()
        hasLoadedOnce = true
    }

    func refresh() async {
        do {
            let transactions = try await transactionRepository.refreshTransactions()
            guard let profile = try await walletProfileRepository.refreshProfile() else {
                throw RepositoryError.walletProfileMissing
            }
            snapshot = try AnalyticsCalculator.calculate(transactions: transactions, currency: profile.baseCurrency)
            phase = .loaded
            refreshNotice = nil
        } catch {
            if phase == .loaded {
                refreshNotice = PresentationErrorMapper.message(for: error)
            } else {
                phase = .failed(PresentationErrorMapper.message(for: error))
            }
        }
    }
}
