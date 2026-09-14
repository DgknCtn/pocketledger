import Foundation
import os
@testable import pocketledger

final class FakeAccountRemoteDataSource: AccountRemoteDataSource, @unchecked Sendable {
    private let state = OSAllocatedUnfairLock<[UUID: AccountDTO]>(initialState: [:])
    var fetchAllError: Error?
    var fetchOneError: Error?
    var createError: Error?
    var updateError: Error?
    var deleteError: Error?

    func seed(_ dto: AccountDTO) {
        state.withLock { $0[dto.id] = dto }
    }

    func fetchAccounts(includeArchived: Bool) async throws -> [AccountDTO] {
        if let fetchAllError { throw fetchAllError }
        return state.withLock { Array($0.values) }
    }

    func fetchAccount(id: UUID) async throws -> AccountDTO {
        if let fetchOneError { throw fetchOneError }
        guard let dto = state.withLock({ $0[id] }) else { throw SingleRowResponseError.notFound }
        return dto
    }

    func createAccount(_ request: CreateAccountRequestDTO) async throws -> AccountDTO {
        if let createError { throw createError }
        let now = Date()
        let dto = AccountDTO(
            id: request.id,
            userID: request.userID,
            name: request.name,
            kind: request.kind,
            openingBalanceMinor: request.openingBalanceMinor,
            isArchived: false,
            archivedAt: nil,
            createdAt: now,
            updatedAt: now
        )
        state.withLock { $0[dto.id] = dto }
        return dto
    }

    func updateAccount(id: UUID, request: UpdateAccountRequestDTO) async throws -> AccountDTO {
        if let updateError { throw updateError }
        guard let existing = state.withLock({ $0[id] }) else { throw SingleRowResponseError.notFound }
        let updated = AccountDTO(
            id: existing.id,
            userID: existing.userID,
            name: request.name,
            kind: existing.kind,
            openingBalanceMinor: request.openingBalanceMinor,
            isArchived: request.isArchived,
            archivedAt: request.archivedAt,
            createdAt: existing.createdAt,
            updatedAt: Date()
        )
        state.withLock { $0[id] = updated }
        return updated
    }

    func deleteAccount(id: UUID) async throws -> AccountDTO {
        if let deleteError { throw deleteError }
        guard let existing = state.withLock({ $0.removeValue(forKey: id) }) else {
            throw SingleRowResponseError.notFound
        }
        return existing
    }
}

final class FakeTransactionRemoteDataSource: TransactionRemoteDataSource, @unchecked Sendable {
    private let state = OSAllocatedUnfairLock<[UUID: TransactionDTO]>(initialState: [:])
    var fetchAllError: Error?
    var fetchOneError: Error?
    var createError: Error?
    var updateError: Error?
    var deleteError: Error?

    func seed(_ dto: TransactionDTO) {
        state.withLock { $0[dto.id] = dto }
    }

    func fetchTransactions() async throws -> [TransactionDTO] {
        if let fetchAllError { throw fetchAllError }
        return state.withLock { Array($0.values) }
    }

    func fetchTransaction(id: UUID) async throws -> TransactionDTO {
        if let fetchOneError { throw fetchOneError }
        guard let dto = state.withLock({ $0[id] }) else { throw SingleRowResponseError.notFound }
        return dto
    }

    func createTransaction(_ request: CreateTransactionRequestDTO) async throws -> TransactionDTO {
        if let createError { throw createError }
        let now = Date()
        let dto = TransactionDTO(
            id: request.id,
            userID: request.userID,
            kind: request.kind,
            accountID: request.accountID,
            destinationAccountID: request.destinationAccountID,
            amountMinor: request.amountMinor,
            category: request.category,
            title: request.title,
            note: request.note,
            transactionDate: request.transactionDate,
            createdAt: now,
            updatedAt: now
        )
        state.withLock { $0[dto.id] = dto }
        return dto
    }

    func updateTransaction(id: UUID, request: UpdateTransactionRequestDTO) async throws -> TransactionDTO {
        if let updateError { throw updateError }
        guard let existing = state.withLock({ $0[id] }) else { throw SingleRowResponseError.notFound }
        let updated = TransactionDTO(
            id: existing.id,
            userID: existing.userID,
            kind: request.kind,
            accountID: request.accountID,
            destinationAccountID: request.destinationAccountID,
            amountMinor: request.amountMinor,
            category: request.category,
            title: request.title,
            note: request.note,
            transactionDate: request.transactionDate,
            createdAt: existing.createdAt,
            updatedAt: Date()
        )
        state.withLock { $0[id] = updated }
        return updated
    }

    func deleteTransaction(id: UUID) async throws -> TransactionDTO {
        if let deleteError { throw deleteError }
        guard let existing = state.withLock({ $0.removeValue(forKey: id) }) else {
            throw SingleRowResponseError.notFound
        }
        return existing
    }
}

final class FakeWalletProfileRemoteDataSource: WalletProfileRemoteDataSource, @unchecked Sendable {
    private let state = OSAllocatedUnfairLock<WalletProfileDTO?>(initialState: nil)
    var fetchError: Error?
    var createError: Error?

    func seed(_ dto: WalletProfileDTO) {
        state.withLock { $0 = dto }
    }

    func fetchProfile(userID: UUID) async throws -> WalletProfileDTO? {
        if let fetchError { throw fetchError }
        return state.withLock { $0 }
    }

    func createProfile(_ request: CreateWalletProfileRequestDTO) async throws -> WalletProfileDTO {
        if let createError { throw createError }
        let now = Date()
        let dto = WalletProfileDTO(
            userID: request.userID,
            baseCurrencyCode: request.baseCurrencyCode,
            createdAt: now,
            updatedAt: now
        )
        state.withLock { $0 = dto }
        return dto
    }
}
