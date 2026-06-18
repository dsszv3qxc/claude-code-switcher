import Foundation
import Security
import ClaudeCodeSwitcherCore

struct KeychainStore: Sendable {
    private let service = "ClaudeCodeSwitcher"
    private let account = "DeepSeekAPIKey"

    func readAPIKey() throws -> String? {
        try readAPIKey(account: account)
    }

    func readAPIKey(for profile: BackendProfile) throws -> String? {
        try readAPIKey(account: accountName(for: profile))
    }

    func saveAPIKey(_ apiKey: String) throws {
        try saveAPIKey(apiKey, account: account)
    }

    func saveAPIKey(_ apiKey: String, for profile: BackendProfile) throws {
        try saveAPIKey(apiKey, account: accountName(for: profile))
    }

    private func readAPIKey(account: String) throws -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw SwitcherError.keychainReadFailed(status)
        }

        guard let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    private func saveAPIKey(_ apiKey: String, account: String) throws {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let data = Data(trimmed.utf8)
        let query = baseQuery(account: account)
        let update = [kSecValueData as String: data]

        let updateStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }

        guard updateStatus == errSecItemNotFound else {
            throw SwitcherError.keychainSaveFailed(updateStatus)
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw SwitcherError.keychainSaveFailed(addStatus)
        }
    }

    private func accountName(for profile: BackendProfile) -> String {
        if profile.id == BackendProfile.deepSeekPro.id || profile.id == BackendProfile.deepSeekFlash.id {
            return account
        }
        return "BackendAPIKey.\(profile.id)"
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
