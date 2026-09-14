import SwiftUI
import os

/// Composition root for the visible app.
///
/// The tab set here is an honest interim shape — Accounts and
/// Transactions are the only features that exist so far. It becomes the
/// PRD's real primary navigation (Dashboard/Transactions/Analytics/
/// Profile) once those land in later phases; Account management moves
/// under Dashboard at that point rather than staying a top-level tab.
///
/// `accountListViewModel`/`transactionListViewModel` are built once in
/// `init` (not computed in `body`, which SwiftUI re-evaluates on every
/// state change including scenePhase and lock transitions) — rebuilding
/// them per render would silently reset loaded data and re-fetch
/// constantly.
struct AppRootView: View {
    private enum Tab: String, Hashable {
        case dashboard, accounts, transactions, analytics
    }

    @State private var appContainer: AppContainer
    @State private var dashboardViewModel: DashboardViewModel
    @State private var accountListViewModel: AccountListViewModel
    @State private var transactionListViewModel: TransactionListViewModel
    @State private var analyticsViewModel: AnalyticsViewModel
    @State private var selectedTab: Tab = .dashboard
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let container = AppContainer()
        _appContainer = State(initialValue: container)
        #if DEBUG
        if container.environment == .uiTesting {
            container.appLockController.bypassForUITesting()
        }
        // -selectedTab <name> lets UI tests (and manual verification) deep
        // link straight to a tab instead of needing a real tap; DEBUG-only,
        // same as the auth bypass above.
        if let requested = Self.tab(fromLaunchArguments: ProcessInfo.processInfo.arguments) {
            _selectedTab = State(initialValue: requested)
        }
        #endif

        _accountListViewModel = State(
            initialValue: AccountListViewModel(
                loadAccountsUseCase: LoadAccountsUseCase(
                    accountRepository: container.accountRepository,
                    transactionRepository: container.transactionRepository
                ),
                createAccountUseCase: CreateAccountUseCase(accountRepository: container.accountRepository),
                updateAccountUseCase: UpdateAccountUseCase(accountRepository: container.accountRepository),
                accountRepository: container.accountRepository,
                walletProfileRepository: container.walletProfileRepository
            )
        )

        _transactionListViewModel = State(
            initialValue: TransactionListViewModel(
                transactionRepository: container.transactionRepository,
                accountRepository: container.accountRepository,
                walletProfileRepository: container.walletProfileRepository,
                createTransactionUseCase: CreateTransactionUseCase(transactionRepository: container.transactionRepository),
                updateTransactionUseCase: UpdateTransactionUseCase(transactionRepository: container.transactionRepository)
            )
        )

        _dashboardViewModel = State(
            initialValue: DashboardViewModel(
                loadDashboardUseCase: LoadDashboardUseCase(
                    accountRepository: container.accountRepository,
                    transactionRepository: container.transactionRepository,
                    walletProfileRepository: container.walletProfileRepository
                )
            )
        )

        _analyticsViewModel = State(
            initialValue: AnalyticsViewModel(
                transactionRepository: container.transactionRepository,
                walletProfileRepository: container.walletProfileRepository
            )
        )
    }

    #if DEBUG
    private static func tab(fromLaunchArguments arguments: [String]) -> Tab? {
        guard let flagIndex = arguments.firstIndex(of: "-selectedTab"), flagIndex + 1 < arguments.count else {
            return nil
        }
        return Tab(rawValue: arguments[flagIndex + 1])
    }
    #endif

    var body: some View {
        ZStack {
            if appContainer.appLockController.isLocked {
                LockView(appLockController: appContainer.appLockController)
            } else {
                TabView(selection: $selectedTab) {
                    DashboardView(
                        viewModel: dashboardViewModel,
                        transactionListViewModel: transactionListViewModel,
                        accountListViewModel: accountListViewModel
                    )
                    .tabItem { Label("Dashboard", systemImage: "house") }
                    .tag(Tab.dashboard)

                    AccountListView(viewModel: accountListViewModel)
                        .tabItem { Label("Accounts", systemImage: "creditcard") }
                        .tag(Tab.accounts)

                    TransactionListView(viewModel: transactionListViewModel)
                        .tabItem { Label("Transactions", systemImage: "list.bullet.rectangle") }
                        .tag(Tab.transactions)

                    AnalyticsView(viewModel: analyticsViewModel)
                        .tabItem { Label("Analytics", systemImage: "chart.pie") }
                        .tag(Tab.analytics)
                }
            }

            if scenePhase != .active && !appContainer.appLockController.isLocked {
                PrivacyShieldView()
            }
        }
        .animation(.default, value: appContainer.appLockController.isLocked)
        .onChange(of: scenePhase) { _, newPhase in
            appContainer.appLockController.handleScenePhaseChange(newPhase)
        }
        .onAppear {
            AppLogger.general.info(
                "App launched in \(String(describing: appContainer.environment), privacy: .public) environment"
            )
        }
    }
}

#Preview {
    AppRootView()
}
