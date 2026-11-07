import SwiftUI

/// Kıble pusulasının seçilebilir temaları. Seçim cihazda kalır; renkler Ramazan paletiyle aynı adları taşır.
struct QiblaTheme: Identifiable, Equatable {
  enum Motif { case star, sky, moons, mihrab, inlay }

  let id: String
  let nameKey: String
  let background: Color
  let surface: Color
  let accent: Color
  let onAccent: Color
  let ink: Color
  let muted: Color
  let tick: Color
  let idleRim: Color
  let isLight: Bool
  let motif: Motif

  /// Kadran 320 birimlik çizilir; ibre, Kâbe ve yön harflerinin merkeze uzaklığı.
  var needle: (from: Double, to: Double, kaaba: Double) {
    switch motif {
    case .star: (60, 90, 110)
    case .sky: (60, 84, 102)
    case .moons: (58, 76, 90)
    case .mihrab: (56, 76, 112)
    case .inlay: (64, 88, 106)
    }
  }
  var cardinalRadius: Double {
    switch motif {
    case .star: 134
    case .sky: 134
    case .moons: 130
    case .mihrab: 136
    case .inlay: 133
    }
  }
  var centerRadius: Double {
    switch motif {
    case .moons: 52
    case .mihrab: 50
    default: 54
    }
  }
  /// Mihrapta kemere yer açmak için merkez aşağıda durur.
  var centerOffset: Double { motif == .mihrab ? 16 : 0 }

  private static let lightOnDark = Color.white.opacity(0.85)
  private static let darkRim = Color.white.opacity(0.14)
  private static let darkTick = Color.white.opacity(0.4)

  static let all: [QiblaTheme] = [
    .init(id: "forest", nameKey: "qibla.themeForest", background: Accent.s900, surface: Accent.s800, accent: Gold.s300, onAccent: Accent.s900,
      ink: .white, muted: lightOnDark, tick: darkTick, idleRim: darkRim, isLight: false, motif: .star),
    .init(id: "night", nameKey: "qibla.themeNight", background: RamadanTint.night.hero, surface: RamadanTint.night.surface, accent: RamadanTint.night.accent, onAccent: RamadanTint.night.hero,
      ink: .white, muted: lightOnDark, tick: darkTick, idleRim: darkRim, isLight: false, motif: .sky),
    .init(id: "dawn", nameKey: "qibla.themeDawn", background: RamadanTint.dawn.hero, surface: RamadanTint.dawn.surface, accent: RamadanTint.dawn.accent, onAccent: RamadanTint.dawn.hero,
      ink: .white, muted: lightOnDark, tick: darkTick, idleRim: darkRim, isLight: false, motif: .moons),
    .init(id: "dusk", nameKey: "qibla.themeDusk", background: RamadanTint.dusk.hero, surface: RamadanTint.dusk.surface, accent: RamadanTint.dusk.accent, onAccent: RamadanTint.dusk.hero,
      ink: .white, muted: lightOnDark, tick: darkTick, idleRim: darkRim, isLight: false, motif: .mihrab),
    .init(id: "sand", nameKey: "qibla.themeSand", background: Color(hex: 0xF4EBDD), surface: Color(hex: 0xE9DBC6), accent: Color(hex: 0x8A4B2A), onAccent: Color(hex: 0xFFFDF8),
      ink: Color(hex: 0x2B1E14), muted: Color(hex: 0x5A4632), tick: Color(hex: 0xA38B6D), idleRim: Color(hex: 0xD2BE9F), isLight: true, motif: .inlay),
  ]

  static let storageKey = "@salah_qibla_theme_v1"

  static func find(_ id: String?) -> QiblaTheme { all.first { $0.id == id } ?? all[0] }
  static var saved: QiblaTheme { find(LocalStore.string(storageKey)) }
}
