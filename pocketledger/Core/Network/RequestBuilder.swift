import Foundation

/// Turns a declarative `APIRequest` into a concrete `URLRequest`.
///
/// URLs are always assembled through `URLComponents`/`URLQueryItem` —
/// never string concatenation — so query values are escaped correctly.
struct RequestBuilder: Sendable {
    enum BuildError: Error, Sendable {
        case invalidURL
    }

    let supabaseURL: URL
    let publishableKey: String

    func urlRequest<Response>(
        for request: APIRequest<Response>,
        accessToken: String?
    ) throws -> URLRequest {
        let baseURL = request.service.baseURL(supabaseURL: supabaseURL)
        let resourceURL = baseURL.appendingPathComponent(request.path)

        guard var components = URLComponents(url: resourceURL, resolvingAgainstBaseURL: false) else {
            throw BuildError.invalidURL
        }

        if !request.queryItems.isEmpty {
            components.queryItems = request.queryItems
        }

        guard let url = components.url else {
            throw BuildError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body

        urlRequest.setValue(publishableKey, forHTTPHeaderField: "apikey")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        if request.body != nil {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        if request.requiresAuth, let accessToken {
            urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        for (field, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: field)
        }

        return urlRequest
    }
}
