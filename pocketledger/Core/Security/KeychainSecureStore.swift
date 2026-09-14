import Foundation
import Security

enum KeychainError: Error, Sendable {
    case unexpectedStatus(OSStatus)
    case unexpectedItemFormat
}

/// `SecureStore` backed by Keychain Services.
///
/// The Security framework's `SecItem*` calls are documented as safe to call
/// concurrently, and this type holds no mutable state after `init`, so
/// `@unchecked Sendable` is an honest annotation here rather than a
/// suppressed warning.
final class KeychainSecureStore: SecureStore, @unchecked Sendable {
    private let service: String

    init(service: String = Bundle.main.bundleIdentifier ?? "pocketledger") {
        self.service = service
    }

    func data(for key: SecureKey) throws -> Data? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw KeychainError.unexpectedItemFormat
            }
            return data

        case errSecItemNotFound:
            return nil

        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func save(_ data: Data, for key: SecureKey) throws {
        if try self.data(for: key) != nil {
            let query = baseQuery(for: key)
            let attributes: [String: Any] = [kSecValueData as String: data]
            let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            guard status == errSecSuccess else {
                throw KeychainError.unexpectedStatus(status)
            }
        } else {
            var query = baseQuery(for: key)
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            let status = SecItemAdd(query as CFDictionary, nil)
            guard status == errSecSuccess else {
                throw KeychainError.unexpectedStatus(status)
            }
        }
    }

    func delete(_ key: SecureKey) throws {
        let status = SecItemDelete(baseQuery(for: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private func baseQuery(for key: SecureKey) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
        ]
    }
}
