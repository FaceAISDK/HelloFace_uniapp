import Foundation
import Security

enum HelloFaceVerifyBridgeError: Error {
    case failure(String, String)
}

/** 基准只存本机 Keychain，解锁后可读，不参与 iCloud 同步或设备迁移。 */
enum ReferenceStore {
    private static let service = (Bundle.main.bundleIdentifier ?? "HelloFace") + ".helloface.references.v1"
    private static func query(_ faceID: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: "jdx-feature-v1:" + faceID]
    }
    static func get(_ faceID: String) throws -> String? {
        var attributes = query(faceID)
        attributes[kSecReturnData as String] = true
        attributes[kSecMatchLimit as String] = kSecMatchLimitOne
        var value: CFTypeRef?
        let status = SecItemCopyMatching(attributes as CFDictionary, &value)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = value as? Data,
              let feature = String(data: data, encoding: .utf8) else {
            throw HelloFaceVerifyBridgeError.failure("STORAGE_ERROR", "Unable to read Keychain reference (\(status))")
        }
        return feature
    }
    static func save(_ faceID: String, _ feature: String) throws {
        let data = Data(feature.utf8)
        let attributes: [String: Any] = [kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        var status = SecItemUpdate(query(faceID) as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var item = query(faceID)
            attributes.forEach { item[$0.key] = $0.value }
            status = SecItemAdd(item as CFDictionary, nil)
        }
        guard status == errSecSuccess else {
            throw HelloFaceVerifyBridgeError.failure("STORAGE_ERROR", "Unable to save Keychain reference (\(status))")
        }
    }
    static func delete(_ faceID: String) throws {
        let status = SecItemDelete(query(faceID) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw HelloFaceVerifyBridgeError.failure("STORAGE_ERROR", "Unable to delete Keychain reference (\(status))")
        }
    }
}
