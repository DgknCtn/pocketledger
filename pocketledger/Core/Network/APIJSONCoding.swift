import Foundation

/// Builds the single, shared `JSONDecoder` used for all Data/Auth API
/// responses.
///
/// PostgreSQL `timestamptz` values may or may not include fractional
/// seconds (`2026-09-14T13:15:22Z` vs `2026-09-14T13:15:22.123456Z`), so
/// both ISO-8601 variants are tried in order. A date that matches neither is
/// treated as a contract violation (a decoding error), never silently
/// defaulted to `Date()`.
enum APIJSONDecoder {
    static func make() -> JSONDecoder {
        let withFractionalSeconds = ISO8601DateFormatter()
        withFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let withoutFractionalSeconds = ISO8601DateFormatter()
        withoutFractionalSeconds.formatOptions = [.withInternetDateTime]

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { valueDecoder in
            let container = try valueDecoder.singleValueContainer()
            let string = try container.decode(String.self)

            if let date = withFractionalSeconds.date(from: string) {
                return date
            }
            if let date = withoutFractionalSeconds.date(from: string) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO-8601 timestamp: \(string)"
            )
        }
        return decoder
    }
}

/// Builds the shared `JSONEncoder` used for all Data/Auth API request
/// bodies. No custom date-encoding strategy is needed: request DTOs encode
/// `transaction_date` as a plain `"YYYY-MM-DD"` `String` themselves rather
/// than relying on encoder-level `Date` formatting, to avoid introducing
/// timezone semantics into a calendar-date field.
enum APIJSONEncoder {
    static func make() -> JSONEncoder {
        JSONEncoder()
    }
}
