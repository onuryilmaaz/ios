import FamilyControls
import Foundation
import ManagedSettings

/// Vakit kilidi: uygulama, izleme uzantısı (DeviceActivityMonitor) ve kilit ekranı uzantısı (ShieldConfiguration)
/// aynı dosyayı derler. Durum App Group'ta. Kilit, vakit girince seçilen uygulamalara konur; namaz uygulamada
/// "kıldım" olarak işaretlenince ya da süre dolunca kalkar.
/// Yalnız `SALAH_PRAYER_LOCK=YES xcodegen generate` ile projeye girer (Apple dağıtım onayı bekleniyor).
nonisolated enum PrayerLockShared {
  static let suite = "group.com.onur6541.salah.shared"
  private static let selectionKey = "salah_prayer_lock_selection"
  private static let settingsKey = "salah_prayer_lock_settings"
  private static let currentKey = "salah_prayer_lock_current"
  static var storeName: ManagedSettingsStore.Name { ManagedSettingsStore.Name("salah.prayerLock") }
  /// Etkinlik adı: "prayer.<id>.<yyyy-MM-dd>" (id: fajr, dhuhr, asr, maghrib, isha; gün: namaz günü).
  static let activityPrefix = "prayer."

  struct Settings: Codable, Equatable, Sendable {
    var enabled = false
    /// Kilit en fazla bu kadar sürer (vakit girdikten sonra).
    var minutes = 30
    /// Kilitlenecek vakitler.
    var prayers = ["fajr", "dhuhr", "asr", "maghrib", "isha"]
  }

  private static var defaults: UserDefaults? { UserDefaults(suiteName: suite) }

  static func settings() -> Settings {
    guard let data = defaults?.data(forKey: settingsKey), let s = try? JSONDecoder().decode(Settings.self, from: data) else { return Settings() }
    return s
  }

  static func save(_ settings: Settings) {
    defaults?.set(try? JSONEncoder().encode(settings), forKey: settingsKey)
  }

  static func selection() -> FamilyActivitySelection {
    guard let data = defaults?.data(forKey: selectionKey), let s = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
      return FamilyActivitySelection()
    }
    return s
  }

  static func save(_ selection: FamilyActivitySelection) {
    defaults?.set(try? JSONEncoder().encode(selection), forKey: selectionKey)
  }

  static func hasSelection(_ s: FamilyActivitySelection) -> Bool {
    !s.applicationTokens.isEmpty || !s.categoryTokens.isEmpty || !s.webDomainTokens.isEmpty
  }

  static func activityName(prayer: String, day: String) -> String { "\(activityPrefix)\(prayer).\(day)" }

  /// "prayer.dhuhr.2026-11-14" → ("dhuhr", "2026-11-14").
  static func parse(_ name: String) -> (prayer: String, day: String)? {
    guard name.hasPrefix(activityPrefix) else { return nil }
    let parts = name.dropFirst(activityPrefix.count).split(separator: ".", maxSplits: 1).map(String.init)
    guard parts.count == 2 else { return nil }
    return (parts[0], parts[1])
  }

  /// Uygulamanın widget'lar için yazdığı takip verisinden: o gün o vakit kılındı mı.
  static func isPrayed(_ prayer: String, day: String) -> Bool {
    for key in ["salah_tracker_data", "salah_tracker_data_prev"] {
      guard let data = defaults?.data(forKey: key),
        let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        obj["date"] as? String == day
      else { continue }
      return (obj["completedPrayers"] as? [String] ?? []).contains(prayer)
    }
    return false
  }

  /// Kilitteki vakit (kilit ekranı metni için).
  static var currentPrayer: String? { defaults?.string(forKey: currentKey) }

  static func lock(prayer: String) {
    let s = selection()
    guard hasSelection(s) else { return }
    let store = ManagedSettingsStore(named: storeName)
    store.shield.applications = s.applicationTokens.isEmpty ? nil : s.applicationTokens
    store.shield.applicationCategories = s.categoryTokens.isEmpty ? nil : .specific(s.categoryTokens)
    store.shield.webDomains = s.webDomainTokens.isEmpty ? nil : s.webDomainTokens
    defaults?.set(prayer, forKey: currentKey)
  }

  static func unlock() {
    ManagedSettingsStore(named: storeName).clearAllSettings()
    defaults?.removeObject(forKey: currentKey)
  }
}
