import Foundation
@testable import pocketledger

/// An `actor` so concurrent-call tests (N simultaneous `validAccessToken()`
/// calls) can safely observe how many real network calls `SessionManager`
/// actually made.
actor FakeAuthRemoteDataSource: AuthRemoteDataSource {
    enum StubResult: Sendable {
        case success(AuthSessionDTO)
        case failure(any Error)
    }

    private(set) var signUpCallCount = 0
    private(set) var refreshCallCount = 0

    private var signUpResult: StubResult
    private var refreshResult: StubResult
    private var delay: Duration

    init(
        signUpResult: StubResult = .success(.fixture()),
        refreshResult: StubResult = .success(.fixture()),
        delay: Duration = .zero
    ) {
        self.signUpResult = signUpResult
        self.refreshResult = refreshResult
        self.delay = delay
    }

    func setSignUpResult(_ result: StubResult) { signUpResult = result }
    func setRefreshResult(_ result: StubResult) { refreshResult = result }

    func createAnonymousSession() async throws -> AuthSessionDTO {
        signUpCallCount += 1
        if delay > .zero { try? await Task.sleep(for: delay) }
        switch signUpResult {
        case .success(let dto): return dto
        case .failure(let error): throw error
        }
    }

    func refreshSession(refreshToken: String) async throws -> AuthSessionDTO {
        refreshCallCount += 1
        if delay > .zero { try? await Task.sleep(for: delay) }
        switch refreshResult {
        case .success(let dto): return dto
        case .failure(let error): throw error
        }
    }
}

extension AuthSessionDTO {
    static func fixture(
        userID: UUID = UUID(),
        accessToken: String = "access-token",
        refreshToken: String = "refresh-token",
        expiresIn: Int = 3_600,
        isAnonymous: Bool = true
    ) -> AuthSessionDTO {
        AuthSessionDTO(
            accessToken: accessToken,
            tokenType: "bearer",
            expiresIn: expiresIn,
            refreshToken: refreshToken,
            user: AuthUserDTO(id: userID, isAnonymous: isAnonymous)
        )
    }
}

struct FixtureError: Error, Equatable, Sendable {}
