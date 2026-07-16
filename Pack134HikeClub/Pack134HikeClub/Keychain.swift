//
//  Keychain.swift
//  Pack134HikeClub
//
//  Minimal Keychain wrapper for the Hike Club API key (a secret).
//  Device-only (kSecAttrAccessibleWhenUnlockedThisDeviceOnly): never synced to iCloud,
//  never written to a file/git/the app binary.
//

import Foundation
import Security

// ponytail: single generic-password item keyed by account string; generalize only if a
// second secret ever needs storing. Device state, so not unit-tested (like HealthImport's
// HKHealthStore calls) — the value round-trips through the Security framework.
enum Keychain {
    private static let service = "Pack134HikeClub"

    /// Store (or overwrite) a string secret. Passing nil deletes it.
    static func set(_ value: String?, for account: String) {
        delete(account)
        guard let value, let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func get(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
