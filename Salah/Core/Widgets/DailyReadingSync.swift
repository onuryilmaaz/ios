import Foundation

/// "Günün okuması" widget'ının verisi: uygulamadaki Günün okuması ekranıyla aynı seçim fonksiyonları (`DailyReading`) ve
/// aynı panel atamaları; önümüzdeki 7 gün için esma, ayet (meal dahil) ve dua App Group'a yazılır.
@MainActor
enum DailyReadingContent {
  static let daysAhead = 7

  /// Bir günün içeriği. Ayet alınamazsa (ağ yok, önbellek yok) `verse` anahtarı yazılmaz.
  static func day(_ date: String) async -> [String: Any] {
    var out: [String: Any] = ["date": date]
    let language = Localizer.shared.language.rawValue
    if let esma = DailyReading.esma(date: date) {
      out["esma"] = ["arabic": esma.arabic, "name": esma.name, "meaning": esma.meaning]
    }
    if let panel = AppControlStore.shared.dailyItem(for: date), panel.kind != "hadith" {
      out["verse"] = ["text": AppControlLogic.text(panel.text, language: language), "source": AppControlLogic.text(panel.source, language: language),
                      "arabic": panel.arabic]
    } else if let ref = DailyReading.verse(date: date), let verse = await VerseTextCache.load(ref), !verse.text.isEmpty {
      out["verse"] = ["text": verse.text, "source": verse.source, "arabic": verse.arabic]
    }
    if let dua = DailyReading.dua(date: date) {
      out["dua"] = ["title": dua.title, "text": dua.turkish.isEmpty ? dua.title : dua.turkish]
    }
    return out
  }

  static func days(from start: Date = Date(), count: Int = daysAhead) async -> [[String: Any]] {
    var result: [[String: Any]] = []
    for offset in 0..<count {
      guard let day = Calendar.current.date(byAdding: .day, value: offset, to: start) else { continue }
      result.append(await Self.day(localDateString(day)))
    }
    return result
  }
}

extension WidgetSync {
  /// Açılışta, öne gelişte ve dil değişince.
  static func syncDailyReading() async {
    guard !DebugLaunch.isIsolated else { return }
    WidgetBridge.updateDailyReading(await DailyReadingContent.days())
  }
}
