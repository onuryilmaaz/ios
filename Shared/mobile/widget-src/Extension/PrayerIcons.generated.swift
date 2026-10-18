// BU DOSYA ÜRETİLDİ, elle düzenleme. Kaynak: src/constants/prayerIcons.json
// Yeniden üretmek için: node scripts/gen-prayer-icons.js

/// Vaktin SF Symbol ikonu (anahtar: prayerKeyFromName çıktısı).
func prayerIcon(_ key: String) -> String {
  switch key {
  case "sabah": return "sun.haze.fill"
  case "gunes": return "sunrise.fill"
  case "ogle": return "sun.max.fill"
  case "ikindi": return "sun.min.fill"
  case "aksam": return "sunset.fill"
  case "yatsi": return "moon.stars.fill"
  default: return "clock.fill"
  }
}
