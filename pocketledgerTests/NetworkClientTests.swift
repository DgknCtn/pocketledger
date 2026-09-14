import Foundation
import os
import Testing
@testable import pocketledger

private struct FixtureResponse: Decodable, Sendable, Equatable {
    let id: String
    let value: Int
}

private struct FakeAuthorizationProvider: AuthorizationTokenProviding {
    enum Behavior: Sendable {
        case token(String)
        case failure
    }

    let behavior: Behavior

    func validAccessToken() async throws -> String {
        switch behavior {
        case .token(let token):
            return token
        case .failure:
            throw NetworkError.unauthorized
        }
    }
}

/// `MockURLProtocol.requestHandler` is a single shared static, so these
/// tests must not run concurrently with each other.
@Suite(.serialized)
struct NetworkClientTests {
    private let supabaseURL = URL(string: "https://example.supabase.co")!

    private func makeClient(
        authorizationProvider: AuthorizationTokenProviding? = nil
    ) -> URLSessionNetworkClient {
        URLSessionNetworkClient(
            session: MockURLProtocol.makeSession(),
            requestBuilder: RequestBuilder(supabaseURL: supabaseURL, publishableKey: "sb_publishable_test"),
            authorizationProvider: authorizationProvider
        )
    }

    private func stub(statusCode: Int, json: String) {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(json.utf8))
        }
    }

    // MARK: - Success

    @Test func decodesASuccessfulJSONResponse() async throws {
        stub(statusCode: 200, json: #"{"id":"abc","value":42}"#)
        let client = makeClient(authorizationProvider: FakeAuthorizationProvider(behavior: .token("t")))

        let result = try await client.send(
            APIRequest<FixtureResponse>(service: .data, path: "accounts", method: .get)
        )

        #expect(result == FixtureResponse(id: "abc", value: 42))
    }

    @Test func decodes201CreatedAsSuccess() async throws {
        stub(statusCode: 201, json: #"{"id":"new","value":1}"#)
        let client = makeClient(authorizationProvider: FakeAuthorizationProvider(behavior: .token("t")))

        let result = try await client.send(
            APIRequest<FixtureResponse>(service: .data, path: "accounts", method: .post)
        )

        #expect(result == FixtureResponse(id: "new", value: 1))
    }

    // MARK: - Authorization

    @Test func attachesBearerTokenToAuthenticatedRequest() async throws {
        let capturedAuthorizationHeader = OSAllocatedUnfairLock<String?>(initialState: nil)
        MockURLProtocol.requestHandler = { request in
            capturedAuthorizationHeader.withLock { $0 = request.value(forHTTPHeaderField: "Authorization") }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"id":"a","value":1}"#.utf8))
        }
        let client = makeClient(authorizationProvider: FakeAuthorizationProvider(behavior: .token("secret-token")))

        _ = try await client.send(APIRequest<FixtureResponse>(service: .data, path: "accounts", method: .get))

        #expect(capturedAuthorizationHeader.withLock { $0 } == "Bearer secret-token")
    }

    @Test func doesNotRequireAnAuthorizationProviderForUnauthenticatedRequests() async throws {
        let capturedAuthorizationHeader = OSAllocatedUnfairLock<String?>(initialState: nil)
        MockURLProtocol.requestHandler = { request in
            capturedAuthorizationHeader.withLock { $0 = request.value(forHTTPHeaderField: "Authorization") }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"id":"a","value":1}"#.utf8))
        }
        // No authorizationProvider at all — must still succeed for /signup-like requests.
        let client = makeClient(authorizationProvider: nil)

        _ = try await client.send(
            APIRequest<FixtureResponse>(service: .auth, path: "signup", method: .post, requiresAuth: false)
        )

        #expect(capturedAuthorizationHeader.withLock { $0 } == nil)
    }

    @Test func missingAuthorizationProviderForAnAuthenticatedRequestThrows() async {
        let client = makeClient(authorizationProvider: nil)

        await #expect(throws: NetworkError.invalidRequest) {
            try await client.send(APIRequest<FixtureResponse>(service: .data, path: "accounts", method: .get))
        }
    }

    // MARK: - Decoding failures

    @Test func malformedJSONThrowsDecodingError() async {
        stub(statusCode: 200, json: "not json")
        let client = makeClient(authorizationProvider: FakeAuthorizationProvider(behavior: .token("t")))

        await #expect(throws: NetworkError.decoding) {
            try await client.send(APIRequest<FixtureResponse>(service: .data, path: "accounts", method: .get))
        }
    }

    // MARK: - HTTP status mapping

    @Test func maps401ToUnauthorized() async {
        stub(statusCode: 401, json: "{}")
        let client = makeClient(authorizationProvider: FakeAuthorizationProvider(behavior: .token("t")))

        await #expect(throws: NetworkError.unauthorized) {
            try await client.send(APIRequest<FixtureResponse>(service: .data, path: "accounts", method: .get))
        }
    }

    @Test func maps403ToForbidden() async {
        stub(statusCode: 403, json: "{}")
        let client = makeClient(authorizationProvider: FakeAuthorizationProvider(behavior: .token("t")))

        await #expect(throws: NetworkError.forbidden) {
            try await client.send(APIRequest<FixtureResponse>(service: .data, path: "accounts", method: .get))
        }
    }

    @Test func maps429ToRateLimited() async {
        stub(statusCode: 429, json: "{}")
        let client = makeClient(authorizationProvider: FakeAuthorizationProvider(behavior: .token("t")))

        await #expect(throws: NetworkError.rateLimited) {
            try await client.send(APIRequest<FixtureResponse>(service: .data, path: "accounts", method: .get))
        }
    }

    @Test func maps500ToServerError() async {
        stub(statusCode: 500, json: "{}")
        let client = makeClient(authorizationProvider: FakeAuthorizationProvider(behavior: .token("t")))

        await #expect(throws: NetworkError.server(statusCode: 500)) {
            try await client.send(APIRequest<FixtureResponse>(service: .data, path: "accounts", method: .get))
        }
    }

    @Test func maps409WithPostgRESTBodyToTypedAPIError() async {
        stub(
            statusCode: 409,
            json: #"{"code":"23503","details":"...","hint":null,"message":"violates foreign key"}"#
        )
        let client = makeClient(authorizationProvider: FakeAuthorizationProvider(behavior: .token("t")))

        await #expect(
            throws: NetworkError.api(statusCode: 409, code: "23503", message: "violates foreign key")
        ) {
            try await client.send(APIRequest<FixtureResponse>(service: .data, path: "accounts", method: .delete))
        }
    }

    @Test func maps400WithoutParseablePostgRESTBodyToUntypedAPIError() async {
        stub(statusCode: 400, json: "not json")
        let client = makeClient(authorizationProvider: FakeAuthorizationProvider(behavior: .token("t")))

        await #expect(throws: NetworkError.api(statusCode: 400, code: nil, message: "")) {
            try await client.send(APIRequest<FixtureResponse>(service: .data, path: "accounts", method: .post))
        }
    }

    // MARK: - Transport failures

    @Test func offlineMapsToTransportError() async {
        MockURLProtocol.requestHandler = { _ in throw URLError(.notConnectedToInternet) }
        let client = makeClient(authorizationProvider: FakeAuthorizationProvider(behavior: .token("t")))

        await #expect(throws: NetworkError.transport(.notConnectedToInternet)) {
            try await client.send(APIRequest<FixtureResponse>(service: .data, path: "accounts", method: .get))
        }
    }

    @Test func timeoutMapsToTransportError() async {
        MockURLProtocol.requestHandler = { _ in throw URLError(.timedOut) }
        let client = makeClient(authorizationProvider: FakeAuthorizationProvider(behavior: .token("t")))

        await #expect(throws: NetworkError.transport(.timedOut)) {
            try await client.send(APIRequest<FixtureResponse>(service: .data, path: "accounts", method: .get))
        }
    }

    @Test func cancellationMapsToCancelledNotAGenericError() async {
        MockURLProtocol.requestHandler = { _ in throw URLError(.cancelled) }
        let client = makeClient(authorizationProvider: FakeAuthorizationProvider(behavior: .token("t")))

        await #expect(throws: NetworkError.cancelled) {
            try await client.send(APIRequest<FixtureResponse>(service: .data, path: "accounts", method: .get))
        }
    }

    // MARK: - DefaultAuthRemoteDataSource
    //
    // Also exercised through `MockURLProtocol`, so these live in this same
    // `.serialized` suite rather than a separate one — two suites each
    // individually serialized can still run *relative to each other* in
    // parallel and clobber the shared handler.

    private func makeAuthDataSource() -> DefaultAuthRemoteDataSource {
        DefaultAuthRemoteDataSource(networkClient: makeClient(authorizationProvider: nil))
    }

    @Test func anonymousSignUpPostsToSignupWithoutAuthorization() async throws {
        let capturedRequest = OSAllocatedUnfairLock<URLRequest?>(initialState: nil)
        MockURLProtocol.requestHandler = { request in
            capturedRequest.withLock { $0 = request }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(Self.fixtureSessionJSON.utf8))
        }

        _ = try await makeAuthDataSource().createAnonymousSession()

        let request = try #require(capturedRequest.withLock { $0 })
        #expect(request.url?.absoluteString == "https://example.supabase.co/auth/v1/signup")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(request.value(forHTTPHeaderField: "apikey") == "sb_publishable_test")
    }

    @Test func refreshSessionSendsGrantTypeQueryAndRefreshTokenBody() async throws {
        let capturedRequest = OSAllocatedUnfairLock<URLRequest?>(initialState: nil)
        MockURLProtocol.requestHandler = { request in
            capturedRequest.withLock { $0 = request }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(Self.fixtureSessionJSON.utf8))
        }

        _ = try await makeAuthDataSource().refreshSession(refreshToken: "old-refresh-token")

        let request = try #require(capturedRequest.withLock { $0 })
        let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
        #expect(components.path == "/auth/v1/token")
        #expect(components.queryItems?.first(where: { $0.name == "grant_type" })?.value == "refresh_token")

        let bodyJSON = try JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: String]
        #expect(bodyJSON?["refresh_token"] == "old-refresh-token")
    }

    @Test func decodesAuthSessionResponse() async throws {
        stub(statusCode: 200, json: Self.fixtureSessionJSON)

        let dto = try await makeAuthDataSource().createAnonymousSession()

        #expect(dto.accessToken == "the-access-token")
        #expect(dto.refreshToken == "the-refresh-token")
        #expect(dto.expiresIn == 3_600)
        #expect(dto.user.isAnonymous == true)
    }

    private static let fixtureSessionJSON = """
    {
      "access_token": "the-access-token",
      "token_type": "bearer",
      "expires_in": 3600,
      "refresh_token": "the-refresh-token",
      "user": {
        "id": "20e9b6f4-45d4-4c5a-b243-98680e14ebff",
        "is_anonymous": true
      }
    }
    """
}
