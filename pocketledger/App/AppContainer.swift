import Foundation

/// The composition root: the one place the app's real object graph is
/// built and wired together with constructor injection. Nothing outside
/// this file reaches for a shared/global instance — `AppContainer` is not
/// a service locator (see the Architecture specification); it hands
/// finished dependencies to whoever needs them, once, at startup.
@MainActor
final class AppContainer {
    let environment: AppEnvironment
    let appLockController: AppLockController

    let walletProfileRepository: WalletProfileRepository
    let accountRepository: AccountRepository
    let transactionRepository: TransactionRepository

    init(environment: AppEnvironment = .resolve()) {
        self.environment = environment
        self.appLockController = AppLockController(localAuthenticationService: DefaultLocalAuthenticationService())

        switch environment {
        case .demo, .uiTesting:
            let store = SampleDataStore()
            self.walletProfileRepository = SampleWalletProfileRepository(store: store)
            self.accountRepository = SampleAccountRepository(store: store)
            self.transactionRepository = SampleTransactionRepository(store: store)

        case .development, .production:
            let configuration = try? AppConfiguration()
            let supabaseURL = configuration?.supabaseURL ?? URL(string: "https://example.supabase.co")!
            let publishableKey = configuration?.supabasePublishableKey ?? ""
            let requestBuilder = RequestBuilder(supabaseURL: supabaseURL, publishableKey: publishableKey)

            // The auth client must never require a token itself (it's what
            // *produces* one), so it gets no AuthorizationTokenProviding —
            // breaking what would otherwise be a circular dependency with
            // SessionManager.
            let authNetworkClient = URLSessionNetworkClient(requestBuilder: requestBuilder)
            let authRemoteDataSource = DefaultAuthRemoteDataSource(networkClient: authNetworkClient)
            let sessionManager = SessionManager(
                authRemoteDataSource: authRemoteDataSource,
                secureStore: KeychainSecureStore()
            )

            let dataNetworkClient = URLSessionNetworkClient(
                requestBuilder: requestBuilder,
                authorizationProvider: sessionManager
            )

            let persistenceActor = PersistenceActor(modelContainer: PersistenceContainer.makeProduction())
            let walletProfileLocalStore = DefaultWalletProfileLocalStore(persistenceActor: persistenceActor)
            let accountLocalStore = DefaultAccountLocalStore(persistenceActor: persistenceActor)
            let transactionLocalStore = DefaultTransactionLocalStore(persistenceActor: persistenceActor)

            self.walletProfileRepository = DefaultWalletProfileRepository(
                remoteDataSource: DefaultWalletProfileRemoteDataSource(networkClient: dataNetworkClient),
                localStore: walletProfileLocalStore,
                sessionManager: sessionManager
            )
            self.accountRepository = DefaultAccountRepository(
                remoteDataSource: DefaultAccountRemoteDataSource(networkClient: dataNetworkClient),
                localStore: accountLocalStore,
                walletProfileLocalStore: walletProfileLocalStore,
                sessionManager: sessionManager
            )
            self.transactionRepository = DefaultTransactionRepository(
                remoteDataSource: DefaultTransactionRemoteDataSource(networkClient: dataNetworkClient),
                localStore: transactionLocalStore,
                walletProfileLocalStore: walletProfileLocalStore,
                sessionManager: sessionManager
            )
        }
    }
}
