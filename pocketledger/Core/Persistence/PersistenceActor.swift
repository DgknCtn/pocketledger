import Foundation
import SwiftData

/// The only place `ModelContext` is touched. `@ModelActor` serializes every
/// call onto one isolated executor, and every method here returns plain
/// Domain value types — never an `@Model` record — because SwiftData model
/// objects are tied to their originating context/actor and must not cross
/// an actor boundary (see the Architecture specification).
@ModelActor
actor PersistenceActor {

    // MARK: - Wallet profile

    func fetchWalletProfile(userID: UUID) throws -> WalletProfile? {
        var descriptor = FetchDescriptor<WalletProfileRecord>(
            predicate: #Predicate { $0.userID == userID }
        )
        descriptor.fetchLimit = 1
        guard let record = try modelContext.fetch(descriptor).first else { return nil }
        return try record.toDomain()
    }

    func upsertWalletProfile(_ profile: WalletProfile, userID: UUID, now: Date = Date()) throws {
        var descriptor = FetchDescriptor<WalletProfileRecord>(
            predicate: #Predicate { $0.userID == userID }
        )
        descriptor.fetchLimit = 1

        if let existing = try modelContext.fetch(descriptor).first {
            existing.update(from: profile, updatedAt: now)
        } else {
            modelContext.insert(
                WalletProfileRecord(
                    userID: userID,
                    baseCurrencyCode: profile.baseCurrency.rawValue,
                    createdAt: now,
                    updatedAt: now
                )
            )
        }
        try save()
    }

    // MARK: - Accounts

    func fetchAccounts(userID: UUID, currency: CurrencyCode) throws -> [Account] {
        let descriptor = FetchDescriptor<AccountRecord>(
            predicate: #Predicate { $0.userID == userID },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return try modelContext.fetch(descriptor).map { try $0.toDomain(currency: currency) }
    }

    func upsertAccount(_ account: Account, userID: UUID) throws {
        let accountID = account.id
        var descriptor = FetchDescriptor<AccountRecord>(predicate: #Predicate { $0.id == accountID })
        descriptor.fetchLimit = 1

        if let existing = try modelContext.fetch(descriptor).first {
            existing.update(from: account)
        } else {
            modelContext.insert(AccountRecord(account: account, userID: userID))
        }
        try save()
    }

    func deleteAccount(id: UUID) throws {
        var descriptor = FetchDescriptor<AccountRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let record = try modelContext.fetch(descriptor).first else { return }
        modelContext.delete(record)
        try save()
    }

    /// Upserts every account in `accounts`, then deletes any cached row for
    /// `userID` whose id is absent from `accounts` — this is only valid
    /// after a *complete* authoritative fetch (never after a filtered
    /// remote query), otherwise unrelated cached rows would be wrongly
    /// deleted.
    func reconcileAccounts(_ accounts: [Account], userID: UUID) throws {
        let descriptor = FetchDescriptor<AccountRecord>(predicate: #Predicate { $0.userID == userID })
        var remainingExisting = Dictionary(
            uniqueKeysWithValues: try modelContext.fetch(descriptor).map { ($0.id, $0) }
        )

        for account in accounts {
            if let existing = remainingExisting.removeValue(forKey: account.id) {
                existing.update(from: account)
            } else {
                modelContext.insert(AccountRecord(account: account, userID: userID))
            }
        }

        for staleRecord in remainingExisting.values {
            modelContext.delete(staleRecord)
        }

        try save()
    }

    // MARK: - Transactions

    func fetchTransactions(userID: UUID, currency: CurrencyCode) throws -> [Transaction] {
        let descriptor = FetchDescriptor<TransactionRecord>(
            predicate: #Predicate { $0.userID == userID },
            sortBy: [
                SortDescriptor(\.transactionDateKey, order: .reverse),
                SortDescriptor(\.createdAt, order: .reverse),
            ]
        )
        return try modelContext.fetch(descriptor).map { try $0.toDomain(currency: currency) }
    }

    func upsertTransaction(_ transaction: Transaction, userID: UUID) throws {
        let transactionID = transaction.id
        var descriptor = FetchDescriptor<TransactionRecord>(predicate: #Predicate { $0.id == transactionID })
        descriptor.fetchLimit = 1

        if let existing = try modelContext.fetch(descriptor).first {
            existing.update(from: transaction)
        } else {
            modelContext.insert(TransactionRecord(transaction: transaction, userID: userID))
        }
        try save()
    }

    func deleteTransaction(id: UUID) throws {
        var descriptor = FetchDescriptor<TransactionRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let record = try modelContext.fetch(descriptor).first else { return }
        modelContext.delete(record)
        try save()
    }

    func reconcileTransactions(_ transactions: [Transaction], userID: UUID) throws {
        let descriptor = FetchDescriptor<TransactionRecord>(predicate: #Predicate { $0.userID == userID })
        var remainingExisting = Dictionary(
            uniqueKeysWithValues: try modelContext.fetch(descriptor).map { ($0.id, $0) }
        )

        for transaction in transactions {
            if let existing = remainingExisting.removeValue(forKey: transaction.id) {
                existing.update(from: transaction)
            } else {
                modelContext.insert(TransactionRecord(transaction: transaction, userID: userID))
            }
        }

        for staleRecord in remainingExisting.values {
            modelContext.delete(staleRecord)
        }

        try save()
    }

    // MARK: - Cache metadata

    func lastSuccessfulSync(userID: UUID, resource: CacheMetadataRecord.Resource) throws -> Date? {
        let key = CacheMetadataRecord.key(userID: userID, resourceRawValue: resource.rawValue)
        var descriptor = FetchDescriptor<CacheMetadataRecord>(predicate: #Predicate { $0.key == key })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.lastSuccessfulSyncAt
    }

    func markSynced(userID: UUID, resource: CacheMetadataRecord.Resource, at date: Date = Date()) throws {
        let key = CacheMetadataRecord.key(userID: userID, resourceRawValue: resource.rawValue)
        var descriptor = FetchDescriptor<CacheMetadataRecord>(predicate: #Predicate { $0.key == key })
        descriptor.fetchLimit = 1

        if let existing = try modelContext.fetch(descriptor).first {
            existing.lastSuccessfulSyncAt = date
        } else {
            modelContext.insert(
                CacheMetadataRecord(userID: userID, resourceRawValue: resource.rawValue, lastSuccessfulSyncAt: date)
            )
        }
        try save()
    }

    // MARK: - User isolation

    /// Clears every cached row for `userID` — used when the signed-in
    /// remote identity changes, so a new anonymous session never renders a
    /// previous user's cached financial data (see the database
    /// specification's "session identity mismatch" policy).
    func clearAllData(userID: UUID) throws {
        let walletDescriptor = FetchDescriptor<WalletProfileRecord>(predicate: #Predicate { $0.userID == userID })
        for record in try modelContext.fetch(walletDescriptor) { modelContext.delete(record) }

        let accountDescriptor = FetchDescriptor<AccountRecord>(predicate: #Predicate { $0.userID == userID })
        for record in try modelContext.fetch(accountDescriptor) { modelContext.delete(record) }

        let transactionDescriptor = FetchDescriptor<TransactionRecord>(predicate: #Predicate { $0.userID == userID })
        for record in try modelContext.fetch(transactionDescriptor) { modelContext.delete(record) }

        let metadataDescriptor = FetchDescriptor<CacheMetadataRecord>(predicate: #Predicate { $0.userID == userID })
        for record in try modelContext.fetch(metadataDescriptor) { modelContext.delete(record) }

        try save()
    }

    // MARK: - Private

    private func save() throws {
        do {
            try modelContext.save()
        } catch {
            throw PersistenceError.saveFailed
        }
    }
}
