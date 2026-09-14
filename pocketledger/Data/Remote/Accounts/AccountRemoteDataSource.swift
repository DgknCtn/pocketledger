import Foundation

protocol AccountRemoteDataSource: Sendable {
    func fetchAccounts(includeArchived: Bool) async throws -> [AccountDTO]
    func fetchAccount(id: UUID) async throws -> AccountDTO
    func createAccount(_ request: CreateAccountRequestDTO) async throws -> AccountDTO
    func updateAccount(id: UUID, request: UpdateAccountRequestDTO) async throws -> AccountDTO
    func deleteAccount(id: UUID) async throws -> AccountDTO
}

struct DefaultAccountRemoteDataSource: AccountRemoteDataSource {
    private static let selectFields =
        "id,user_id,name,kind,opening_balance_minor,is_archived,archived_at,created_at,updated_at"

    private let networkClient: NetworkClient
    private let encoder: JSONEncoder

    init(networkClient: NetworkClient, encoder: JSONEncoder = APIJSONEncoder.make()) {
        self.networkClient = networkClient
        self.encoder = encoder
    }

    func fetchAccounts(includeArchived: Bool) async throws -> [AccountDTO] {
        var queryItems = [
            URLQueryItem(name: "select", value: Self.selectFields),
            URLQueryItem(name: "order", value: "created_at.asc"),
        ]
        if !includeArchived {
            queryItems.append(URLQueryItem(name: "is_archived", value: "eq.false"))
        }

        let request = APIRequest<[AccountDTO]>(service: .data, path: "accounts", method: .get, queryItems: queryItems)
        return try await networkClient.send(request)
    }

    func fetchAccount(id: UUID) async throws -> AccountDTO {
        let request = APIRequest<[AccountDTO]>(
            service: .data,
            path: "accounts",
            method: .get,
            queryItems: [
                URLQueryItem(name: "select", value: Self.selectFields),
                URLQueryItem(name: "id", value: "eq.\(id.uuidString)"),
                URLQueryItem(name: "limit", value: "1"),
            ]
        )
        return try await networkClient.send(request).singleRow()
    }

    func createAccount(_ requestBody: CreateAccountRequestDTO) async throws -> AccountDTO {
        let body = try encoder.encode(requestBody)
        let request = APIRequest<[AccountDTO]>(
            service: .data,
            path: "accounts",
            method: .post,
            headers: ["Prefer": "return=representation"],
            body: body
        )
        return try await networkClient.send(request).singleRow()
    }

    func updateAccount(id: UUID, request requestBody: UpdateAccountRequestDTO) async throws -> AccountDTO {
        let body = try encoder.encode(requestBody)
        let request = APIRequest<[AccountDTO]>(
            service: .data,
            path: "accounts",
            method: .patch,
            queryItems: [URLQueryItem(name: "id", value: "eq.\(id.uuidString)")],
            headers: ["Prefer": "return=representation"],
            body: body
        )
        return try await networkClient.send(request).singleRow()
    }

    func deleteAccount(id: UUID) async throws -> AccountDTO {
        let request = APIRequest<[AccountDTO]>(
            service: .data,
            path: "accounts",
            method: .delete,
            queryItems: [URLQueryItem(name: "id", value: "eq.\(id.uuidString)")],
            headers: ["Prefer": "return=representation"]
        )
        return try await networkClient.send(request).singleRow()
    }
}
