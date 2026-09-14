import Foundation

enum TransactionListPhase: Equatable {
    case loading
    case loaded
    case failed(String)
}

@MainActor
@Observable
final class TransactionListViewModel {
    private(set) var phase: TransactionListPhase = .loading
    private(set) var refreshNotice: String?
    private(set) var accounts: [Account] = []
    private var allTransactions: [Transaction] = []

    var searchText: String = ""
    var categoryFilter: TransactionCategory?
    var kindFilter: TransactionKind?

    let transactionRepository: TransactionRepository
    let accountRepository: AccountRepository
    private let walletProfileRepository: WalletProfileRepository
    private let createTransactionUseCase: CreateTransactionUseCase
    private let updateTransactionUseCase: UpdateTransactionUseCase

    private(set) var currency: CurrencyCode?
    private var hasLoadedOnce = false

    init(
        transactionRepository: TransactionRepository,
        accountRepository: AccountRepository,
        walletProfileRepository: WalletProfileRepository,
        createTransactionUseCase: CreateTransactionUseCase,
        updateTransactionUseCase: UpdateTransactionUseCase
    ) {
        self.transactionRepository = transactionRepository
        self.accountRepository = accountRepository
        self.walletProfileRepository = walletProfileRepository
        self.createTransactionUseCase = createTransactionUseCase
        self.updateTransactionUseCase = updateTransactionUseCase
    }

    var filteredTransactions: [Transaction] {
        allTransactions.filter { transaction in
            let matchesSearch = searchText.isEmpty
                || transaction.title.localizedCaseInsensitiveContains(searchText)
            let matchesCategory = categoryFilter == nil || transaction.category == categoryFilter
            let matchesKind = kindFilter == nil || transaction.kind == kindFilter
            return matchesSearch && matchesCategory && matchesKind
        }
    }

    var hasActiveFilters: Bool {
        categoryFilter != nil || kindFilter != nil
    }

    func loadIfNeeded() async {
        guard !hasLoadedOnce else { return }
        await load()
    }

    func load() async {
        phase = .loading

        if currency == nil {
            currency = try? await walletProfileRepository.cachedProfile()?.baseCurrency
        }
        if let cachedAccounts = try? await accountRepository.cachedAccounts() {
            accounts = cachedAccounts
        }
        if let cached = try? await transactionRepository.cachedTransactions(), !cached.isEmpty {
            allTransactions = cached
            phase = .loaded
        }

        await refresh()
        hasLoadedOnce = true
    }

    func refresh() async {
        if currency == nil {
            currency = try? await walletProfileRepository.refreshProfile()?.baseCurrency
        }

        do {
            allTransactions = try await transactionRepository.refreshTransactions()
            if let refreshedAccounts = try? await accountRepository.refreshAccounts() {
                accounts = refreshedAccounts
            }
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

    func delete(_ transaction: Transaction) async -> String? {
        do {
            try await transactionRepository.deleteTransaction(id: transaction.id)
            await refresh()
            return nil
        } catch {
            return PresentationErrorMapper.message(for: error)
        }
    }

    func accountName(for id: UUID) -> String {
        accounts.first(where: { $0.id == id })?.name ?? "Unknown Account"
    }

    func clearFilters() {
        categoryFilter = nil
        kindFilter = nil
    }

    func makeCreateFormViewModel() -> TransactionFormViewModel {
        TransactionFormViewModel(
            mode: .create,
            accounts: accounts,
            currency: currency ?? CurrencyCode(rawValue: "TRY")!,
            createUseCase: createTransactionUseCase,
            updateUseCase: updateTransactionUseCase
        )
    }

    func makeEditFormViewModel(for transaction: Transaction) -> TransactionFormViewModel {
        TransactionFormViewModel(
            mode: .edit(transaction),
            accounts: accounts,
            currency: currency ?? transaction.amount.currency,
            createUseCase: createTransactionUseCase,
            updateUseCase: updateTransactionUseCase
        )
    }
}
