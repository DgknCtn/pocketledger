import Foundation

struct DefaultWalletProfileRepository: WalletProfileRepository {
    private let remoteDataSource: WalletProfileRemoteDataSource
    private let localStore: WalletProfileLocalStore
    private let sessionManager: SessionManager

    init(
        remoteDataSource: WalletProfileRemoteDataSource,
        localStore: WalletProfileLocalStore,
        sessionManager: SessionManager
    ) {
        self.remoteDataSource = remoteDataSource
        self.localStore = localStore
        self.sessionManager = sessionManager
    }

    func cachedProfile() async throws -> WalletProfile? {
        let userID = try await sessionManager.currentUserID()
        do {
            return try await localStore.fetch(userID: userID)
        } catch {
            throw RepositoryError.persistenceFailure
        }
    }

    func refreshProfile() async throws -> WalletProfile? {
        let userID = try await sessionManager.currentUserID()

        let dto: WalletProfileDTO?
        do {
            dto = try await remoteDataSource.fetchProfile(userID: userID)
        } catch {
            throw NetworkErrorMapping.repositoryError(for: error)
        }

        guard let dto else { return nil }

        let profile = try map(dto)
        try? await localStore.upsert(profile, userID: userID)
        return profile
    }

    func createProfile(baseCurrency: CurrencyCode) async throws -> WalletProfile {
        let userID = try await sessionManager.currentUserID()

        let dto: WalletProfileDTO
        do {
            dto = try await remoteDataSource.createProfile(
                CreateWalletProfileRequestDTO(userID: userID, baseCurrencyCode: baseCurrency.rawValue)
            )
        } catch {
            throw NetworkErrorMapping.repositoryError(for: error)
        }

        let profile = try map(dto)
        try? await localStore.upsert(profile, userID: userID)
        return profile
    }

    private func map(_ dto: WalletProfileDTO) throws -> WalletProfile {
        guard let currency = CurrencyCode(rawValue: dto.baseCurrencyCode) else {
            throw RepositoryError.corruptedData
        }
        return WalletProfile(baseCurrency: currency)
    }
}
