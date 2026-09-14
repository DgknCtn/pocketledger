import Foundation
import os

struct DefaultTransactionRepository: TransactionRepository {
    private let remoteDataSource: TransactionRemoteDataSource
    private let localStore: TransactionLocalStore
    private let walletProfileLocalStore: WalletProfileLocalStore
    private let sessionManager: SessionManager

    init(
        remoteDataSource: TransactionRemoteDataSource,
        localStore: TransactionLocalStore,
        walletProfileLocalStore: WalletProfileLocalStore,
        sessionManager: SessionManager
    ) {
        self.remoteDataSource = remoteDataSource
        self.localStore = localStore
        self.walletProfileLocalStore = walletProfileLocalStore
        self.sessionManager = sessionManager
    }

    func cachedTransactions() async throws -> [Transaction] {
        let userID = try await sessionManager.currentUserID()
        let currency = try await resolveCurrency(userID: userID)
        do {
            return try await localStore.fetchAll(userID: userID, currency: currency)
        } catch {
            throw RepositoryError.persistenceFailure
        }
    }

    func refreshTransactions() async throws -> [Transaction] {
        let userID = try await sessionManager.currentUserID()
        let currency = try await resolveCurrency(userID: userID)

        let dtos: [TransactionDTO]
        do {
            dtos = try await remoteDataSource.fetchTransactions()
        } catch {
            throw NetworkErrorMapping.repositoryError(for: error)
        }

        let transactions = try map(dtos, currency: currency)

        // As with accounts: only a complete authoritative fetch may
        // reconcile (delete stale rows from) the cache.
        try? await localStore.reconcile(transactions, userID: userID)

        return transactions
    }

    func createTransaction(_ input: NewTransaction) async throws -> Transaction {
        let userID = try await sessionManager.currentUserID()
        let currency = try await resolveCurrency(userID: userID)

        let dto: TransactionDTO
        do {
            dto = try await remoteDataSource.createTransaction(
                CreateTransactionRequestDTO(input: input, userID: userID)
            )
        } catch let networkError as NetworkError {
            if case .api(_, "23505", _) = networkError {
                // Ambiguous create: the response to an earlier attempt with
                // this same client-generated UUID was lost, but the server
                // already accepted it. Reconcile by fetching the canonical
                // record instead of surfacing a failure — see the API
                // specification's "safe retry pattern".
                return try await reconcileAmbiguousCreate(id: input.id, userID: userID, currency: currency)
            }
            throw NetworkErrorMapping.repositoryError(for: networkError)
        } catch {
            throw NetworkErrorMapping.repositoryError(for: error)
        }

        let transaction = try map(dto, currency: currency)
        await cacheAfterRemoteSuccess(transaction, userID: userID)
        return transaction
    }

    func updateTransaction(id: Transaction.ID, input: NewTransaction) async throws -> Transaction {
        let userID = try await sessionManager.currentUserID()
        let currency = try await resolveCurrency(userID: userID)

        let dto: TransactionDTO
        do {
            dto = try await remoteDataSource.updateTransaction(
                id: id,
                request: UpdateTransactionRequestDTO(input: input)
            )
        } catch {
            throw NetworkErrorMapping.repositoryError(for: error)
        }

        let transaction = try map(dto, currency: currency)
        await cacheAfterRemoteSuccess(transaction, userID: userID)
        return transaction
    }

    func deleteTransaction(id: Transaction.ID) async throws {
        do {
            _ = try await remoteDataSource.deleteTransaction(id: id)
        } catch {
            throw NetworkErrorMapping.repositoryError(for: error)
        }

        // As with accounts: the remote delete already succeeded, so a
        // local cache-delete failure just leaves a stale row that the
        // next full refresh reconciles away.
        try? await localStore.delete(id: id)
    }

    // MARK: - Private

    private func reconcileAmbiguousCreate(
        id: UUID,
        userID: UUID,
        currency: CurrencyCode
    ) async throws -> Transaction {
        let dto: TransactionDTO
        do {
            dto = try await remoteDataSource.fetchTransaction(id: id)
        } catch {
            throw NetworkErrorMapping.repositoryError(for: error)
        }

        let transaction = try map(dto, currency: currency)
        await cacheAfterRemoteSuccess(transaction, userID: userID)
        return transaction
    }

    private func cacheAfterRemoteSuccess(_ transaction: Transaction, userID: UUID) async {
        do {
            try await localStore.upsert(transaction, userID: userID)
        } catch {
            AppLogger.persistence.error(
                "Failed to cache transaction \(transaction.id, privacy: .public) after remote success: \(String(describing: error), privacy: .private)"
            )
        }
    }

    private func resolveCurrency(userID: UUID) async throws -> CurrencyCode {
        guard let profile = try? await walletProfileLocalStore.fetch(userID: userID) else {
            throw RepositoryError.walletProfileMissing
        }
        return profile.baseCurrency
    }

    private func map(_ dtos: [TransactionDTO], currency: CurrencyCode) throws -> [Transaction] {
        do {
            return try dtos.map { try TransactionMapper.domain(from: $0, currency: currency) }
        } catch {
            throw RepositoryError.corruptedData
        }
    }

    private func map(_ dto: TransactionDTO, currency: CurrencyCode) throws -> Transaction {
        do {
            return try TransactionMapper.domain(from: dto, currency: currency)
        } catch {
            throw RepositoryError.corruptedData
        }
    }
}
