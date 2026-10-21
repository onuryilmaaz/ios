import SwiftUI

enum AppLanguage: String, CaseIterable, Sendable {
  case tr, en, ar

  var isRTL: Bool { self == .ar }

  /// Telefon dili: Türkçe ve Arapça doğrudan, diğer her dil için İngilizce.
  static var device: AppLanguage {
    let code = Locale.preferredLanguages.first.map { Locale(identifier: $0).language.languageCode?.identifier ?? "" }
    switch code {
    case "tr": return .tr
    case "ar": return .ar
    default: return .en
    }
  }
}

enum LanguagePreference: Equatable, Sendable {
  case system
  case fixed(AppLanguage)

  init?(raw: String) {
    if raw == "system" {
      self = .system
    } else if let lang = AppLanguage(rawValue: raw) {
      self = .fixed(lang)
    } else {
      return nil
    }
  }

  var raw: String {
    switch self {
    case .system: return "system"
    case .fixed(let lang): return lang.rawValue
    }
  }

  var resolved: AppLanguage {
    switch self {
    case .system: return .device
    case .fixed(let lang): return lang
    }
  }
}

/// Metinler Shared/mobile/src/i18n/locales/{tr,en,ar}.json dosyalarından gelir (RN projesinden alınmış, artık iOS'a ait kopya).
/// Anahtar biçimi (`home.hero.entry`) ve `{{değişken}}` yer tutucuları i18next ile aynıdır.
///
/// SwiftUI gövdesinde `t(...)` çağrısı `language`'ı okuduğu için dil
/// değişince ekranlar kendiliğinden yeniden çizilir.
@Observable
final class Localizer {
  static let shared = Localizer()

  private static let languageKey = "@salah_language"
  /// Onboarding tamamlanmışsa uygulama bu sürümden önce de kullanılıyordu.
  private static let existingInstallKey = "@salah_onboarding_done"

  private(set) var preference: LanguagePreference
  private(set) var language: AppLanguage

  @ObservationIgnored private var tables: [AppLanguage: [String: Entry]] = [:]

  private enum Entry {
    case text(String)
    case list([String])
  }

  private init() {
    var pref = LanguagePreference.system
    if let saved = LocalStore.string(Self.languageKey), let p = LanguagePreference(raw: saved) {
      pref = p
    } else if LocalStore.string(Self.existingInstallKey) != nil {
      // Güncelleyen kullanıcı: arayüz birden telefon diline dönmesin.
      pref = .fixed(.tr)
      LocalStore.set(pref.raw, for: Self.languageKey)
    } else {
      LocalStore.set(pref.raw, for: Self.languageKey)
    }
    preference = pref
    language = pref.resolved
    for lang in AppLanguage.allCases { tables[lang] = Self.load(lang) }
  }

  func setPreference(_ pref: LanguagePreference) {
    preference = pref
    language = pref.resolved
    LocalStore.set(pref.raw, for: Self.languageKey)
  }

  var layoutDirection: LayoutDirection { language.isRTL ? .rightToLeft : .leftToRight }
  var locale: Locale { Locale(identifier: language.rawValue) }

  /// Çeviri; anahtar yoksa Türkçe'ye, o da yoksa anahtarın kendisine düşer.
  func t(_ key: String, _ vars: [String: any CustomStringConvertible] = [:]) -> String {
    var text = lookup(key) ?? key
    for (name, value) in vars {
      text = text.replacingOccurrences(of: "{{\(name)}}", with: value.description)
    }
    return text
  }

  func list(_ key: String) -> [String] {
    for lang in [language, .tr] {
      if case .list(let items)? = tables[lang]?[key] { return items }
    }
    return []
  }

  private func lookup(_ key: String) -> String? {
    for lang in [language, .tr] {
      if case .text(let s)? = tables[lang]?[key] { return s }
    }
    return nil
  }

  private static func load(_ lang: AppLanguage) -> [String: Entry] {
    guard
      let url = Bundle.main.url(forResource: lang.rawValue, withExtension: "json", subdirectory: "locales"),
      let data = try? Data(contentsOf: url),
      let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return [:] }
    var out: [String: Entry] = [:]
    flatten(root, prefix: "", into: &out)
    return out
  }

  private static func flatten(_ node: [String: Any], prefix: String, into out: inout [String: Entry]) {
    for (key, value) in node {
      let path = prefix + key
      switch value {
      case let s as String: out[path] = .text(s)
      case let items as [Any]: out[path] = .list(items.compactMap { $0 as? String })
      case let child as [String: Any]: flatten(child, prefix: path + ".", into: &out)
      default: break
      }
    }
  }
}

/// Kısa yol: `t("home.tracker.title")`, `t("home.hero.entry", ["time": "05:12"])`.
func t(_ key: String, _ vars: [String: any CustomStringConvertible] = [:]) -> String {
  Localizer.shared.t(key, vars)
}
