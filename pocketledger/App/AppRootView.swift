import SwiftUI
import os

/// Composition root for the visible app. Face ID app-lock gates the one
/// real feature that exists so far (Accounts) — Dashboard/Transactions/
/// Analytics/Profile and the full `TabView` shell land in later phases.
///
/// `accountListViewModel` is built once in `init` (not computed in `body`,
/// which SwiftUI re-evaluates on every state change including scenePhase
/// and lock transitions) — rebuilding it per render would silently reset
/// its loaded data and re-fetch on every re-render.
struct AppRootView: View {
    @State private var appContainer: AppContainer
    @State private var accountListViewModel: AccountListViewModel
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
    }

    var body: some View {
        ZStack {
            if appContainer.appLockController.isLocked {
                LockView(appLockController: appContainer.appLockController)
            } else {
                AccountListView(viewModel: accountListViewModel)
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
