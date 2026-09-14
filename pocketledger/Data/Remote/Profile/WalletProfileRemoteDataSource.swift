import Foundation

protocol WalletProfileRemoteDataSource: Sendable {
    func fetchProfile(userID: UUID) async throws -> WalletProfileDTO?
    func createProfile(_ request: CreateWalletProfileRequestDTO) async throws -> WalletProfileDTO
}

struct DefaultWalletProfileRemoteDataSource: WalletProfileRemoteDataSource {
    private static let selectFields = "user_id,base_currency_code,created_at,updated_at"

    private let networkClient: NetworkClient

    init(networkClient: NetworkClient) {
        self.networkClient = networkClient
    }

    func fetchProfile(userID: UUID) async throws -> WalletProfileDTO? {
        let request = APIRequest<[WalletProfileDTO]>(
            service: .data,
            path: "wallet_profiles",
            method: .get,
            queryItems: [
                URLQueryItem(name: "select", value: Self.selectFields),
                URLQueryItem(name: "user_id", value: "eq.\(userID.uuidString)"),
                URLQueryItem(name: "limit", value: "1"),
            ]
        )
        // An empty list means "no profile created yet", not a network error.
        return try await networkClient.send(request).first
    }

    func createProfile(_ requestBody: CreateWalletProfileRequestDTO) async throws -> WalletProfileDTO {
        let body = try APIJSONEncoder.make().encode(requestBody)
        let request = APIRequest<[WalletProfileDTO]>(
            service: .data,
            path: "wallet_profiles",
            method: .post,
            headers: ["Prefer": "return=representation"],
            body: body
        )
        return try await networkClient.send(request).singleRow()
    }
}
