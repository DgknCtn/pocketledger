import Foundation
import os
@testable import pocketledger

final class FakeLocalAuthenticationService: LocalAuthenticationService, @unchecked Sendable {
    private let state = OSAllocatedUnfairLock<(canAuthenticate: Bool, error: LocalAuthenticationError?)>(
        initialState: (true, nil)
    )

    var canAuthenticateResult: Bool {
        get { state.withLock { $0.canAuthenticate } }
        set { state.withLock { $0.canAuthenticate = newValue } }
    }

    var authenticateError: LocalAuthenticationError? {
        get { state.withLock { $0.error } }
        set { state.withLock { $0.error = newValue } }
    }

    func canAuthenticate() -> Bool {
        state.withLock { $0.canAuthenticate }
    }

    func authenticate(reason: String) async throws {
        if let error = state.withLock({ $0.error }) {
            throw error
        }
    }
}
