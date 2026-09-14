import Foundation
import Testing
@testable import pocketledger

private struct FixtureResponse: Decodable, Sendable { let value: String }

struct RequestBuilderTests {
    private let builder = RequestBuilder(
        supabaseURL: URL(string: "https://example.supabase.co")!,
        publishableKey: "sb_publishable_test"
    )

    @Test func buildsGETRequestWithCorrectURLAndMethod() throws {
        let request = APIRequest<FixtureResponse>(service: .data, path: "accounts", method: .get)

        let urlRequest = try builder.urlRequest(for: request, accessToken: nil)

        #expect(urlRequest.url?.absoluteString == "https://example.supabase.co/rest/v1/accounts")
        #expect(urlRequest.httpMethod == "GET")
    }

    @Test func usesAuthBasePathForAuthService() throws {
        let request = APIRequest<FixtureResponse>(
            service: .auth,
            path: "signup",
            method: .post,
            requiresAuth: false
        )

        let urlRequest = try builder.urlRequest(for: request, accessToken: nil)

        #expect(urlRequest.url?.absoluteString == "https://example.supabase.co/auth/v1/signup")
    }

    @Test func includesQueryItemsEscapedCorrectly() throws {
        let request = APIRequest<FixtureResponse>(
            service: .data,
            path: "transactions",
            method: .get,
            queryItems: [
                URLQueryItem(name: "select", value: "id,title"),
                URLQueryItem(name: "title", value: "ilike.*coffee & tea*"),
            ]
        )

        let urlRequest = try builder.urlRequest(for: request, accessToken: nil)
        let components = URLComponents(url: urlRequest.url!, resolvingAgainstBaseURL: false)!

        #expect(components.queryItems?.first(where: { $0.name == "select" })?.value == "id,title")
        #expect(components.queryItems?.first(where: { $0.name == "title" })?.value == "ilike.*coffee & tea*")
    }

    @Test func alwaysIncludesThePublishableKeyHeader() throws {
        let request = APIRequest<FixtureResponse>(service: .data, path: "accounts", method: .get)

        let urlRequest = try builder.urlRequest(for: request, accessToken: nil)

        #expect(urlRequest.value(forHTTPHeaderField: "apikey") == "sb_publishable_test")
    }

    @Test func addsAuthorizationHeaderWhenTokenProvidedAndRequired() throws {
        let request = APIRequest<FixtureResponse>(service: .data, path: "accounts", method: .get)

        let urlRequest = try builder.urlRequest(for: request, accessToken: "token-123")

        #expect(urlRequest.value(forHTTPHeaderField: "Authorization") == "Bearer token-123")
    }

    @Test func omitsAuthorizationHeaderWhenRequestDoesNotRequireIt() throws {
        let request = APIRequest<FixtureResponse>(
            service: .auth,
            path: "signup",
            method: .post,
            requiresAuth: false
        )

        // Even if a token happens to be available, an unauthenticated
        // endpoint like /signup must never receive it.
        let urlRequest = try builder.urlRequest(for: request, accessToken: "token-123")

        #expect(urlRequest.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test func setsContentTypeOnlyWhenBodyIsPresent() throws {
        let withBody = APIRequest<FixtureResponse>(
            service: .data,
            path: "accounts",
            method: .post,
            body: Data("{}".utf8)
        )
        let withoutBody = APIRequest<FixtureResponse>(service: .data, path: "accounts", method: .get)

        let withBodyRequest = try builder.urlRequest(for: withBody, accessToken: nil)
        let withoutBodyRequest = try builder.urlRequest(for: withoutBody, accessToken: nil)

        #expect(withBodyRequest.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(withBodyRequest.httpBody == Data("{}".utf8))
        #expect(withoutBodyRequest.value(forHTTPHeaderField: "Content-Type") == nil)
    }

    @Test func customHeadersArePassedThrough() throws {
        let request = APIRequest<FixtureResponse>(
            service: .data,
            path: "transactions",
            method: .post,
            headers: ["Prefer": "return=representation"]
        )

        let urlRequest = try builder.urlRequest(for: request, accessToken: nil)

        #expect(urlRequest.value(forHTTPHeaderField: "Prefer") == "return=representation")
    }
}
