import Foundation

/// Oturum token'ları. Depo, RN sürümü ve widget ile ORTAK Keychain öğesidir
/// (`SalahKeychain`, mobile/widget-src); güncellemeden sonra oturum aynen sürer.
/// Kurallar RN'deki services/token.service.ts ile aynı:
/// - Damga (`token_updated_at`) yalnız refresh token DEĞİŞTİĞİNDE ilerler.
/// - Bayat damgalı yazma yok sayılır (widget'ın taze token'ını ezmez).
enum TokenStore {
  static var accessToken: String? { credentials().access }
  static var refreshToken: String? { credentials().refresh }

  /// Eski RN sürümlerinde token AsyncStorage/App Group'ta kalmış olabilir.
  /// Keychain hatasında kaynak korunur ve aynı erişim eski değere düşer.
  private static func credentials() -> LegacyTokenMigration.Credentials {
    let current = readSecure()
    guard !DebugLaunch.isIsolated else { return current }
    let group = UserDefaults(suiteName: WidgetBridge.appGroupID)
    let sources = [
      LegacyTokenMigration.Credentials(access: LocalStore.string("access_token"), refresh: LocalStore.string("refresh_token"),
        stamp: Double(LocalStore.string("refresh_token_changed_at") ?? "") ?? 0),
      LegacyTokenMigration.Credentials(access: group?.string(forKey: "salah_access_token"), refresh: group?.string(forKey: "salah_refresh_token"),
        stamp: group?.double(forKey: "salah_token_updated_at") ?? 0),
    ]
    let result = LegacyTokenMigration.restore(sources: sources, current: current) { value in
      SalahKeychain.store(access: value.access ?? "", refresh: value.refresh ?? "", stampMs: value.stamp)
      return readSecure()
    }
    if result.removableSources.contains(0) { LocalStore.remove("access_token", "refresh_token", "refresh_token_changed_at") }
    if result.removableSources.contains(1) {
      for key in ["salah_access_token", "salah_refresh_token", "salah_token_updated_at"] { group?.removeObject(forKey: key) }
    }
    return result.credentials
  }

  private static func readSecure() -> LegacyTokenMigration.Credentials {
    .init(access: SalahKeychain.get(SalahKeychain.accessToken), refresh: SalahKeychain.get(SalahKeychain.refreshToken), stamp: SalahKeychain.updatedAtMs)
  }

  static func setAccessToken(_ token: String) {
    SalahKeychain.store(access: token, refresh: nil, stampMs: SalahKeychain.updatedAtMs)
  }

  static func removeAccessToken() {
    SalahKeychain.store(access: "", refresh: nil, stampMs: SalahKeychain.updatedAtMs)
  }

  static func setRefreshToken(_ token: String) {
    guard refreshToken != token else { return }
    SalahKeychain.store(access: nil, refresh: token, stampMs: nowMs)
  }

  /// Dışarıdan gelen (ör. widget'ın yenilediği) token çifti.
  static func adopt(access: String, refresh: String) {
    // Çift tek yazma adımında: taşıma erişim ile refresh arasına giremez.
    // RN kuralı: refresh değişmediyse damga ilerletilmez.
    let current = credentials()
    SalahKeychain.store(access: access, refresh: refresh,
      stampMs: current.refresh == refresh ? SalahKeychain.updatedAtMs : nowMs)
  }

  static func clear() {
    SalahKeychain.clear()
    LocalStore.remove(storedUserKey, "access_token", "refresh_token", "refresh_token_changed_at")
    if !DebugLaunch.isIsolated, let group = UserDefaults(suiteName: WidgetBridge.appGroupID) {
      for key in ["salah_access_token", "salah_refresh_token", "salah_token_updated_at"] { group.removeObject(forKey: key) }
    }
  }

  /// Son başarılı profil yanıtı: internetsiz açılışta oturumu sunucuya gitmeden açmak için.
  static let storedUserKey = "auth_user"

  private static var nowMs: Double { Date().timeIntervalSince1970 * 1000 }

}
