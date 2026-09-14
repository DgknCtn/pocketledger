import Foundation

struct CreateAccountUseCase {
    let accountRepository: AccountRepository

    func execute(name: String, kind: AccountKind, openingBalance: Money) async throws -> Account {
        try AccountValidator.validate(name: name)
        let input = CreateAccountInput(id: UUID(), name: name, kind: kind, openingBalance: openingBalance)
        return try await accountRepository.createAccount(input)
    }
}
