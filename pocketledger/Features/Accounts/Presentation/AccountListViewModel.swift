import Foundation

enum AccountListPhase: Equatable {
    case loading
    case loaded
    case failed(String)
}

@MainActor
@Observable
final class AccountListViewModel {
    private(set) var summaries: [AccountSummary] = []
    private(set) var phase: AccountListPhase = .loading
    /// A non-blocking notice shown alongside still-valid cached content —
    /// distinct from `.failed`, which replaces the whole screen. Keeping
    /// this as its own optional (rather than more booleans on `phase`)
    /// avoids the "cached content + failed refresh" state being
    /// inexpressible or contradictory (see the Architecture specification's
    /// "Presentation State").
    private(set) var refreshNotice: String?

    let accountRepository: AccountRepository
    let walletProfileRepository: WalletProfileRepository
    private let loadAccountsUseCase: LoadAccountsUseCase
    private let createAccountUseCase: CreateAccountUseCase
    private let updateAccountUseCase: UpdateAccountUseCase

    private(set) var currency: CurrencyCode?
    private var hasLoadedOnce = false

    init(
        loadAccountsUseCase: LoadAccountsUseCase,
        createAccountUseCase: CreateAccountUseCase,
        updateAccountUseCase: UpdateAccountUseCase,
        accountRepository: AccountRepository,
        walletProfileRepository: WalletProfileRepository
    ) {
        self.loadAccountsUseCase = loadAccountsUseCase
        self.createAccountUseCase = createAccountUseCase
        self.updateAccountUseCase = updateAccountUseCase
        self.accountRepository = accountRepository
        self.walletProfileRepository = walletProfileRepository
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

        if let cached = try? await loadAccountsUseCase.loadCached(), !cached.isEmpty {
            summaries = cached
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
            summaries = try await loadAccountsUseCase.refresh()
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

    func archive(_ account: Account) async -> String? {
        do {
            _ = try await accountRepository.archiveAccount(id: account.id)
            await refresh()
            return nil
        } catch {
            return PresentationErrorMapper.message(for: error)
        }
    }

    func delete(_ account: Account) async -> String? {
        do {
            try await accountRepository.deleteAccount(id: account.id)
            await refresh()
            return nil
        } catch {
            return PresentationErrorMapper.message(for: error)
        }
    }

    func makeCreateFormViewModel() -> AccountFormViewModel {
        AccountFormViewModel(
            mode: .create,
            currency: currency ?? CurrencyCode(rawValue: "TRY")!,
            createAccountUseCase: createAccountUseCase,
            updateAccountUseCase: updateAccountUseCase
        )
    }

    func makeEditFormViewModel(for account: Account) -> AccountFormViewModel {
        AccountFormViewModel(
            mode: .edit(account),
            currency: currency ?? account.openingBalance.currency,
            createAccountUseCase: createAccountUseCase,
            updateAccountUseCase: updateAccountUseCase
        )
    }
}
