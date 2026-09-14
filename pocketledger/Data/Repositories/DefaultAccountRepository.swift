import Foundation
import os

struct DefaultAccountRepository: AccountRepository {
    private let remoteDataSource: AccountRemoteDataSource
    private let localStore: AccountLocalStore
    private let walletProfileLocalStore: WalletProfileLocalStore
    private let sessionManager: SessionManager

    init(
        remoteDataSource: AccountRemoteDataSource,
        localStore: AccountLocalStore,
        walletProfileLocalStore: WalletProfileLocalStore,
        sessionManager: SessionManager
    ) {
        self.remoteDataSource = remoteDataSource
        self.localStore = localStore
        self.walletProfileLocalStore = walletProfileLocalStore
        self.sessionManager = sessionManager
    }

    func cachedAccounts() async throws -> [Account] {
        let userID = try await sessionManager.currentUserID()
        let currency = try await resolveCurrency(userID: userID)
        do {
            return try await localStore.fetchAll(userID: userID, currency: currency)
        } catch {
            throw RepositoryError.persistenceFailure
        }
    }

    func refreshAccounts() async throws -> [Account] {
        let userID = try await sessionManager.currentUserID()
        let currency = try await resolveCurrency(userID: userID)

        let dtos: [AccountDTO]
        do {
            dtos = try await remoteDataSource.fetchAccounts(includeArchived: true)
        } catch {
            throw NetworkErrorMapping.repositoryError(for: error)
        }

        let accounts = try map(dtos, currency: currency)

        // Only a *complete* authoritative fetch may reconcile (delete
        // stale) the cache — never a filtered query. A cache-write failure
        // here is not surfaced: the freshly-fetched `accounts` are still
        // returned to the caller, and the cache is simply stale until the
        // next successful refresh.
        try? await localStore.reconcile(accounts, userID: userID)

        return accounts
    }

    func createAccount(_ input: CreateAccountInput) async throws -> Account {
        let userID = try await sessionManager.currentUserID()
        let currency = try await resolveCurrency(userID: userID)

        let dto: AccountDTO
        do {
            dto = try await remoteDataSource.createAccount(CreateAccountRequestDTO(input: input, userID: userID))
        } catch {
            throw NetworkErrorMapping.repositoryError(for: error)
        }

        let account = try map(dto, currency: currency)
        await cacheAfterRemoteSuccess(account, userID: userID)
        return account
    }

    func updateAccount(_ input: UpdateAccountInput) async throws -> Account {
        let userID = try await sessionManager.currentUserID()
        let currency = try await resolveCurrency(userID: userID)

        // Fetches the server's current row first (rather than trusting a
        // possibly-stale local cache) so archive state is preserved
        // exactly, even if this device has never refreshed since the
        // account was archived elsewhere.
        let current = try await fetchRemoteAccount(id: input.id)
        let requestBody = UpdateAccountRequestDTO(
            input: input,
            isArchived: current.isArchived,
            archivedAt: current.archivedAt
        )

        let dto: AccountDTO
        do {
            dto = try await remoteDataSource.updateAccount(id: input.id, request: requestBody)
        } catch {
            throw NetworkErrorMapping.repositoryError(for: error)
        }

        let account = try map(dto, currency: currency)
        await cacheAfterRemoteSuccess(account, userID: userID)
        return account
    }

    func archiveAccount(id: Account.ID) async throws -> Account {
        let userID = try await sessionManager.currentUserID()
        let currency = try await resolveCurrency(userID: userID)

        let current = try await fetchRemoteAccount(id: id)
        let requestBody = UpdateAccountRequestDTO(
            name: current.name,
            openingBalanceMinor: current.openingBalanceMinor,
            isArchived: true,
            archivedAt: Date()
        )

        let dto: AccountDTO
        do {
            dto = try await remoteDataSource.updateAccount(id: id, request: requestBody)
        } catch {
            throw NetworkErrorMapping.repositoryError(for: error)
        }

        let account = try map(dto, currency: currency)
        await cacheAfterRemoteSuccess(account, userID: userID)
        return account
    }

    func deleteAccount(id: Account.ID) async throws {
        do {
            _ = try await remoteDataSource.deleteAccount(id: id)
        } catch let networkError as NetworkError {
            if case .api(_, "23503", _) = networkError {
                throw RepositoryError.accountHasTransactions
            }
            throw NetworkErrorMapping.repositoryError(for: networkError)
        } catch {
            throw NetworkErrorMapping.repositoryError(for: error)
        }

        // Remote delete succeeded; a local cache-delete failure just means
        // the row goes stale until the next refresh reconciles it away.
        try? await localStore.delete(id: id)
    }

    // MARK: - Private

    private func fetchRemoteAccount(id: UUID) async throws -> AccountDTO {
        do {
            return try await remoteDataSource.fetchAccount(id: id)
        } catch {
            throw NetworkErrorMapping.repositoryError(for: error)
        }
    }

    private func cacheAfterRemoteSuccess(_ account: Account, userID: UUID) async {
        do {
            try await localStore.upsert(account, userID: userID)
        } catch {
            // The remote write already succeeded and is canonical — this
            // is logged, not retried (retrying the POST/PATCH here could
            // duplicate it), and not thrown to the caller.
            AppLogger.persistence.error(
                "Failed to cache account \(account.id, privacy: .public) after remote success: \(String(describing: error), privacy: .private)"
            )
        }
    }

    private func resolveCurrency(userID: UUID) async throws -> CurrencyCode {
        guard let profile = try? await walletProfileLocalStore.fetch(userID: userID) else {
            throw RepositoryError.walletProfileMissing
        }
        return profile.baseCurrency
    }

    private func map(_ dtos: [AccountDTO], currency: CurrencyCode) throws -> [Account] {
        do {
            return try dtos.map { try AccountMapper.domain(from: $0, currency: currency) }
        } catch {
            throw RepositoryError.corruptedData
        }
    }

    private func map(_ dto: AccountDTO, currency: CurrencyCode) throws -> Account {
        do {
            return try AccountMapper.domain(from: dto, currency: currency)
        } catch {
            throw RepositoryError.corruptedData
        }
    }
}
