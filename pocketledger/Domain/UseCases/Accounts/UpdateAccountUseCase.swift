import Foundation

struct UpdateAccountUseCase {
    let accountRepository: AccountRepository

    func execute(id: UUID, name: String, openingBalance: Money) async throws -> Account {
        try AccountValidator.validate(name: name)
        let input = UpdateAccountInput(id: id, name: name, openingBalance: openingBalance)
        return try await accountRepository.updateAccount(input)
    }
}
