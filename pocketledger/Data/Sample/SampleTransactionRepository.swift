import Foundation

struct SampleTransactionRepository: TransactionRepository {
    private let store: SampleDataStore

    init(store: SampleDataStore) {
        self.store = store
    }

    func cachedTransactions() async throws -> [Transaction] {
        await store.allTransactions()
    }

    func refreshTransactions() async throws -> [Transaction] {
        await store.allTransactions()
    }

    func createTransaction(_ input: NewTransaction) async throws -> Transaction {
        let now = Date()
        let transaction = Transaction(
            id: input.id,
            kind: input.kind,
            sourceAccountID: input.sourceAccountID,
            destinationAccountID: input.destinationAccountID,
            amount: input.amount,
            category: input.category,
            title: input.title,
            note: input.note,
            date: input.date,
            createdAt: now,
            updatedAt: now
        )
        await store.upsertTransaction(transaction)
        return transaction
    }

    func updateTransaction(id: Transaction.ID, input: NewTransaction) async throws -> Transaction {
        guard let existing = await store.transaction(id: id) else {
            throw RepositoryError.notFound
        }
        let updated = Transaction(
            id: existing.id,
            kind: input.kind,
            sourceAccountID: input.sourceAccountID,
            destinationAccountID: input.destinationAccountID,
            amount: input.amount,
            category: input.category,
            title: input.title,
            note: input.note,
            date: input.date,
            createdAt: existing.createdAt,
            updatedAt: Date()
        )
        await store.upsertTransaction(updated)
        return updated
    }

    func deleteTransaction(id: Transaction.ID) async throws {
        await store.deleteTransaction(id: id)
    }
}
