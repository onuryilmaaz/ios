import SwiftUI
import WidgetKit

// MARK: - Design System
//
// Sade, Apple-native bir dil: düz yüzeyler, net tipografi hiyerarşisi ve her
// vakit için TEK bir vurgu rengi. Parlama/iç ışıltı/ağır gölge kullanılmaz;
// vurgu rengi ikon, ilerleme ve "şimdi" işaretinde bilinçli olarak kullanılır.

// Görsel dil "Derin Orman" (uygulamayla aynı): yeşile çalan nötrler, derin
// zümrüt taban ve altın vurgu. Değerler: mobile/tailwind.config.js.
extension Color {
  /// Marka/onay rengi (accent-600 / dark accent-400).
  static func brand(_ theme: SalahTheme) -> Color {
    switch theme {
    case .light: return Color(red: 0.122, green: 0.451, blue: 0.337)
    case .dark: return Color(red: 0.310, green: 0.639, blue: 0.514)
    // Koyu zümrüt zeminde zümrüt kaybolur: açık nane (accent-200).
    case .hero: return Color(red: 0.682, green: 0.839, blue: 0.765)
    }
  }
  /// Altın vurgu (gold-500 / koyu zeminde gold-300).
  static func gold(_ theme: SalahTheme) -> Color {
    theme.isDark ? Color(red: 0.902, green: 0.741, blue: 0.384) : Color(red: 0.769, green: 0.561, blue: 0.169)
  }
}

enum SalahTheme {
  case light
  case dark
  /// Koyu zümrüt kahraman yüzeyi (uygulamadaki ana sayfa üst alanı gibi).
  case hero

  var isDark: Bool { self != .light }

  var canvas: Color {
    switch self {
    case .light: return .white
    case .dark: return Color(red: 0.133, green: 0.176, blue: 0.157)  // #222d28
    case .hero: return Color(red: 0.067, green: 0.235, blue: 0.184)  // #113c2f
    }
  }
  var textPrimary: Color { isDark ? Color(red: 0.961, green: 0.969, blue: 0.961) : Color(red: 0.086, green: 0.114, blue: 0.102) }
  var textSecondary: Color {
    isDark ? Color.white.opacity(self == .hero ? 0.72 : 0.62) : Color(red: 0.306, green: 0.349, blue: 0.325)
  }
  var textTertiary: Color {
    isDark ? Color.white.opacity(self == .hero ? 0.5 : 0.38) : Color(red: 0.592, green: 0.639, blue: 0.612)
  }
  /// İnce ayraçlar ve pasif ray.
  var hairline: Color { isDark ? Color.white.opacity(self == .hero ? 0.14 : 0.10) : Color(red: 0.875, green: 0.898, blue: 0.882) }
  /// Pasif dolgu (boş ilerleme, pasif daire).
  var fill: Color { isDark ? Color.white.opacity(self == .hero ? 0.10 : 0.07) : Color(red: 0.929, green: 0.945, blue: 0.933) }
}

// MARK: - Prayer Key & Accent

/// Görünen vakit adını (Sabah, İmsak, Güneş, Öğle...) renk/ikon anahtarına çevirir.
/// Güneş namaz değildir; sabah vaktinin bittiği an olarak ayrı anahtar alır.
/// Türkçe küçük harf: "İkindi".lowercased() Türkçe dışı locale'de "i̇kindi" olur.
func prayerKeyFromName(_ name: String) -> String {
  let n = name.lowercased(with: Locale(identifier: "tr_TR"))
  if n.contains("güneş") || n.contains("gunes") || n.contains("sunrise") { return "gunes" }
  if n.contains("sabah") || n.contains("imsak") || n.contains("fajr") { return "sabah" }
  if n.contains("öğle") || n.contains("ogle") || n.contains("dhuhr") { return "ogle" }
  if n.contains("ikindi") || n.contains("asr") { return "ikindi" }
  if n.contains("akşam") || n.contains("aksam") || n.contains("maghrib") { return "aksam" }
  if n.contains("yatsı") || n.contains("yatsi") || n.contains("isha") { return "yatsi" }
  return "ogle"
}

/// Vakit vurgusu: uygulamadaki gibi o anki vakit altınla öne çıkar.
func prayerAccent(_ key: String, _ theme: SalahTheme) -> Color {
  Color.gold(theme)
}

/// Kaza (vakti geçtikten sonra kılınan) işareti: amber (uygulamada amber-500).
func kazaAccent(_ theme: SalahTheme) -> Color {
  theme.isDark ? Color(red: 0.984, green: 0.749, blue: 0.141) : Color(red: 0.851, green: 0.467, blue: 0.024)
}

// MARK: - Amel (ibadet türü) Helpers

func amelAccent(_ type: String, _ theme: SalahTheme) -> Color {
  // Tek vurgu rengi: ibadet türleri ikonla ayrışır, renkle değil.
  Color.brand(theme)
}

func amelIcon(for type: String) -> String {
  switch type {
  case "quran":        return "book.fill"
  case "nafile":       return "moon.stars.fill"
  case "fasting":      return "drop.fill"
  case "sadaka":       return "heart.fill"
  case "dua":          return "hands.sparkles.fill"
  case "memorization": return "brain.head.profile"
  case "book":         return "books.vertical.fill"
  default:             return "star.fill"
  }
}

func amelLabel(for type: String) -> String { WL.amel(type) }

let allAmelTypes = ["quran", "nafile", "fasting", "sadaka", "dua", "memorization", "book"]

// MARK: - Typography

extension Font {
  /// Küçük başlık ("Öğle vaktine"); büyük harf ve harf aralığı yok.
  static let widgetEyebrow = Font.caption.weight(.semibold)
  /// Kahraman geri sayım: uygulamadaki gibi ince ve sabit genişlikli rakamlar.
  static func widgetHero(_ size: CGFloat) -> Font {
    .system(size: size, weight: .light).monospacedDigit()
  }
}

struct Eyebrow: View {
  let text: String
  let color: Color
  var body: some View {
    Text(text)
      .font(.widgetEyebrow)
      .foregroundColor(color)
      .lineLimit(1)
  }
}

// MARK: - Components

/// İnce kapsül ilerleme çubuğu.
struct ProgressCapsule: View {
  let progress: Double
  let tint: Color
  let track: Color
  var height: CGFloat = 4

  var body: some View {
    GeometryReader { geo in
      ZStack(alignment: .leading) {
        Capsule().fill(track)
        Capsule().fill(tint)
          .frame(width: max(height, geo.size.width * CGFloat(min(1, max(0, progress)))))
          .widgetAccentable()
      }
    }
    .frame(height: height)
  }
}

/// Günün vakitleri üzerinde şu anki konumu gösteren ray (imza öğe).
/// Geçilen kısım dolu, vakit noktaları işaretli, şu anki konumda bir imleç.
struct DayRail: View {
  let data: WidgetData?
  let now: Date
  let tint: Color
  let theme: SalahTheme

  private var marks: [Double] {
    guard let d = data else { return [] }
    return [d.imsak, d.gunes, d.ogle, d.ikindi, d.aksam, d.yatsi].compactMap(minutes)
  }

  private func minutes(_ s: String) -> Double? {
    let p = s.split(separator: ":").compactMap { Double($0) }
    return p.count >= 2 ? p[0] * 60 + p[1] : nil
  }

  var body: some View {
    let c = Calendar.current.dateComponents([.hour, .minute], from: now)
    let nowMin = Double((c.hour ?? 0) * 60 + (c.minute ?? 0))
    let lo = (marks.first ?? 0) - 30, hi = (marks.last ?? 1440) + 30
    let pos = min(1, max(0, (nowMin - lo) / (hi - lo)))
    GeometryReader { geo in
      let w = geo.size.width
      ZStack(alignment: .leading) {
        Capsule().fill(theme.hairline).frame(height: 3)
        Capsule().fill(tint.opacity(0.9)).frame(width: max(3, w * pos), height: 3).widgetAccentable()
        ForEach(Array(marks.enumerated()), id: \.offset) { _, m in
          let x = w * (m - lo) / (hi - lo)
          Circle()
            .fill(nowMin >= m ? tint : theme.canvas)
            .overlay(Circle().strokeBorder(nowMin >= m ? tint : theme.textTertiary, lineWidth: 1.2))
            .frame(width: 6, height: 6)
            .offset(x: x - 3)
        }
        Circle()
          .fill(theme.textPrimary)
          .frame(width: 10, height: 10)
          .overlay(Circle().strokeBorder(theme.canvas, lineWidth: 2))
          .offset(x: w * pos - 5)
      }
      .frame(height: 10)
    }
    .frame(height: 10)
  }
}

/// Vaktin ikonunu yumuşak renkli bir daire içinde gösterir.
struct PrayerBadge: View {
  let key: String
  let theme: SalahTheme
  var size: CGFloat = 28

  var body: some View {
    let tint = prayerAccent(key, theme)
    ZStack {
      Circle().fill(tint.opacity(theme.isDark ? 0.18 : 0.13))
      Image(systemName: prayerIcon(key))
        .font(.system(size: size * 0.46, weight: .semibold))
        .foregroundColor(tint)
        .widgetAccentable()
    }
    .frame(width: size, height: size)
  }
}

// MARK: - System Theme

/// Widget'ı iOS'un açık/koyu moduna göre çizer: temayı içeriğe verir ve arka
/// planı da aynı temayla uygular (ayrı açık/koyu widget'lara gerek kalmaz).
struct SystemThemed<Content: View>: View {
  @Environment(\.colorScheme) private var colorScheme
  let content: (SalahTheme) -> Content

  var body: some View {
    let theme: SalahTheme = colorScheme == .dark ? .dark : .light
    content(theme)
      // Sistem yazı boyutuyla büyür; sabit widget alanını taşırmayacak sınırda durur.
      .dynamicTypeSize(...DynamicTypeSize.xLarge)
      .salahWidgetBackground(theme)
  }
}

/// Ana vakit widget'ı: sistem temasından bağımsız, uygulamadaki ana sayfa üst
/// alanı gibi koyu zümrüt kahraman yüzeyi.
struct HeroThemed<Content: View>: View {
  let content: (SalahTheme) -> Content

  var body: some View {
    content(.hero)
      .dynamicTypeSize(...DynamicTypeSize.xLarge)
      .salahWidgetBackground(.hero)
  }
}

// MARK: - Widget Background

extension View {
  @ViewBuilder
  func salahWidgetBackground(_ theme: SalahTheme) -> some View {
    if #available(iOS 17.0, *) {
      containerBackground(for: .widget) { theme.canvas }
    } else {
      background(theme.canvas)
    }
  }

  // iOS 16: wraps view in ZStack with AccessoryWidgetBackground
  // iOS 17+: no-op (containerBackground handles it at the widget level)
  @ViewBuilder
  func withAccessoryBackground() -> some View {
    if #available(iOS 17.0, *) {
      self
    } else {
      ZStack {
        AccessoryWidgetBackground()
        self
      }
    }
  }

  // Apply on the widget's entry view inside StaticConfiguration
  @ViewBuilder
  func lockWidgetBackground() -> some View {
    if #available(iOS 17.0, *) {
      containerBackground(for: .widget) { AccessoryWidgetBackground() }
    } else {
      self
    }
  }
}

// MARK: - Premium Gating (bulanık önizleme)

/// App Group'taki premium erişim bayrağını okur. Anahtar hiç yazılmamışsa
/// (eski kurulum / ilk açılış öncesi) kilit YOK varsayar → false-pozitif kilit önlenir.
func isWidgetPremiumActive() -> Bool {
  guard let ud = UserDefaults(suiteName: appGroupID) else { return true }
  if ud.object(forKey: "salah_is_premium") == nil { return true }
  return ud.bool(forKey: "salah_is_premium")
}

/// Premium olmayan kullanıcıya gösterilen kilit katmanı (içerik bulanıklaştırılır).
struct PremiumLockOverlay: View {
  var body: some View {
    ZStack {
      Color.black.opacity(0.22)
      VStack(spacing: 6) {
        Image(systemName: "lock.fill")
          .font(.system(size: 20, weight: .semibold))
        Text(WL.t("premium.cta"))
          .font(.system(size: 12, weight: .semibold))
      }
      .foregroundColor(.white)
    }
  }
}

extension View {
  /// Premium değilse içeriği bulanıklaştırıp kilit katmanı koyar ve etkileşimi kapatır.
  @ViewBuilder
  func premiumGated(_ active: Bool) -> some View {
    if active {
      self
    } else {
      self
        .blur(radius: 7)
        .overlay(PremiumLockOverlay())
        .allowsHitTesting(false)
    }
  }
}
