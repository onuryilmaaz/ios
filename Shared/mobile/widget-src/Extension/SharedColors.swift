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
    case .light: return WidgetAppColor.palette.accent(6)
    // Koyu zeminde vurgu kaybolur: açık ton (accent-200).
    case .dark, .hero: return WidgetAppColor.palette.accent(2)
    }
  }

  init(rgb: UInt32) {
    self.init(red: Double((rgb >> 16) & 0xff) / 255, green: Double((rgb >> 8) & 0xff) / 255, blue: Double(rgb & 0xff) / 255)
  }
  /// Altın vurgu (gold-500 / koyu zeminde gold-300).
  static func gold(_ theme: SalahTheme) -> Color {
    theme.isDark ? Color(red: 0.902, green: 0.741, blue: 0.384) : Color(red: 0.769, green: 0.561, blue: 0.169)
  }
}

/// Uygulama rengi (Ayarlar > Uygulama rengi). Uygulama seçimi `salah_app_color` olarak yazar; Ramazan
/// günlerinde ton saate göre buradan hesaplanır (akşamdan imsaka lacivert, imsaktan öğleye mor, öğleden
/// akşama bordo), böylece uygulama açılmasa da widget doğru renkte kalır. Değerler: Salah/Core/Theme/Palette.swift.
enum WidgetAppColor: String {
  case forest, navy, purple, burgundy
  /// Paletten seçilen renk: uygulama `salah_app_color_custom` yazar ("#RRGGBB").
  case custom

  var scales: (accent: [UInt32], neutral: [UInt32]) {
    switch self {
    case .custom:
      let hex = UserDefaults(suiteName: appGroupID)?.string(forKey: "salah_app_color_custom").flatMap(CustomPalette.parse) ?? CustomPalette.defaultSeed
      return CustomPalette.scales(seed: hex)
    case .forest: return (accent: [0xeef6f2, 0xd6ebe1, 0xaed6c3, 0x7fbea2, 0x4fa383, 0x2e8a6a, 0x1f7356, 0x195c46, 0x154a39, 0x113c2f, 0x0f3a2b],
                       neutral: [0xf5f7f5, 0xedf1ee, 0xdfe5e1, 0xc7d0ca, 0x97a39c, 0x6a766f, 0x4e5953, 0x46534c, 0x2d3933, 0x222d28, 0x131b17])
    case .navy: return (accent: [0xf2f4f8, 0xe1e6f0, 0xc4cee0, 0xa5b2ca, 0x8594b2, 0x637baa, 0x4b6698, 0x3a517d, 0x2c416a, 0x10203f, 0x0e1c37],
                       neutral: [0xf6f6f8, 0xeff0f2, 0xe2e4e7, 0xcbced3, 0x9ca0a8, 0x6f737c, 0x53575e, 0x4b5059, 0x32363f, 0x272b33, 0x161920])
    case .purple: return (accent: [0xf5f4f8, 0xe7e5ef, 0xd0cade, 0xb4adc7, 0x988faf, 0x8174a4, 0x6d5d97, 0x57497d, 0x473a6a, 0x2a1e4a, 0x251a41],
                       neutral: [0xf7f6f8, 0xf0eff3, 0xe4e3e8, 0xcfcdd5, 0xa29faa, 0x75717e, 0x585561, 0x524e5c, 0x383442, 0x2c2936, 0x1a1822])
    case .burgundy: return (accent: [0xf8f3f4, 0xf0e3e7, 0xdfc7ce, 0xc9a9b2, 0xb18a94, 0xa66a7b, 0x955164, 0x7a3f50, 0x67303f, 0x3f1420, 0x37121c],
                       neutral: [0xf8f6f7, 0xf3eff0, 0xe8e2e4, 0xd4ccce, 0xa99da0, 0x7d7074, 0x5f5357, 0x5b4c50, 0x403337, 0x34272b, 0x201719])
    }
  }

  func accent(_ step: Int) -> Color { Color(rgb: scales.accent[step]) }
  func neutral(_ step: Int) -> Color { Color(rgb: scales.neutral[step]) }

  static var palette: WidgetAppColor { current() }

  static func current(now: Date = Date()) -> WidgetAppColor {
    if let ramadan = ramadan(now) { return ramadan }
    return UserDefaults(suiteName: appGroupID)?.string(forKey: "salah_app_color").flatMap(WidgetAppColor.init) ?? .forest
  }

  private static func ramadan(_ now: Date) -> WidgetAppColor? {
    guard let data = RamadanData.load(), data.on else { return nil }
    let key = dayKey(now)
    guard key >= data.start, key <= data.last else { return nil }
    guard let times = WidgetData.load(at: now) else { return .navy }
    func minutes(_ s: String) -> Int? {
      let p = s.split(separator: ":").compactMap { Int($0) }
      return p.count >= 2 ? p[0] * 60 + p[1] : nil
    }
    let c = Calendar.current.dateComponents([.hour, .minute], from: now)
    let m = (c.hour ?? 0) * 60 + (c.minute ?? 0)
    guard let imsak = minutes(times.imsak), let ogle = minutes(times.ogle), let aksam = minutes(times.aksam) else { return .navy }
    if m < imsak || m >= aksam { return .navy }
    return m < ogle ? .purple : .burgundy
  }
}

enum SalahTheme {
  case light
  case dark
  /// Koyu zümrüt kahraman yüzeyi: StandBy ve Live Activity (ana ekran widget'ları temaya uyar).
  case hero

  var isDark: Bool { self != .light }

  var canvas: Color {
    switch self {
    case .light: return .white
    // accent-900 (#113c2f yeşilde; Android widget'larıyla aynı)
    case .dark, .hero: return WidgetAppColor.palette.accent(9)
    }
  }
  var textPrimary: Color { isDark ? WidgetAppColor.palette.neutral(0) : Color(red: 0.086, green: 0.114, blue: 0.102) }
  var textSecondary: Color {
    isDark ? Color.white.opacity(0.72) : WidgetAppColor.palette.neutral(6)
  }
  var textTertiary: Color {
    isDark ? Color.white.opacity(0.5) : WidgetAppColor.palette.neutral(5)
  }
  /// İnce ayraçlar ve pasif ray.
  var hairline: Color { isDark ? Color.white.opacity(0.14) : WidgetAppColor.palette.neutral(2) }
  /// Pasif dolgu (boş ilerleme, pasif daire).
  var fill: Color { isDark ? Color.white.opacity(0.10) : WidgetAppColor.palette.neutral(1) }
}

// MARK: - Prayer Key & Accent

/// Görünen vakit adını (Sabah, İmsak, Güneş, Öğle...) renk/ikon anahtarına çevirir.
/// Güneş namaz değildir; sabah vaktinin bittiği an olarak ayrı anahtar alır.
/// Türkçe küçük harf: "İkindi".lowercased() Türkçe dışı locale'de "i̇kindi" olur.
func prayerKeyFromName(_ name: String) -> String {
  let n = name.lowercased(with: Locale(identifier: "tr_TR"))
  if n.contains("iftar") { return "aksam" }
  if n.contains("sahur") { return "sabah" }
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
  var accent: Color? = nil

  var body: some View {
    let tint = accent ?? prayerAccent(key, theme)
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

/// Widget'ı Ayarlar'daki widget temasına, seçim "telefon teması"ysa iOS'un açık/koyu moduna göre
/// çizer: temayı içeriğe verir ve arka planı da aynı temayla uygular.
struct SystemThemed<Content: View>: View {
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.widgetFamily) private var family
  let content: (SalahTheme) -> Content

  var body: some View {
    if Self.isAccessory(family) {
      // Kilit ekranı: tema zorlanmaz. iOS metni kendi titreşimli rengiyle çizer; açık tema koyu yazıyı
      // burada neredeyse saydam yapıyordu.
      content(.dark)
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
        .lockWidgetBackground()
    } else {
      themed
    }
  }

  private static func isAccessory(_ family: WidgetFamily) -> Bool {
    family == .accessoryRectangular || family == .accessoryInline || family == .accessoryCircular
  }

  @ViewBuilder
  private var themed: some View {
    let dark = WidgetThemeChoice.load().forcedDark ?? (colorScheme == .dark)
    let theme: SalahTheme = dark ? .dark : .light
    content(theme)
      .environment(\.colorScheme, dark ? .dark : .light)
      // Sistem yazı boyutuyla büyür; sabit widget alanını taşırmayacak sınırda durur.
      .dynamicTypeSize(...DynamicTypeSize.xLarge)
      .salahWidgetBackground(theme)
  }
}

// MARK: - Galeri

/// iOS galeride önizleme yerine placeholder'a düşünce içeriği iskelete çevirir (gerçek cihazda büyük boyda görüldü).
/// Bu widget'ların placeholder'ı gerçek örnek taşıdığı için iskelet kaldırılır. Yalnız placeholder: gizlilik
/// karartmasına (kilitli ekran) dokunmaz.
private struct GalleryPlaceholderReadable: ViewModifier {
  @Environment(\.redactionReasons) private var reasons

  func body(content: Content) -> some View {
    if reasons.contains(.placeholder) { content.unredacted() } else { content }
  }
}

extension View {
  func galleryPlaceholderReadable() -> some View { modifier(GalleryPlaceholderReadable()) }
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
