import Foundation

enum AccountValidationError: Error, Equatable, Sendable {
    case nameRequired
    case nameTooLong
}

/// Mirrors the remote `accounts_name_not_empty` constraint
/// (`char_length(btrim(name)) between 1 and 50`) client-side.
enum AccountValidator {
    static let maxNameLength = 50

    static func validate(name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AccountValidationError.nameRequired }
        guard trimmed.count <= maxNameLength else { throw AccountValidationError.nameTooLong }
    }
}
