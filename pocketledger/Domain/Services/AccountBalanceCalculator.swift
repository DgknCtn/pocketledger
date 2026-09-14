/// Computes an account's current balance from its opening balance and the
/// full transaction set — balance is never persisted, only derived.
///
/// Formula: `opening + income − expense − transferOut + transferIn`.
/// Transactions belonging to other accounts are ignored, so callers may pass
/// the user's complete transaction list rather than pre-filtering it.
enum AccountBalanceCalculator {
    /// Thrown only if a transaction's amount is denominated in a different
    /// currency than the account's opening balance — an internal
    /// data-integrity violation in this P0 (single base-currency) app, not
    /// a scenario a user can trigger through normal use.
    enum CalculationError: Error, Equatable, Sendable {
        case currencyMismatch(Money.CurrencyMismatchError)
    }

    static func balance(for account: Account, transactions: [Transaction]) throws -> Money {
        var balance = account.openingBalance

        do {
            for transaction in transactions {
                switch transaction.kind {
                case .income where transaction.sourceAccountID == account.id:
                    balance = try balance.adding(transaction.amount)

                case .expense where transaction.sourceAccountID == account.id:
                    balance = try balance.subtracting(transaction.amount)

                case .transfer where transaction.sourceAccountID == account.id:
                    balance = try balance.subtracting(transaction.amount)

                case .transfer where transaction.destinationAccountID == account.id:
                    balance = try balance.adding(transaction.amount)

                default:
                    continue
                }
            }
        } catch let error as Money.CurrencyMismatchError {
            throw CalculationError.currencyMismatch(error)
        }

        return balance
    }
}
