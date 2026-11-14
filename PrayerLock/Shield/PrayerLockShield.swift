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
    let lang = UserDefaults(suiteName: PrayerLockShared.suite)?.string(forKey: "appLanguage") ?? "tr"
    let texts = Self.texts[lang] ?? Self.texts["tr"]!
    let prayer = PrayerLockShared.currentPrayer.flatMap { Self.names[$0]?[Self.index(lang)] }
    return ShieldConfiguration(
      backgroundBlurStyle: .systemThickMaterialDark,
      backgroundColor: UIColor(red: 0.06, green: 0.23, blue: 0.17, alpha: 1),
      icon: UIImage(systemName: "moon.stars.fill"),
      title: ShieldConfiguration.Label(text: prayer.map { String(format: texts.titleFormat, $0) } ?? texts.title, color: .white),
      subtitle: ShieldConfiguration.Label(text: texts.subtitle, color: UIColor.white.withAlphaComponent(0.85)),
      primaryButtonLabel: ShieldConfiguration.Label(text: texts.button, color: UIColor(red: 0.06, green: 0.23, blue: 0.17, alpha: 1)),
      primaryButtonBackgroundColor: UIColor(red: 0.96, green: 0.83, blue: 0.48, alpha: 1)
    )
  }

  private static func index(_ lang: String) -> Int { lang == "en" ? 1 : lang == "ar" ? 2 : 0 }

  private struct Texts { let title, titleFormat, subtitle, button: String }

  /// Uzantı uygulamanın dil dosyalarını okuyamaz; metinler burada (widget'lardaki WidgetL10n gibi).
  private static let texts: [String: Texts] = [
    "tr": .init(title: "Namaz vakti", titleFormat: "%@ vakti girdi", subtitle: "Salah'ta namazını kıldım olarak işaretleyince bu uygulama açılır.", button: "Tamam"),
    "en": .init(title: "Prayer time", titleFormat: "It's %@ time", subtitle: "This app unlocks once you mark the prayer as prayed in Salah.", button: "OK"),
    "ar": .init(title: "وقت الصلاة", titleFormat: "دخل وقت %@", subtitle: "يُفتح هذا التطبيق بعد أن تسجّل الصلاة في تطبيق Salah.", button: "حسنًا"),
  ]

  private static let names: [String: [String]] = [
    "fajr": ["Sabah", "Fajr", "الفجر"], "dhuhr": ["Öğle", "Dhuhr", "الظهر"], "asr": ["İkindi", "Asr", "العصر"],
    "maghrib": ["Akşam", "Maghrib", "المغرب"], "isha": ["Yatsı", "Isha", "العشاء"],
  ]
}
