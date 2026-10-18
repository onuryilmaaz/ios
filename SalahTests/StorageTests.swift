import Foundation
import Testing
@testable import Salah

@MainActor
struct LegacyAsyncStorageTests {
  /// RN AsyncStorage yerleşimi: kısa değer manifest'te, uzun değer MD5 adlı dosyada.
  @Test func readsInlineAndExternalValues() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }

    let storage = LegacyAsyncStorage(directory: dir)
    let long = String(repeating: "x", count: 2000)
    let manifest = #"{"SELECTED_DISTRICT_ID":"9541","@salah_prayer_times_cache_9541":null}"#
    try manifest.write(to: dir.appendingPathComponent("manifest.json"), atomically: true, encoding: .utf8)
    try long.write(to: storage.fileURL(for: "@salah_prayer_times_cache_9541"), atomically: true, encoding: .utf8)

    let entries = storage.allEntries()
    #expect(entries["SELECTED_DISTRICT_ID"] == "9541")
    #expect(entries["@salah_prayer_times_cache_9541"] == long)
  }

  /// Dosya adı RCTMD5Hash ile aynı olmalı (küçük harf hex).
  @Test func fileNameIsLowercaseMD5() {
    let storage = LegacyAsyncStorage(directory: URL(fileURLWithPath: "/tmp"))
    #expect(storage.fileURL(for: "abc").lastPathComponent == "900150983cd24fb0d6963f7d28e17f72")
  }
}

@MainActor
struct GamificationCacheTests {
  /// RN'nin zustand persist biçimi ve metin sayaçlar okunabilmeli.
  @Test func decodesRNPersistedStats() throws {
    let raw = #"{"stats":{"today_prayers":["fajr"],"kaza_prayers":[],"current_streak":"4","highest_streak":9},"statsDate":"2026-10-01"}"#
    struct Wrapper: Decodable { let stats: GamificationStore.Stats }
    let w = try JSONDecoder().decode(Wrapper.self, from: Data(raw.utf8))
    #expect(w.stats.today_prayers == ["fajr"])
    #expect(w.stats.current_streak == 4)
    #expect(w.stats.highest_streak == 9)
  }
}

@MainActor
struct LocalizerTests {
  @Test func interpolatesVariables() {
    #expect(Localizer.shared.t("home.tracker.progress", ["done": 2, "total": 5]).contains("2"))
    #expect(!Localizer.shared.t("home.hero.entry", ["time": "05:12"]).contains("{{"))
  }

  @Test func missingKeyFallsBackToKey() {
    #expect(Localizer.shared.t("does.not.exist") == "does.not.exist")
  }

  @Test func prayerLabelAcceptsAllAliases() {
    #expect(prayerLabel("dhuhr") == prayerLabel("Öğle"))
    #expect(prayerLabel("fajr") == prayerLabel("Sabah"))
  }

  @Test func locationNameUsesTurkishCasing() {
    #expect(Locations.displayName("KOCAELİ") == "Kocaeli")
    #expect(Locations.displayName("IĞDIR") == "Iğdır")
  }
}
