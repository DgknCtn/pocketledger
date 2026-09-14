import SwiftUI

/// Shown whenever `AppLockController.isLocked` is true. No financial
/// content is ever a sibling of this view while locked — see
/// `AppRootView`.
struct LockView: View {
    var appLockController: AppLockController

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text("PocketLedger")
                .font(.title2.bold())

            content
        }
        .padding()
        .task {
            if case .locked = appLockController.phase {
                await appLockController.authenticate()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch appLockController.phase {
        case .locked:
            EmptyView()

        case .authenticating:
            ProgressView()
                .accessibilityLabel("Authenticating")

        case .unlocked:
            EmptyView()

        case .failed(let error):
            VStack(spacing: 12) {
                Text(message(for: error))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button("Try Again") {
                    Task { await appLockController.retryAuthentication() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func message(for error: LocalAuthenticationError) -> String {
        switch error {
        case .unavailable:
            "Face ID or a device passcode isn't set up. Enable a passcode in Settings to use PocketLedger."
        case .userCancelled:
            "Authentication was cancelled."
        case .lockedOut:
            "Too many failed attempts. Unlock your device with your passcode, then try again."
        case .failed:
            "We couldn't verify it's you. Please try again."
        }
    }
}

#Preview("Locked") {
    LockView(appLockController: AppLockController(localAuthenticationService: DefaultLocalAuthenticationService()))
}
