import Foundation

/// The business-rule reasons a transaction draft can be rejected.
///
/// Distinct from infrastructure errors (`NetworkError`, `RepositoryError`,
/// added in later phases): these are field-level, user-correctable
/// mistakes, not failures of the network or the backend.
enum TransactionValidationError: Error, Equatable, Sendable {
    case amountMustBePositive
    case titleRequired
    case futureDateNotAllowed
    case categoryRequiredForExpense
    case categoryNotAllowedForIncome
    case categoryNotAllowedForTransfer
    case destinationAccountRequiredForTransfer
    case destinationAccountNotAllowedForThisKind
    case transferSourceAndDestinationMustDiffer
}

/// Validates a `NewTransaction` draft against PocketLedger's transaction
/// invariants (see the Database specification's `transactions_kind_shape_check`
/// constraint, which this mirrors on the client so mistakes surface as an
/// immediate field error rather than a round-trip to the server).
enum TransactionValidator {
    static func validate(
        _ transaction: NewTransaction,
        today: LocalDate = .today()
    ) throws {
        guard transaction.amount.minorUnits > 0 else {
            throw TransactionValidationError.amountMustBePositive
        }

        guard !transaction.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TransactionValidationError.titleRequired
        }

        guard transaction.date <= today else {
            throw TransactionValidationError.futureDateNotAllowed
        }

        switch transaction.kind {
        case .income:
            guard transaction.category == nil else {
                throw TransactionValidationError.categoryNotAllowedForIncome
            }
            guard transaction.destinationAccountID == nil else {
                throw TransactionValidationError.destinationAccountNotAllowedForThisKind
            }

        case .expense:
            guard transaction.category != nil else {
                throw TransactionValidationError.categoryRequiredForExpense
            }
            guard transaction.destinationAccountID == nil else {
                throw TransactionValidationError.destinationAccountNotAllowedForThisKind
            }

        case .transfer:
            guard transaction.category == nil else {
                throw TransactionValidationError.categoryNotAllowedForTransfer
            }
            guard let destinationAccountID = transaction.destinationAccountID else {
                throw TransactionValidationError.destinationAccountRequiredForTransfer
            }
            guard destinationAccountID != transaction.sourceAccountID else {
                throw TransactionValidationError.transferSourceAndDestinationMustDiffer
            }
        }
    }
}
