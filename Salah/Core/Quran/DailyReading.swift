import Foundation

/// Günün okuması: tarih ve dile bağlı SABİT seçim (aynı gün, aynı dil, aynı içerik; rastgele değil).
enum DailyReading {
  static func seed(_ date: String, _ part: String) -> String { "\(date)|\(Localizer.shared.language.rawValue)|\(part)" }

  /// FNV-1a: Swift'in sürece göre değişen hash'i kullanılmaz.
  static func hash(_ seed: String) -> Int {
    var state: UInt64 = 0xcbf2_9ce4_8422_2325
    for byte in seed.utf8 { state = (state ^ UInt64(byte)) &* 0x100_0000_01b3 }
    return Int(state % UInt64(Int32.max))
  }

  static func index(_ count: Int, _ seed: String) -> Int { count > 0 ? hash(seed) % count : 0 }

  /// Günün ayeti: Konular'daki ayetlerden.
  static func verse(date: String) -> TopicRef? {
    let refs = TopicCatalog.refs(for: TopicCatalog.all.map(\.id))
    guard !refs.isEmpty else { return nil }
    return refs[index(refs.count, seed(date, "verse"))]
  }

  static func hadith(date: String) async -> HadithService.Result? {
    let s = seed(date, "hadith")
    return await HadithService.daily { index($0, s) }
  }

  static func dua(date: String) -> Dua? {
    let all = DuaLibrary.allDuas.filter { !$0.arabic.isEmpty }
    return all.isEmpty ? nil : all[index(all.count, seed(date, "dua"))]
  }

  static func esma(date: String) -> EsmaName? {
    let all = EsmaLibrary.names
    return all.isEmpty ? nil : all[index(all.count, seed(date, "esma"))]
  }
}
