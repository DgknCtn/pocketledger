import Foundation
import Testing
@testable import pocketledger

@MainActor
struct TransactionFormViewModelTests {
    private let currency = CurrencyCode(rawValue: "TRY")!

    private func account(name: String = "Main") -> Account {
        Account(
            id: UUID(), name: name, kind: .bank,
            openingBalance: Money(minorUnits: 0, currency: currency),
            isArchived: false, archivedAt: nil, createdAt: Date(), updatedAt: Date()
        )
    }

    private func makeViewModel(
        mode: TransactionFormMode = .create,
        accounts: [Account],
        repository: FakeTransactionRepository = FakeTransactionRepository()
    ) -> TransactionFormViewModel {
        TransactionFormViewModel(
            mode: mode,
            accounts: accounts,
            currency: currency,
            createUseCase: CreateTransactionUseCase(transactionRepository: repository),
            updateUseCase: UpdateTransactionUseCase(transactionRepository: repository)
        )
    }

    @Test func creatingAValidExpenseSucceeds() async {
        let account = account()
        let viewModel = makeViewModel(accounts: [account])
        viewModel.title = "Groceries"
        viewModel.amountText = "150.00"
        viewModel.category = .food

        let transaction = await viewModel.save()

        #expect(transaction?.title == "Groceries")
        #expect(transaction?.category == .food)
        #expect(viewModel.saveState == .idle)
    }

    @Test func missingSourceAccountShowsAFieldError() async {
        let viewModel = makeViewModel(accounts: [])
        viewModel.title = "Groceries"
        viewModel.amountText = "150.00"

        let transaction = await viewModel.save()

        #expect(transaction == nil)
        #expect(viewModel.fieldError != nil)
    }

    @Test func invalidAmountShowsAFieldError() async {
        let viewModel = makeViewModel(accounts: [account()])
        viewModel.title = "Groceries"
        viewModel.amountText = "not a number"

        let transaction = await viewModel.save()

        #expect(transaction == nil)
        #expect(viewModel.fieldError != nil)
    }

    @Test func domainValidationFailureIsSurfacedAsASaveStateMessage() async {
        let viewModel = makeViewModel(accounts: [account()])
        viewModel.title = ""
        viewModel.amountText = "150.00"

        let transaction = await viewModel.save()

        #expect(transaction == nil)
        guard case .failed = viewModel.saveState else {
            Issue.record("Expected .failed save state")
            return
        }
    }

    @Test func transferModeIgnoresCategoryAndUsesDestination() async {
        let source = account(name: "Main")
        let destination = account(name: "Savings")
        let viewModel = makeViewModel(accounts: [source, destination])
        viewModel.kind = .transfer
        viewModel.sourceAccountID = source.id
        viewModel.destinationAccountID = destination.id
        viewModel.title = "Move to savings"
        viewModel.amountText = "500"

        let transaction = await viewModel.save()

        #expect(transaction?.kind == .transfer)
        #expect(transaction?.destinationAccountID == destination.id)
        #expect(transaction?.category == nil)
    }

    @Test func editModePrefillsExistingTransactionFields() {
        let source = account()
        let existing = Transaction(
            id: UUID(), kind: .expense, sourceAccountID: source.id, destinationAccountID: nil,
            amount: Money(minorUnits: 12_345, currency: currency), category: .bills,
            title: "Electricity", note: "Monthly", date: try! LocalDate(parsing: "2026-09-01"),
            createdAt: Date(), updatedAt: Date()
        )
        let viewModel = makeViewModel(mode: .edit(existing), accounts: [source])

        #expect(viewModel.isEditing)
        #expect(viewModel.title == "Electricity")
        #expect(viewModel.amountText == "123.45")
        #expect(viewModel.category == .bills)
        #expect(viewModel.note == "Monthly")
    }

    @Test func availableDestinationAccountsExcludesTheSelectedSource() {
        let source = account(name: "Main")
        let other = account(name: "Savings")
        let viewModel = makeViewModel(accounts: [source, other])
        viewModel.sourceAccountID = source.id

        #expect(viewModel.availableDestinationAccounts.map(\.id) == [other.id])
    }
}
