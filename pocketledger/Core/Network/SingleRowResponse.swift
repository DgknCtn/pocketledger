/// PostgREST mutation/single-row responses come back as a JSON array even
/// when exactly one row is expected. Centralizes the "how many rows did we
/// actually get back" validation described in the API specification.
enum SingleRowResponseError: Error, Sendable, Equatable {
    case notFound
    case unexpectedRowCount(Int)
}

extension Array {
    func singleRow() throws -> Element {
        switch count {
        case 1: return self[0]
        case 0: throw SingleRowResponseError.notFound
        default: throw SingleRowResponseError.unexpectedRowCount(count)
        }
    }
}
