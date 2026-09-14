import Foundation

enum TransactionFormMode: Equatable {
    case create
    case edit(Transaction)
}

enum TransactionFormSaveState: Equatable {
    case idle
    case saving
    case failed(String)
}

@MainActor
@Observable
final class TransactionFormViewModel {
    var kind: TransactionKind
    var sourceAccountID: UUID?
    var destinationAccountID: UUID?
    var amountText: String
    var category: TransactionCategory?
    var title: String
    var note: String
    var date: Date

    private(set) var saveState: TransactionFormSaveState = .idle
    private(set) var fieldError: String?

    let mode: TransactionFormMode
    let accounts: [Account]
    private let currency: CurrencyCode
    private let createUseCase: CreateTransactionUseCase
    private let updateUseCase: UpdateTransactionUseCase

    init(
        mode: TransactionFormMode,
        accounts: [Account],
        currency: CurrencyCode,
        createUseCase: CreateTransactionUseCase,
        updateUseCase: UpdateTransactionUseCase
    ) {
        self.mode = mode
        self.accounts = accounts
        self.currency = currency
        self.createUseCase = createUseCase
        self.updateUseCase = updateUseCase

        switch mode {
        case .create:
            kind = .expense
            sourceAccountID = accounts.first(where: { !$0.isArchived })?.id
            destinationAccountID = nil
            amountText = ""
            category = .food
            title = ""
            note = ""
            date = Date()

        case .edit(let transaction):
            kind = transaction.kind
            sourceAccountID = transaction.sourceAccountID
            destinationAccountID = transaction.destinationAccountID
            amountText = MoneyInput.editableText(forMinorUnits: transaction.amount.minorUnits)
            category = transaction.category ?? .food
            title = transaction.title
            note = transaction.note ?? ""
            date = transaction.date.asDate()
        }
    }

    var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var availableDestinationAccounts: [Account] {
        accounts.filter { $0.id != sourceAccountID }
    }

    @discardableResult
    func save() async -> Transaction? {
        fieldError = nil

        guard let sourceAccountID else {
            fieldError = "Choose an account."
            return nil
        }

        guard let money = MoneyInput.parse(amountText, currency: currency) else {
            fieldError = "Enter a valid amount."
            return nil
        }

        let resolvedDestination = kind == .transfer ? destinationAccountID : nil
        let resolvedCategory = kind == .expense ? category : nil
        let resolvedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let localDate = LocalDate(date: date)

        saveState = .saving

        do {
            let transaction: Transaction
            switch mode {
            case .create:
                transaction = try await createUseCase.execute(
                    kind: kind,
                    sourceAccountID: sourceAccountID,
                    destinationAccountID: resolvedDestination,
                    amount: money,
                    category: resolvedCategory,
                    title: title,
                    note: resolvedNote.isEmpty ? nil : resolvedNote,
                    date: localDate
                )

            case .edit(let existing):
                transaction = try await updateUseCase.execute(
                    id: existing.id,
                    kind: kind,
                    sourceAccountID: sourceAccountID,
                    destinationAccountID: resolvedDestination,
                    amount: money,
                    category: resolvedCategory,
                    title: title,
                    note: resolvedNote.isEmpty ? nil : resolvedNote,
                    date: localDate
                )
            }
            saveState = .idle
            return transaction
        } catch let error as TransactionValidationError {
            saveState = .failed(Self.message(for: error))
            return nil
        } catch {
            saveState = .failed(PresentationErrorMapper.message(for: error))
            return nil
        }
    }

    private static func message(for error: TransactionValidationError) -> String {
        switch error {
        case .amountMustBePositive:
            "Enter an amount greater than zero."
        case .titleRequired:
            "Give this transaction a title."
        case .futureDateNotAllowed:
            "The date can't be in the future."
        case .categoryRequiredForExpense:
            "Choose a category."
        case .categoryNotAllowedForIncome, .categoryNotAllowedForTransfer:
            "This transaction type doesn't use a category."
        case .destinationAccountRequiredForTransfer:
            "Choose a destination account."
        case .destinationAccountNotAllowedForThisKind:
            "This transaction type doesn't use a destination account."
        case .transferSourceAndDestinationMustDiffer:
            "Choose two different accounts."
        }
    }
}
