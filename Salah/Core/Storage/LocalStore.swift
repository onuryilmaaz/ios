import Foundation

/// Uygulamanın anahtar/değer deposu.
///
/// Anahtarlar ve değer biçimleri RN'deki AsyncStorage ile AYNIDIR (ör.
/// `SELECTED_DISTRICT_ID`, `@salah_gamification_cache`). İlk açılışta
/// `LegacyMigration` eski RN verisini olduğu gibi buraya kopyalar; böylece
/// ekranlar taşınırken kod iki biçimle uğraşmaz.
enum LocalStore {
  private static let defaults = UserDefaults.standard
  private static let prefix = "rn."

  static func string(_ key: String) -> String? {
    defaults.string(forKey: prefix + key)
  }

  /// `nil` anahtarı siler.
  static func set(_ value: String?, for key: String) {
    if let value {
      defaults.set(value, forKey: prefix + key)
    } else {
      defaults.removeObject(forKey: prefix + key)
    }
  }

  static func remove(_ keys: String...) {
    for key in keys { defaults.removeObject(forKey: prefix + key) }
  }

  static func decode<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
    guard let raw = string(key), let data = raw.data(using: .utf8) else { return nil }
    return try? JSONDecoder().decode(type, from: data)
  }

  static func encode<T: Encodable>(_ value: T, for key: String) {
    guard let data = try? JSONEncoder().encode(value) else { return }
    set(String(data: data, encoding: .utf8), for: key)
  }

  /// Taşıma sırasında toplu yazma.
  @discardableResult
  static func importEntries(_ entries: [String: String], defaults: UserDefaults = .standard) -> Bool {
    for (key, value) in entries where defaults.string(forKey: prefix + key) == nil {
      defaults.set(value, forKey: prefix + key)
    }
    return entries.keys.allSatisfy { defaults.string(forKey: prefix + $0) != nil }
  }
}
