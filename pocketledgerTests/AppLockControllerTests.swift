import Foundation
import os
import SwiftUI
import Testing
@testable import pocketledger

/// A settable "current time" so background-duration tests are deterministic
/// instead of depending on real wall-clock time.
private final class MutableClock: @unchecked Sendable {
    private let lock = OSAllocatedUnfairLock<Date>(initialState: Date(timeIntervalSince1970: 0))

    var now: Date {
        get { lock.withLock { $0 } }
        set { lock.withLock { $0 = newValue } }
    }
}

@MainActor
struct AppLockControllerTests {
    @Test func successfulAuthenticationUnlocks() async {
        let controller = AppLockController(localAuthenticationService: FakeLocalAuthenticationService())

        await controller.authenticate()

        #expect(controller.phase == .unlocked)
        #expect(controller.isLocked == false)
    }

    @Test func failedAuthenticationStaysLockedWithTheSpecificReason() async {
        let fake = FakeLocalAuthenticationService()
        fake.authenticateError = .failed
        let controller = AppLockController(localAuthenticationService: fake)

        await controller.authenticate()

        #expect(controller.phase == .failed(.failed))
        #expect(controller.isLocked)
    }

    @Test func cancelledAuthenticationStaysLocked() async {
        let fake = FakeLocalAuthenticationService()
        fake.authenticateError = .userCancelled
        let controller = AppLockController(localAuthenticationService: fake)

        await controller.authenticate()

        #expect(controller.phase == .failed(.userCancelled))
    }

    @Test func unavailableBiometricsFailsWithoutAttemptingAuthentication() async {
        let fake = FakeLocalAuthenticationService()
        fake.canAuthenticateResult = false
        let controller = AppLockController(localAuthenticationService: fake)

        await controller.authenticate()

        #expect(controller.phase == .failed(.unavailable))
    }

    @Test func retryAfterFailureCanSucceed() async {
        let fake = FakeLocalAuthenticationService()
        fake.authenticateError = .failed
        let controller = AppLockController(localAuthenticationService: fake)
        await controller.authenticate()
        #expect(controller.isLocked)

        fake.authenticateError = nil
        await controller.retryAuthentication()

        #expect(controller.phase == .unlocked)
    }

    @Test func failureDoesNotCrashAndRemainsRecoverable() async {
        let fake = FakeLocalAuthenticationService()
        fake.authenticateError = .lockedOut
        let controller = AppLockController(localAuthenticationService: fake)

        await controller.authenticate()
        #expect(controller.phase == .failed(.lockedOut))

        fake.authenticateError = nil
        await controller.retryAuthentication()
        #expect(controller.phase == .unlocked)
    }

    // MARK: - Background timeout

    @Test func shortBackgroundDurationDoesNotRelock() async {
        let clock = MutableClock()
        let controller = AppLockController(
            localAuthenticationService: FakeLocalAuthenticationService(),
            securityPolicy: SecurityPolicy(reauthenticationInterval: 30),
            now: { clock.now }
        )
        await controller.authenticate()
        #expect(controller.phase == .unlocked)

        controller.handleScenePhaseChange(.background)
        clock.now = clock.now.addingTimeInterval(5)
        controller.handleScenePhaseChange(.active)

        #expect(controller.phase == .unlocked)
    }

    @Test func backgroundDurationPastTheThresholdRelocks() async {
        let clock = MutableClock()
        let controller = AppLockController(
            localAuthenticationService: FakeLocalAuthenticationService(),
            securityPolicy: SecurityPolicy(reauthenticationInterval: 30),
            now: { clock.now }
        )
        await controller.authenticate()

        controller.handleScenePhaseChange(.background)
        clock.now = clock.now.addingTimeInterval(60)
        controller.handleScenePhaseChange(.active)

        #expect(controller.isLocked)
    }

    @Test func inactivePhaseAloneDoesNotRelock() async {
        let controller = AppLockController(localAuthenticationService: FakeLocalAuthenticationService())
        await controller.authenticate()

        controller.handleScenePhaseChange(.inactive)
        controller.handleScenePhaseChange(.active)

        #expect(controller.phase == .unlocked)
    }
}
