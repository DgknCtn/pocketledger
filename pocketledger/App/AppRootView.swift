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
    @State private var appContainer: AppContainer
    @State private var dashboardViewModel: DashboardViewModel
    @State private var accountListViewModel: AccountListViewModel
    @State private var transactionListViewModel: TransactionListViewModel
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let container = AppContainer()
        _appContainer = State(initialValue: container)
        #if DEBUG
        if container.environment == .uiTesting {
            container.appLockController.bypassForUITesting()
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
    }

    var body: some View {
        ZStack {
            if appContainer.appLockController.isLocked {
                LockView(appLockController: appContainer.appLockController)
            } else {
                TabView {
                    DashboardView(
                        viewModel: dashboardViewModel,
                        transactionListViewModel: transactionListViewModel,
                        accountListViewModel: accountListViewModel
                    )
                    .tabItem { Label("Dashboard", systemImage: "house") }

                    AccountListView(viewModel: accountListViewModel)
                        .tabItem { Label("Accounts", systemImage: "creditcard") }

                    TransactionListView(viewModel: transactionListViewModel)
                        .tabItem { Label("Transactions", systemImage: "list.bullet.rectangle") }
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
