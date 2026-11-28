import Foundation
import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Kilitli uygulama açılınca görünen ekran: hangi vaktin kılınacağı ve kilidin nasıl kalkacağı.
final class PrayerLockShield: ShieldConfigurationDataSource {
  override func configuration(shielding application: Application) -> ShieldConfiguration { make() }
  override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration { make() }
  override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration { make() }
  override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration { make() }

  private func make() -> ShieldConfiguration {
    let defaults = UserDefaults(suiteName: PrayerLockShared.suite)
    let lang = defaults?.string(forKey: "appLanguage") ?? "tr"
    let texts = Self.texts[lang] ?? Self.texts["tr"]!
    let prayer = PrayerLockShared.currentPrayer.flatMap { Self.names[$0].map { $0[lang] ?? $0["tr"] ?? "" } }
    let format = PrayerLockShared.settings().mode == .end ? texts.endFormat : texts.titleFormat
    // Uygulama rengi (accent-900, açılış ekranıyla aynı ton) ve altın vurgu (gold-300).
    let hero = Self.color(Self.heroRGB(defaults))
    let gold = Self.color(0xE6BD62)
    return ShieldConfiguration(
      // Bulanıklık rengi griye çekiyordu: düz zemin.
      backgroundBlurStyle: nil,
      backgroundColor: hero,
      icon: Self.logo(defaults),
      title: ShieldConfiguration.Label(text: prayer.map { String(format: format, $0) } ?? texts.title, color: .white),
      subtitle: ShieldConfiguration.Label(text: texts.subtitle, color: UIColor.white.withAlphaComponent(0.72)),
      primaryButtonLabel: ShieldConfiguration.Label(text: texts.button, color: hero),
      primaryButtonBackgroundColor: gold
    )
  }

  /// Seçili uygulama simgesi (uygulama `salah_app_icon` yazar); asset bulunamazsa altın hilal.
  private static func logo(_ defaults: UserDefaults?) -> UIImage? {
    let id = defaults?.string(forKey: "salah_app_icon") ?? "default"
    if let image = UIImage(named: "ShieldIcon-\(id)") ?? UIImage(named: "ShieldIcon-default") {
      return image.withRenderingMode(.alwaysOriginal)
    }
    return UIImage(systemName: "moon.stars.fill")?.withTintColor(color(0xE6BD62), renderingMode: .alwaysOriginal)
  }

  /// accent-900 (Salah/Core/Theme/Palette.swift ve widget `WidgetAppColor` ile aynı değerler).
  private static func heroRGB(_ defaults: UserDefaults?) -> UInt32 {
    switch defaults?.string(forKey: "salah_app_color") {
    case "navy": return 0x10203f
    case "purple": return 0x2a1e4a
    case "burgundy": return 0x3f1420
    case "custom":
      let seed = defaults?.string(forKey: "salah_app_color_custom").flatMap(CustomPalette.parse) ?? CustomPalette.defaultSeed
      return CustomPalette.scales(seed: seed).accent[9]
    default: return 0x113c2f
    }
  }

  private static func color(_ rgb: UInt32) -> UIColor {
    UIColor(red: CGFloat((rgb >> 16) & 0xff) / 255, green: CGFloat((rgb >> 8) & 0xff) / 255, blue: CGFloat(rgb & 0xff) / 255, alpha: 1)
  }

  private struct Texts { let title, titleFormat, endFormat, subtitle, button: String }

  /// Uzantı uygulamanın dil dosyalarını okuyamaz; metinler burada (widget'lardaki WidgetL10n gibi).
  private static let texts: [String: Texts] = [
    "tr": .init(title: "Namaz vakti", titleFormat: "%@ vakti girdi", endFormat: "%@ vaktinin çıkmasına az kaldı", subtitle: "Salah'ta namazını kıldım olarak işaretleyince bu uygulama açılır.", button: "Tamam"),
    "en": .init(title: "Prayer time", titleFormat: "It's %@ time", endFormat: "%@ time is ending soon", subtitle: "This app unlocks once you mark the prayer as prayed in Salah.", button: "OK"),
    "es": .init(title: "Hora de oración", titleFormat: "Es la hora de %@", endFormat: "Queda poco para que termine la hora de %@", subtitle: "Esta app se desbloquea cuando marcas la oración como realizada en Salah.", button: "Aceptar"),
    "it": .init(title: "Ora di preghiera", titleFormat: "È l'ora di %@", endFormat: "L'orario di %@ sta per finire", subtitle: "Questa app si sblocca quando segni la preghiera come eseguita in Salah.", button: "OK"),
    "ms": .init(title: "Waktu solat", titleFormat: "Masuk waktu %@", endFormat: "Waktu %@ hampir tamat", subtitle: "Aplikasi ini dibuka semula apabila anda menandakan solat sudah dikerjakan dalam Salah.", button: "OK"),
    "bn": .init(title: "নামাজের সময়", titleFormat: "%@ এর ওয়াক্ত শুরু হয়েছে", endFormat: "%@ এর ওয়াক্ত শেষ হতে আর বেশি দেরি নেই", subtitle: "Salah-এ নামাজ আদায় হয়েছে বলে চিহ্নিত করলে এই অ্যাপ খুলবে।", button: "ঠিক আছে"),
    "hi": .init(title: "नमाज़ का वक़्त", titleFormat: "%@ का वक़्त हो गया", endFormat: "%@ का वक़्त ख़त्म होने वाला है", subtitle: "Salah में नमाज़ को अदा की हुई दर्ज करने पर यह ऐप खुलेगा।", button: "ठीक है"),
    "th": .init(title: "เวลาละหมาด", titleFormat: "เข้าเวลา%@แล้ว", endFormat: "ใกล้หมดเวลา%@แล้ว", subtitle: "แอปนี้จะปลดล็อกเมื่อคุณทำเครื่องหมายว่าละหมาดแล้วใน Salah", button: "ตกลง"),
    "ar": .init(title: "وقت الصلاة", titleFormat: "دخل وقت %@", endFormat: "اقترب خروج وقت %@", subtitle: "يُفتح هذا التطبيق بعد أن تسجّل الصلاة في تطبيق Salah.", button: "حسنًا"),
  ]

  private static let names: [String: [String: String]] = [
    "fajr": ["tr": "Sabah", "en": "Fajr", "ar": "الفجر", "es": "Fajr", "it": "Fajr", "ms": "Subuh", "bn": "ফজর", "hi": "फ़ज्र", "th": "ฟัจร์"],
    "dhuhr": ["tr": "Öğle", "en": "Dhuhr", "ar": "الظهر", "es": "Dhuhr", "it": "Dhuhr", "ms": "Zuhur", "bn": "যোহর", "hi": "ज़ुहर", "th": "ซุฮร์"],
    "asr": ["tr": "İkindi", "en": "Asr", "ar": "العصر", "es": "Asr", "it": "Asr", "ms": "Asar", "bn": "আসর", "hi": "अस्र", "th": "อัสร์"],
    "maghrib": ["tr": "Akşam", "en": "Maghrib", "ar": "المغرب", "es": "Maghrib", "it": "Maghrib", "ms": "Maghrib", "bn": "মাগরিব", "hi": "मग़रिब", "th": "มัฆริบ"],
    "isha": ["tr": "Yatsı", "en": "Isha", "ar": "العشاء", "es": "Isha", "it": "Isha", "ms": "Isyak", "bn": "ইশা", "hi": "इशा", "th": "อิชาอ์"],
  ]
}
