import Foundation
import os
@testable import pocketledger

final class FakeSecureStore: SecureStore, @unchecked Sendable {
    private let storage = OSAllocatedUnfairLock<[SecureKey: Data]>(initialState: [:])

    func data(for key: SecureKey) throws -> Data? {
        storage.withLock { $0[key] }
    }

    func save(_ data: Data, for key: SecureKey) throws {
        storage.withLock { $0[key] = data }
    }

    func delete(_ key: SecureKey) throws {
        storage.withLock { $0[key] = nil }
    }
}
