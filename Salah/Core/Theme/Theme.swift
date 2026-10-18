import SwiftUI

/// Anlamsal renkler; mobile/src/theme/tokens.ts ile aynı değerler.
/// Ek olarak sık kullanılan `x / dark:y` sınıf çiftleri adlandırıldı.
struct Tokens {
  let isDark: Bool

  var canvas: Color { isDark ? Forest.s950 : Forest.s50 }
  var surface: Color { isDark ? Forest.s900 : .white }
  var line: Color { isDark ? Forest.s800 : Forest.s200 }
  var ink: Color { isDark ? Forest.s50 : Forest.s900 }
  var inkMuted: Color { isDark ? Forest.s400 : Forest.s600 }
  var inkSubtle: Color { isDark ? Forest.s600 : Forest.s400 }
  var accent: Color { isDark ? Accent.s400 : Accent.s600 }
  var accentSoft: Color { isDark ? Accent.s900 : Accent.s50 }
  var onAccent: Color { isDark ? Forest.s950 : .white }
  var gold: Color { isDark ? Gold.s400 : Gold.s500 }
  var danger: Color { isDark ? Color(hex: 0xf87171) : Color(hex: 0xdc2626) }

  /// `text-slate-900 dark:text-slate-50`
  var textPrimary: Color { isDark ? Forest.s50 : Forest.s900 }
  /// `text-slate-500 dark:text-slate-400`
  var textSecondary: Color { isDark ? Forest.s400 : Forest.s500 }
  /// `bg-slate-100 dark:bg-slate-800`
  var fill: Color { isDark ? Forest.s800 : Forest.s100 }
  /// Ana sayfa üst alanı: `bg-accent-900 dark:bg-accent-950`
  var hero: Color { isDark ? Accent.s950 : Accent.s900 }
}

extension EnvironmentValues {
  @Entry var tokens = Tokens(isDark: true)
}

/// Kullanıcının tema seçimi. RN ile aynı anahtar ve varsayılan (koyu).
@Observable
final class ThemeStore {
  static let shared = ThemeStore()
  private static let key = "@salah_theme_mode"

  private(set) var isDark: Bool

  private init() {
    isDark = LocalStore.string(Self.key).map { $0 == "dark" } ?? true
  }

  func setDark(_ value: Bool) {
    isDark = value
    LocalStore.set(value ? "dark" : "light", for: Self.key)
  }

  func toggle() { setDark(!isDark) }

  var tokens: Tokens { Tokens(isDark: isDark) }
}
