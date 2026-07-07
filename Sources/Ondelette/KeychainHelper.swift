import Foundation
import Security

enum KeychainHelper {
    private static let service = "com.charles.ondelette"
    /// Ancien service (l'app s'appelait Parler) : lu en repli puis migré.
    private static let legacyService = "com.charles.parler"
    private static let account = "openai_api_key"

    static func saveAPIKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        delete(service: service)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func loadAPIKey() -> String? {
        if let key = load(service: service) {
            return key
        }
        // Migration depuis l'identité « Parler ».
        if let legacy = load(service: legacyService) {
            saveAPIKey(legacy)
            delete(service: legacyService)
            return legacy
        }
        return nil
    }

    static func deleteAPIKey() {
        delete(service: service)
    }

    private static func load(service: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func delete(service: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
