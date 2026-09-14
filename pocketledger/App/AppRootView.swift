import SwiftUI
import os

/// Composition root for the visible app.
///
/// This is intentionally minimal in Phase 0/1: there is no networking, no
/// persistence and no Face ID lock yet, so it only proves that the project
/// structure, environment and logging foundation build and launch. App-lock
/// state (`AppPhase`), `AppContainer` dependency wiring and the real
/// `TabView` shell are added once Networking/Auth/SwiftData (later phases)
/// exist to back them.
struct AppRootView: View {
    private let environment = AppEnvironment.resolve()

    var body: some View {
        VStack(spacing: 8) {
            Text("PocketLedger")
                .font(.largeTitle.bold())
            Text("Foundation phase — \(String(describing: environment))")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .onAppear {
            AppLogger.general.info("App launched in \(String(describing: environment), privacy: .public) environment")
        }
    }
}

#Preview {
    AppRootView()
}
