import Foundation
import Security

struct UserSession: Codable, Sendable {
  let token: String
  let username: String
  let name: String
  let avatar: String?
}

struct SessionVault {
  private let service = "zip.tiago.tweeta.session"

  func load(instanceID: UUID) -> UserSession? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: instanceID.uuidString,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var result: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
      let data = result as? Data
    else { return nil }
    return try? JSONDecoder().decode(UserSession.self, from: data)
  }

  func save(_ session: UserSession, instanceID: UUID) throws {
    let data = try JSONEncoder().encode(session)
    let identity: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: instanceID.uuidString,
    ]
    let attributes: [String: Any] = [
      kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]
    let status = SecItemUpdate(identity as CFDictionary, attributes as CFDictionary)
    if status == errSecItemNotFound {
      var insertion = identity
      attributes.forEach { insertion[$0.key] = $0.value }
      guard SecItemAdd(insertion as CFDictionary, nil) == errSecSuccess else {
        throw APIError.message("Tweeta couldn’t securely save this session.")
      }
    } else if status != errSecSuccess {
      throw APIError.message("Tweeta couldn’t securely save this session.")
    }
  }

  func delete(instanceID: UUID) {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: instanceID.uuidString,
    ]
    SecItemDelete(query as CFDictionary)
  }
}
