import Foundation

/// Vakit adları uygulama içinde Türkçe kimlik olarak dolaşır (widget ve Live
/// Activity bunlara dayanır); ekranda gösterirken bu yardımcıyla çevrilir.
/// RN: src/i18n/prayers.ts
private let prayerKeys: [String: String] = [
  "İmsak": "imsak", "imsak": "imsak",
  "Sabah": "sabah", "sabah": "sabah", "fajr": "sabah",
  "Güneş": "gunes", "gunes": "gunes",
  "Öğle": "ogle", "ogle": "ogle", "dhuhr": "ogle",
  "İkindi": "ikindi", "ikindi": "ikindi", "asr": "ikindi",
  "Akşam": "aksam", "aksam": "aksam", "maghrib": "aksam",
  "Yatsı": "yatsi", "yatsi": "yatsi", "isha": "yatsi",
]

/// "Öğle" / "dhuhr" / "ogle" → seçili dildeki ad. Bilinmeyen değer olduğu gibi döner.
func prayerLabel(_ nameOrId: String) -> String {
  guard let key = prayerKeys[nameOrId] else { return nameOrId }
  return t("prayers.\(key)")
}
