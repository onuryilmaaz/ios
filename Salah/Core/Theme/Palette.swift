import SwiftUI

/// "Derin Orman" paleti ve seçilebilen tonları. Değerler mobile/tailwind.config.js ile birebir aynıdır;
/// orada değişen renk burada da değişmeli.
extension Color {
  init(hex: UInt32, opacity: Double = 1) {
    self.init(
      .sRGB,
      red: Double((hex >> 16) & 0xff) / 255,
      green: Double((hex >> 8) & 0xff) / 255,
      blue: Double(hex & 0xff) / 255,
      opacity: opacity
    )
  }
}

/// Uygulama rengi: Derin Orman (varsayılan) ya da Ramazan tonlarından biri. Yeşil olan her yer seçilen
/// tonu alır; altın, amber ve kırmızı sabit kalır. Ölçekler yeşilin parlaklığına eşlendi (aynı kontrast).
/// Android `AppColor` (core/theme/Palette.kt) ve widget `WidgetAppColor` (SharedColors.swift) ile aynı değerler.
enum AppColor: String, CaseIterable, Sendable {
  case forest, navy, purple, burgundy
  /// Paletten seçilen renk (`AppColorStore.customSeed`); ölçek `CustomPalette` ile üretilir.
  case custom

  /// Hazır renkler (seçicide yan yana; özel renk ayrı satırda).
  static let presets: [AppColor] = [.forest, .navy, .purple, .burgundy]

  /// Özel rengin kaynağı; AppColorStore açılışta ve seçimde günceller.
  nonisolated(unsafe) static var customSeed: UInt32 = CustomPalette.defaultSeed

  /// 50...950 (11 adım).
  nonisolated var scales: (accent: [UInt32], neutral: [UInt32]) {
    switch self {
    case .forest: (accent: [0xeef6f2, 0xd6ebe1, 0xaed6c3, 0x7fbea2, 0x4fa383, 0x2e8a6a, 0x1f7356, 0x195c46, 0x154a39, 0x113c2f, 0x0f3a2b],
               neutral: [0xf5f7f5, 0xedf1ee, 0xdfe5e1, 0xc7d0ca, 0x97a39c, 0x6a766f, 0x4e5953, 0x46534c, 0x2d3933, 0x222d28, 0x131b17])
    case .navy: (accent: [0xf2f4f8, 0xe1e6f0, 0xc4cee0, 0xa5b2ca, 0x8594b2, 0x637baa, 0x4b6698, 0x3a517d, 0x2c416a, 0x10203f, 0x0e1c37],
               neutral: [0xf6f6f8, 0xeff0f2, 0xe2e4e7, 0xcbced3, 0x9ca0a8, 0x6f737c, 0x53575e, 0x4b5059, 0x32363f, 0x272b33, 0x161920])
    case .purple: (accent: [0xf5f4f8, 0xe7e5ef, 0xd0cade, 0xb4adc7, 0x988faf, 0x8174a4, 0x6d5d97, 0x57497d, 0x473a6a, 0x2a1e4a, 0x251a41],
               neutral: [0xf7f6f8, 0xf0eff3, 0xe4e3e8, 0xcfcdd5, 0xa29faa, 0x75717e, 0x585561, 0x524e5c, 0x383442, 0x2c2936, 0x1a1822])
    case .custom: CustomPalette.scales(seed: AppColor.customSeed)
    case .burgundy: (accent: [0xf8f3f4, 0xf0e3e7, 0xdfc7ce, 0xc9a9b2, 0xb18a94, 0xa66a7b, 0x955164, 0x7a3f50, 0x67303f, 0x3f1420, 0x37121c],
               neutral: [0xf8f6f7, 0xf3eff0, 0xe8e2e4, 0xd4ccce, 0xa99da0, 0x7d7074, 0x5f5357, 0x5b4c50, 0x403337, 0x34272b, 0x201719])
    }
  }

  /// Ramazan'da saate göre: akşamdan imsaka lacivert, imsaktan öğleye mor, öğleden akşama bordo.
  nonisolated static func of(_ phase: RamadanTintPhase) -> AppColor {
    switch phase {
    case .night: .navy
    case .dawn: .purple
    case .dusk: .burgundy
    }
  }
}

/// Seçilen rengin hazır `Color` ölçekleri.
struct AppPalette {
  let accent: [Color]
  let neutral: [Color]

  init(_ color: AppColor) {
    accent = color.scales.accent.map { Color(hex: $0) }
    neutral = color.scales.neutral.map { Color(hex: $0) }
  }
}

/// `slate-*`: seçilen tona çalan nötrler.
enum Forest {
  static var s50: Color { AppColorStore.shared.palette.neutral[0] }
  static var s100: Color { AppColorStore.shared.palette.neutral[1] }
  static var s200: Color { AppColorStore.shared.palette.neutral[2] }
  static var s300: Color { AppColorStore.shared.palette.neutral[3] }
  static var s400: Color { AppColorStore.shared.palette.neutral[4] }
  static var s500: Color { AppColorStore.shared.palette.neutral[5] }
  static var s600: Color { AppColorStore.shared.palette.neutral[6] }
  static var s700: Color { AppColorStore.shared.palette.neutral[7] }
  static var s800: Color { AppColorStore.shared.palette.neutral[8] }
  static var s900: Color { AppColorStore.shared.palette.neutral[9] }
  static var s950: Color { AppColorStore.shared.palette.neutral[10] }
}

/// `accent-*` (= `teal-*`): seçilen ton (varsayılan derin zümrüt).
enum Accent {
  static var s50: Color { AppColorStore.shared.palette.accent[0] }
  static var s100: Color { AppColorStore.shared.palette.accent[1] }
  static var s200: Color { AppColorStore.shared.palette.accent[2] }
  static var s300: Color { AppColorStore.shared.palette.accent[3] }
  static var s400: Color { AppColorStore.shared.palette.accent[4] }
  static var s500: Color { AppColorStore.shared.palette.accent[5] }
  static var s600: Color { AppColorStore.shared.palette.accent[6] }
  static var s700: Color { AppColorStore.shared.palette.accent[7] }
  static var s800: Color { AppColorStore.shared.palette.accent[8] }
  static var s900: Color { AppColorStore.shared.palette.accent[9] }
  static var s950: Color { AppColorStore.shared.palette.accent[10] }
}

/// `gold-*`: ikincil vurgu.
enum Gold {
  static let s50 = Color(hex: 0xfcf7ec)
  static let s100 = Color(hex: 0xf7ebcd)
  static let s200 = Color(hex: 0xefd596)
  static let s300 = Color(hex: 0xe6bd62)
  static let s400 = Color(hex: 0xdca843)
  static let s500 = Color(hex: 0xc48f2b)
  static let s600 = Color(hex: 0xa07221)
  static let s700 = Color(hex: 0x7c581c)
}

/// Tailwind'in varsayılan amber skalası (kaza işareti, logo).
enum Amber {
  static let s50 = Color(hex: 0xfffbeb)
  static let s200 = Color(hex: 0xfde68a)
  static let s300 = Color(hex: 0xfcd34d)
  static let s400 = Color(hex: 0xfbbf24)
  static let s500 = Color(hex: 0xf59e0b)
  static let s600 = Color(hex: 0xd97706)
  static let s700 = Color(hex: 0xb45309)
}

/// Ramazan renkleri: yalnız Ramazan ekranlarında, günün saatine göre (CLAUDE.md'deki istisna).
/// Gece laciverti akşamdan imsaka, şafak moru imsaktan öğleye, mihrap bordosu öğleden iftara.
struct RamadanTint: Equatable {
  var hero: Color
  var surface: Color
  var accent: Color

  static let night = RamadanTint(hero: Color(hex: 0x10203F), surface: Color(hex: 0x1B3158), accent: Color(hex: 0xE6BD62))
  static let dawn = RamadanTint(hero: Color(hex: 0x2A1E4A), surface: Color(hex: 0x3A2C63), accent: Color(hex: 0xF0C987))
  static let dusk = RamadanTint(hero: Color(hex: 0x3F1420), surface: Color(hex: 0x561E2C), accent: Color(hex: 0xE9C07A))

  static func of(_ phase: RamadanTintPhase) -> RamadanTint {
    switch phase {
    case .night: night
    case .dawn: dawn
    case .dusk: dusk
    }
  }

  /// Şu anki ton; Debug'da `-SalahDebugTint night|dawn|dusk`.
  @MainActor
  static func current(_ today: PrayerTimes?, now: Date = Date()) -> RamadanTint {
    #if DEBUG
    if let raw = UserDefaults.standard.string(forKey: "SalahDebugTint"), let phase = RamadanTintPhase(rawValue: raw) { return of(phase) }
    #endif
    let times = today ?? PrayerTimesService.cachedDays(districtId: Locations.selectedDistrictId).first { $0.localDay.map(Calendar.current.isDateInToday) == true }?.times
    return of(RamadanPlan.tint(now: now, today: times, calendar: .current))
  }
}
