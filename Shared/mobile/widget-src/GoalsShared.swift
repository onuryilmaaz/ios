import Foundation

/// "Hedeflerim" widget'ının verisi: kaza borcu, bugünkü ezber tekrarı ve teheccüd. Uygulama (`GoalsWidgetSync`) yazar,
/// widget (`GoalsWidget`) okur; App Group `salah_goals_widget`. Android `GoalsWidget` aynı alanlar.
nonisolated enum GoalsShared {
  static let suite = "group.com.onur6541.salah.shared"
  static let key = "salah_goals_widget"

  struct Snapshot: Codable, Equatable, Sendable {
    /// Kaza borcu toplamı; kaza kullanılamıyorsa (giriş yok, kapalı) nil.
    var kaza: Int?
    /// Bugün tekrar zamanı gelen ezber ayeti ve toplam ezber.
    var hifzDue = 0
    var hifzTotal = 0
    /// Teheccüd: bugün (gece) kaydedildi mi, bu ay kaç gece. Giriş yoksa nil.
    var teheccudToday: Bool?
    var teheccudMonth = 0
    /// Verinin yazıldığı gün ("yyyy-MM-dd"): ertesi gün bugüne ait alanlar sıfır sayılır.
    var day = ""
  }

  static func load() -> Snapshot? {
    guard let data = UserDefaults(suiteName: suite)?.data(forKey: key) else { return nil }
    return try? JSONDecoder().decode(Snapshot.self, from: data)
  }

  static func save(_ snapshot: Snapshot) {
    guard let data = try? JSONEncoder().encode(snapshot) else { return }
    UserDefaults(suiteName: suite)?.set(data, forKey: key)
  }

  static func ymd(_ date: Date) -> String {
    let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
  }

  /// Gün değiştiyse bugüne ait alanlar (teheccüd işareti) sıfırlanmış kopya; ezber tekrarı gün dönünce artabileceğinden
  /// uygulama bir sonraki açılışta günceller.
  static func current(_ snapshot: Snapshot, now: Date) -> Snapshot {
    guard snapshot.day != ymd(now) else { return snapshot }
    var copy = snapshot
    if copy.teheccudToday != nil { copy.teheccudToday = false }
    return copy
  }
}
