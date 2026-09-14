import Foundation

/// A three-letter ISO-4217-style currency code (e.g. `TRY`, `USD`).
///
/// Mirrors the remote `wallet_profiles.base_currency_code` check constraint
/// (`^[A-Z]{3}$`) so an invalid code can never enter the domain layer.
struct CurrencyCode: Hashable, Sendable, CustomStringConvertible {
    let rawValue: String

    init?(rawValue: String) {
        guard Self.isValid(rawValue) else { return nil }
        self.rawValue = rawValue
    }

    var description: String { rawValue }

    private static func isValid(_ value: String) -> Bool {
        value.count == 3 && value.allSatisfy { $0.isASCII && $0.isLetter && $0.isUppercase }
    }
}

extension CurrencyCode: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let value = CurrencyCode(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid currency code: \(rawValue)"
            )
        }
        self = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
