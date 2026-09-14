import SwiftUI
import os

/// Composition root for the visible app.
///
/// Face ID app-lock is wired up here; the real `TabView` shell, dashboard
/// content, networking and SwiftData-backed data still don't exist yet
/// (added once Accounts/Transactions features land) — `readyContent` is a
/// placeholder proving the lock flow gates *something*.
struct AppRootView: View {
    @State private var appLockController = AppLockController(
        localAuthenticationService: DefaultLocalAuthenticationService()
    )
    @Environment(\.scenePhase) private var scenePhase

    private let environment = AppEnvironment.resolve()

    var body: some View {
        ZStack {
            if appLockController.isLocked {
                LockView(appLockController: appLockController)
            } else {
                readyContent
            }

            if scenePhase != .active && !appLockController.isLocked {
                PrivacyShieldView()
            }
        }
        .animation(.default, value: appLockController.isLocked)
        .onChange(of: scenePhase) { _, newPhase in
            appLockController.handleScenePhaseChange(newPhase)
        }
        .onAppear {
            AppLogger.general.info("App launched in \(String(describing: environment), privacy: .public) environment")
        }
    }

    private var readyContent: some View {
        VStack(spacing: 8) {
            Text("PocketLedger")
                .font(.largeTitle.bold())
            Text("Foundation phase — \(String(describing: environment))")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    AppRootView()
}
