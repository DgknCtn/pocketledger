import Foundation

enum AccountFormMode: Equatable {
    case create
    case edit(Account)
}

enum AccountFormSaveState: Equatable {
    case idle
    case saving
    case failed(String)
}

@MainActor
@Observable
final class AccountFormViewModel {
    var name: String
    var kind: AccountKind
    /// A plain decimal string the user types into — for a credit card this
    /// is "how much do you currently owe", never a signed value (see the
    /// database specification's "Credit Card Creation UX").
    var amountText: String

    private(set) var saveState: AccountFormSaveState = .idle
    private(set) var amountFieldError: String?

    let mode: AccountFormMode
    private let currency: CurrencyCode
    private let createAccountUseCase: CreateAccountUseCase
    private let updateAccountUseCase: UpdateAccountUseCase

    init(
        mode: AccountFormMode,
        currency: CurrencyCode,
        createAccountUseCase: CreateAccountUseCase,
        updateAccountUseCase: UpdateAccountUseCase
    ) {
        self.mode = mode
        self.currency = currency
        self.createAccountUseCase = createAccountUseCase
        self.updateAccountUseCase = updateAccountUseCase

        switch mode {
        case .create:
            name = ""
            kind = .bank
            amountText = ""

        case .edit(let account):
            name = account.name
            kind = account.kind
            let magnitude = account.kind == .creditCard
                ? -account.openingBalance.minorUnits
                : account.openingBalance.minorUnits
            amountText = MoneyInput.editableText(forMinorUnits: magnitude)
        }
    }

    var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var amountFieldTitle: String {
        kind == .creditCard ? "Current Amount Owed" : "Starting Balance"
    }

    var isKindEditable: Bool {
        // Changing an account's kind after creation is out of P0 scope —
        // it would silently change credit-card sign semantics.
        !isEditing
    }

    @discardableResult
    func save() async -> Account? {
        amountFieldError = nil

        guard let magnitude = MoneyInput.parse(amountText, currency: currency) else {
            amountFieldError = "Enter a valid amount."
            return nil
        }

        let openingBalance = kind == .creditCard ? magnitude.negated : magnitude

        saveState = .saving
        do {
            let account: Account
            switch mode {
            case .create:
                account = try await createAccountUseCase.execute(name: name, kind: kind, openingBalance: openingBalance)
            case .edit(let existing):
                account = try await updateAccountUseCase.execute(
                    id: existing.id, name: name, openingBalance: openingBalance
                )
            }
            saveState = .idle
            return account
        } catch let error as AccountValidationError {
            saveState = .failed(Self.message(for: error))
            return nil
        } catch {
            saveState = .failed(PresentationErrorMapper.message(for: error))
            return nil
        }
    }

    private static func message(for error: AccountValidationError) -> String {
        switch error {
        case .nameRequired:
            "Give this account a name."
        case .nameTooLong:
            "Account names must be 50 characters or fewer."
        }
    }
}
