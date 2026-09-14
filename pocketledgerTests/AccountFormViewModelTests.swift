import Foundation
import Testing
@testable import pocketledger

@MainActor
struct AccountFormViewModelTests {
    private let currency = CurrencyCode(rawValue: "TRY")!

    private func makeViewModel(
        mode: AccountFormMode = .create,
        accountRepository: FakeAccountRepository = FakeAccountRepository()
    ) -> AccountFormViewModel {
        AccountFormViewModel(
            mode: mode,
            currency: currency,
            createAccountUseCase: CreateAccountUseCase(accountRepository: accountRepository),
            updateAccountUseCase: UpdateAccountUseCase(accountRepository: accountRepository)
        )
    }

    @Test func creatingWithValidInputSucceeds() async {
        let viewModel = makeViewModel()
        viewModel.name = "New Account"
        viewModel.amountText = "1500.50"

        let account = await viewModel.save()

        #expect(account?.name == "New Account")
        #expect(account?.openingBalance.minorUnits == 150_050)
        #expect(viewModel.saveState == .idle)
    }

    @Test func creditCardAmountIsStoredAsNegative() async {
        let viewModel = makeViewModel()
        viewModel.name = "My Card"
        viewModel.kind = .creditCard
        viewModel.amountText = "2000"

        let account = await viewModel.save()

        #expect(account?.openingBalance.minorUnits == -200_000)
    }

    @Test func invalidAmountShowsAFieldErrorAndDoesNotSave() async {
        let accountRepository = FakeAccountRepository()
        let viewModel = makeViewModel(accountRepository: accountRepository)
        viewModel.name = "Valid Name"
        viewModel.amountText = "not a number"

        let account = await viewModel.save()

        #expect(account == nil)
        #expect(viewModel.amountFieldError != nil)
    }

    @Test func emptyNameFailsWithAValidationMessage() async {
        let viewModel = makeViewModel()
        viewModel.name = ""
        viewModel.amountText = "100"

        let account = await viewModel.save()

        #expect(account == nil)
        guard case .failed = viewModel.saveState else {
            Issue.record("Expected .failed save state")
            return
        }
    }

    @Test func editModePrefillsExistingAccountFields() {
        let existing = Account(
            id: UUID(), name: "Existing", kind: .creditCard,
            openingBalance: Money(minorUnits: -50_000, currency: currency),
            isArchived: false, archivedAt: nil, createdAt: Date(), updatedAt: Date()
        )
        let viewModel = makeViewModel(mode: .edit(existing))

        #expect(viewModel.name == "Existing")
        #expect(viewModel.isEditing)
        #expect(viewModel.amountText == "500.00")
        #expect(!viewModel.isKindEditable)
    }

    @Test func remoteFailureDuringSaveIsSurfacedAsAMessage() async {
        let accountRepository = FakeAccountRepository()
        accountRepository.createError = RepositoryError.serviceUnavailable
        let viewModel = makeViewModel(accountRepository: accountRepository)
        viewModel.name = "New Account"
        viewModel.amountText = "100"

        let account = await viewModel.save()

        #expect(account == nil)
        guard case .failed = viewModel.saveState else {
            Issue.record("Expected .failed save state")
            return
        }
    }
}
