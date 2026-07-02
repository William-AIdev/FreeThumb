import Combine
import Foundation
import Security

@MainActor
final class WebhookSecretModel: ObservableObject {
  @Published var url: String {
    didSet {
      KeychainSecretStore.save(url, account: "alertsWebhookURL")
    }
  }

  init() {
    url = KeychainSecretStore.load(account: "alertsWebhookURL")
  }
}

enum KeychainSecretStore {
  private static let service = "com.freethumb.app"

  static func load(account: String) -> String {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]

    var result: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
      let data = result as? Data
    else {
      return ""
    }
    return String(decoding: data, as: UTF8.self)
  }

  static func save(_ value: String, account: String) {
    let identity: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]

    if value.isEmpty {
      SecItemDelete(identity as CFDictionary)
      return
    }

    let data = Data(value.utf8)
    let attributes = [kSecValueData as String: data]
    if SecItemUpdate(identity as CFDictionary, attributes as CFDictionary) == errSecItemNotFound {
      var item = identity
      item[kSecValueData as String] = data
      SecItemAdd(item as CFDictionary, nil)
    }
  }
}
