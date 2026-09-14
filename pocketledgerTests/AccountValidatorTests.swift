import Testing
@testable import pocketledger

struct AccountValidatorTests {
    @Test func validNamePasses() throws {
        try AccountValidator.validate(name: "Main Account")
    }

    @Test func emptyNameFails() {
        #expect(throws: AccountValidationError.nameRequired) {
            try AccountValidator.validate(name: "")
        }
    }

    @Test func whitespaceOnlyNameFails() {
        #expect(throws: AccountValidationError.nameRequired) {
            try AccountValidator.validate(name: "   ")
        }
    }

    @Test func nameOverFiftyCharactersFails() {
        let longName = String(repeating: "a", count: 51)
        #expect(throws: AccountValidationError.nameTooLong) {
            try AccountValidator.validate(name: longName)
        }
    }

    @Test func nameExactlyFiftyCharactersPasses() throws {
        let name = String(repeating: "a", count: 50)
        try AccountValidator.validate(name: name)
    }
}
