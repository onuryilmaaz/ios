import Foundation
import Security

/// Oturum token'larının tek ve şifreli deposu: uygulama ile widget uzantısının
/// paylaştığı Keychain erişim grubu (`<TeamID>.com.onur6541.salah.shared`).
///
/// Önceden token'lar uygulamada AsyncStorage'da, widget için App Group
/// UserDefaults'ta düz metin duruyordu ve iki kopya birbirini ezebiliyordu.
/// Şimdi iki taraf aynı öğeyi okuyup yazar.
///
/// Erişilebilirlik `AfterFirstUnlockThisDeviceOnly`: cihaz açılıştan sonra bir kez
/// kilidi açıldıysa kilitliyken de okunur (arka planda çalışan widget için gerekli),
/// iCloud'a ve yedeklere taşınmaz.
enum SalahKeychain {
  static let accessToken = "access_token"
  static let refreshToken = "refresh_token"
  static let updatedAt = "token_updated_at"

  private static let service = "com.onur6541.salah.auth"

  /// Info.plist'teki `AppIdentifierPrefix` (derlemede "<TeamID>." olur).
  private static var accessGroup: String? {
    guard let prefix = Bundle.main.object(forInfoDictionaryKey: "AppIdentifierPrefix") as? String,
          !prefix.isEmpty, !prefix.hasPrefix("$(") else { return nil }
    return prefix + "com.onur6541.salah.shared"
  }

  private static func query(_ key: String) -> [String: Any] {
    var q: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key,
    ]
    if let group = accessGroup { q[kSecAttrAccessGroup as String] = group }
    return q
  }

  static func get(_ key: String) -> String? {
    var q = query(key)
    q[kSecReturnData as String] = true
    q[kSecMatchLimit as String] = kSecMatchLimitOne
    var out: AnyObject?
    guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
          let data = out as? Data else { return nil }
    return String(data: data, encoding: .utf8)
  }

  /// Boş değer öğeyi siler.
  @discardableResult
  static func set(_ value: String?, for key: String) -> Bool {
    guard let value, !value.isEmpty else { return delete(key) }
    let data = Data(value.utf8)
    let attrs: [String: Any] = [
      kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]
    let status = SecItemUpdate(query(key) as CFDictionary, attrs as CFDictionary)
    if status == errSecItemNotFound {
      var add = query(key)
      add.merge(attrs) { _, new in new }
      return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }
    return status == errSecSuccess
  }

  @discardableResult
  static func delete(_ key: String) -> Bool {
    let status = SecItemDelete(query(key) as CFDictionary)
    return status == errSecSuccess || status == errSecItemNotFound
  }

  static var updatedAtMs: Double { Double(get(updatedAt) ?? "") ?? 0 }

  /// Token'ları yazar. `stampMs`, Keychain'dekinden eskiyse yazma yok sayılır:
  /// bayat bir kopya (örn. widget'ın az önce yenilediği) taze token'ı ezemez.
  @discardableResult
  static func store(access: String?, refresh: String?, stampMs: Double) -> Bool {
    if stampMs < updatedAtMs { return false }
    if let access { set(access, for: accessToken) }
    if let refresh { set(refresh, for: refreshToken) }
    if access != nil || refresh != nil { set(String(stampMs), for: updatedAt) }
    return true
  }

  static func clear() {
    delete(accessToken)
    delete(refreshToken)
    set(String(Date().timeIntervalSince1970 * 1000), for: updatedAt)
  }

  /// Eski sürümlerden kalan, App Group UserDefaults'taki düz metin token'ları
  /// Keychain'e taşır ve siler. Keychain'de daha taze bir kopya varsa onu korur.
  static func migrateFromDefaults(_ ud: UserDefaults?) {
    guard let ud else { return }
    let legacyAccess = ud.string(forKey: "salah_access_token")
    let legacyRefresh = ud.string(forKey: "salah_refresh_token")
    guard legacyAccess != nil || legacyRefresh != nil else { return }
    let legacyStamp = ud.double(forKey: "salah_token_updated_at")
    if get(refreshToken) == nil, let r = legacyRefresh, !r.isEmpty {
      store(access: legacyAccess, refresh: r, stampMs: max(legacyStamp, updatedAtMs))
    }
    ud.removeObject(forKey: "salah_access_token")
    ud.removeObject(forKey: "salah_refresh_token")
    ud.removeObject(forKey: "salah_token_updated_at")
  }
}
