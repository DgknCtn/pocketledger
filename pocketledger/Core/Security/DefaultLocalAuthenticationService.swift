import LocalAuthentication

/// `.deviceOwnerAuthentication` rather than
/// `.deviceOwnerAuthenticationWithBiometrics`: PocketLedger's product
/// requirement is that Face ID unavailable/failed falls back to the
/// device passcode, not that biometrics are mandatory.
struct DefaultLocalAuthenticationService: LocalAuthenticationService {
    func canAuthenticate() -> Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    func authenticate(reason: String) async throws {
        let context = LAContext()

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else {
            throw LocalAuthenticationError.unavailable
        }

        do {
            let success = try await evaluatePolicy(context: context, reason: reason)
            guard success else { throw LocalAuthenticationError.failed }
        } catch let error as LAError {
            throw Self.map(error)
        }
    }

    /// Wraps the completion-handler `evaluatePolicy` explicitly rather than
    /// assuming an async overload exists on every supported SDK.
    private func evaluatePolicy(context: LAContext, reason: String) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: success)
                }
            }
        }
    }

    private static func map(_ error: LAError) -> LocalAuthenticationError {
        switch error.code {
        case .userCancel, .appCancel, .systemCancel:
            return .userCancelled
        case .biometryLockout:
            return .lockedOut
        default:
            return .failed
        }
    }
}
