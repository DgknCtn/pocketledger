import Foundation

/// A deterministic, in-process `URLProtocol` stand-in for the real network.
/// Networking tests never touch the real internet or a real Supabase
/// project — they configure `requestHandler` and inspect the `URLRequest`
/// that `URLSessionNetworkClient` produced.
///
/// `requestHandler` is a single shared static, so any test suite using it
/// must not run its tests concurrently with each other (see
/// `NetworkClientTests`, which opts into `.serialized`).
final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        // URLSession sometimes moves a POST/PATCH body into
        // `httpBodyStream` rather than delivering it via `httpBody` on the
        // request the protocol sees — reconstruct it so callers can always
        // read `request.httpBody`.
        var observedRequest = request
        if observedRequest.httpBody == nil, let stream = request.httpBodyStream {
            observedRequest.httpBody = Data(readingRemainderOf: stream)
        }

        do {
            let (response, data) = try handler(observedRequest)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private extension Data {
    init(readingRemainderOf stream: InputStream) {
        self.init()
        stream.open()
        defer { stream.close() }

        let bufferSize = 4_096
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        while stream.hasBytesAvailable {
            let bytesRead = stream.read(&buffer, maxLength: bufferSize)
            guard bytesRead > 0 else { break }
            append(buffer, count: bytesRead)
        }
    }
}
