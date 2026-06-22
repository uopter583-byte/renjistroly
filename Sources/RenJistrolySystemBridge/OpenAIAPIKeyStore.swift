import Foundation
import Security

public enum OpenAIAPIKeyStore {
    /// Keychain service name. Changed from "MacVoiceAssistant" (legacy project name) to "RenJistroly".
    /// Users who previously saved their key under the old service name will need to re-save.
    private static let service = "RenJistroly"
    public static let defaultAccount = "OPENAI_API_KEY"

    public static func load(account: String = Self.defaultAccount) -> String? {
        if let envKey = ProcessInfo.processInfo.environment[account], !envKey.isEmpty {
            return envKey
        }

        var item: CFTypeRef?
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let key = String(data: data, encoding: .utf8),
              !key.isEmpty
        else {
            return nil
        }
        return key
    }

    public static func save(_ key: String, account: String = Self.defaultAccount) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        if trimmed.isEmpty {
            SecItemDelete(query as CFDictionary)
            return
        }

        let data = Data(trimmed.utf8)
        let attributes: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeyStoreError.saveFailed(addStatus)
        }
    }
}

public enum KeyStoreError: Error, Sendable {
    case saveFailed(OSStatus)
}
