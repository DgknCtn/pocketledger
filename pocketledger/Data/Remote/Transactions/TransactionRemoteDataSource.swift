import Foundation

protocol TransactionRemoteDataSource: Sendable {
    func fetchTransactions() async throws -> [TransactionDTO]
    func fetchTransaction(id: UUID) async throws -> TransactionDTO
    func createTransaction(_ request: CreateTransactionRequestDTO) async throws -> TransactionDTO
    func updateTransaction(id: UUID, request: UpdateTransactionRequestDTO) async throws -> TransactionDTO
    func deleteTransaction(id: UUID) async throws -> TransactionDTO
}

struct DefaultTransactionRemoteDataSource: TransactionRemoteDataSource {
    private static let selectFields =
        "id,user_id,kind,account_id,destination_account_id,amount_minor,category,title,note,transaction_date,created_at,updated_at"

    private let networkClient: NetworkClient
    private let encoder: JSONEncoder

    init(networkClient: NetworkClient, encoder: JSONEncoder = APIJSONEncoder.make()) {
        self.networkClient = networkClient
        self.encoder = encoder
    }

    /// P0's full-dataset refresh (see the API specification): the entire
    /// user's transaction set, not a filtered/paginated query — pagination
    /// and filtered remote queries are intentionally deferred, since only a
    /// *complete* authoritative fetch may be used to reconcile the local
    /// cache (a filtered response must never be treated as authoritative
    /// for deletion purposes).
    func fetchTransactions() async throws -> [TransactionDTO] {
        let request = APIRequest<[TransactionDTO]>(
            service: .data,
            path: "transactions",
            method: .get,
            queryItems: [
                URLQueryItem(name: "select", value: Self.selectFields),
                URLQueryItem(name: "order", value: "transaction_date.desc,created_at.desc"),
            ]
        )
        return try await networkClient.send(request)
    }

    func fetchTransaction(id: UUID) async throws -> TransactionDTO {
        let request = APIRequest<[TransactionDTO]>(
            service: .data,
            path: "transactions",
            method: .get,
            queryItems: [
                URLQueryItem(name: "select", value: Self.selectFields),
                URLQueryItem(name: "id", value: "eq.\(id.uuidString)"),
                URLQueryItem(name: "limit", value: "1"),
            ]
        )
        return try await networkClient.send(request).singleRow()
    }

    func createTransaction(_ requestBody: CreateTransactionRequestDTO) async throws -> TransactionDTO {
        let body = try encoder.encode(requestBody)
        let request = APIRequest<[TransactionDTO]>(
            service: .data,
            path: "transactions",
            method: .post,
            headers: ["Prefer": "return=representation"],
            body: body
        )
        return try await networkClient.send(request).singleRow()
    }

    func updateTransaction(id: UUID, request requestBody: UpdateTransactionRequestDTO) async throws -> TransactionDTO {
        let body = try encoder.encode(requestBody)
        let request = APIRequest<[TransactionDTO]>(
            service: .data,
            path: "transactions",
            method: .patch,
            queryItems: [URLQueryItem(name: "id", value: "eq.\(id.uuidString)")],
            headers: ["Prefer": "return=representation"],
            body: body
        )
        return try await networkClient.send(request).singleRow()
    }

    func deleteTransaction(id: UUID) async throws -> TransactionDTO {
        let request = APIRequest<[TransactionDTO]>(
            service: .data,
            path: "transactions",
            method: .delete,
            queryItems: [URLQueryItem(name: "id", value: "eq.\(id.uuidString)")],
            headers: ["Prefer": "return=representation"]
        )
        return try await networkClient.send(request).singleRow()
    }
}
