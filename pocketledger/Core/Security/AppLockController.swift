import SwiftUI

/// The local app-lock state machine — entirely independent of
/// `SessionManager`/remote auth. `.failed` carries the specific reason so
/// the lock screen can show accurate copy instead of a generic error.
enum AppLockPhase: Sendable, Equatable {
    case locked
    case authenticating
    case unlocked
    case failed(LocalAuthenticationError)
}

/// Owns whether financial content may be shown. No financial data is
/// fetched or rendered while `isLocked` is true (see the Architecture
/// specification's "No Sensitive Financial UI Before Unlock").
@MainActor
@Observable
final class AppLockController {
    static let authenticationReason =
        "PocketLedger uses Face ID to protect access to your financial overview."

    private(set) var phase: AppLockPhase = .locked

    private let localAuthenticationService: LocalAuthenticationService
    private let securityPolicy: SecurityPolicy
    private let now: @Sendable () -> Date
    private var backgroundedAt: Date?

    init(
        localAuthenticationService: LocalAuthenticationService,
        securityPolicy: SecurityPolicy = SecurityPolicy(),
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.localAuthenticationService = localAuthenticationService
        self.securityPolicy = securityPolicy
        self.now = now
    }

    var isLocked: Bool {
        phase != .unlocked
    }

    func authenticate() async {
        guard localAuthenticationService.canAuthenticate() else {
            phase = .failed(.unavailable)
            return
        }

        phase = .authenticating

        do {
            try await localAuthenticationService.authenticate(reason: Self.authenticationReason)
            phase = .unlocked
        } catch let error as LocalAuthenticationError {
            phase = .failed(error)
        } catch {
            phase = .failed(.failed)
        }
    }

    func retryAuthentication() async {
        phase = .locked
        await authenticate()
    }

    #if DEBUG
    /// Skips real biometric/passcode authentication entirely. Only ever
    /// called for `AppEnvironment.uiTesting` (see `AppRootView`), and only
    /// exists in DEBUG builds — see the Architecture specification's "UI
    /// Test Environment" (this must never ship in a Release build).
    func bypassForUITesting() {
        phase = .unlocked
    }
    #endif

    /// Called from `AppRootView` on every `scenePhase` change. Background
    /// duration under `securityPolicy.reauthenticationInterval` leaves the
    /// unlocked state alone (the privacy shield still covers the content
    /// while backgrounded — see `PrivacyShieldView`); longer than that
    /// re-locks so returning to the app requires authentication again.
    func handleScenePhaseChange(_ scenePhase: ScenePhase) {
        switch scenePhase {
        case .active:
            if let backgroundedAt, now().timeIntervalSince(backgroundedAt) >= securityPolicy.reauthenticationInterval {
                phase = .locked
            }
            backgroundedAt = nil

        case .background:
            backgroundedAt = now()

        case .inactive:
            break

        @unknown default:
            break
        }
    }
}
