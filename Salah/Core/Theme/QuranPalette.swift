import SwiftUI

/// RN quranSettings.store.ts ve constants/mushafThemes.ts okuma yüzeyleri.
struct QuranReadingPalette {
  var canvas: Color
  var surface: Color
  var line: Color
  var primary: Color
  var secondary: Color
  var arabic: Color
  var accent: Color

  init(theme: QuranReadingTheme, tokens: Tokens) {
    switch theme {
    case .system:
      canvas = tokens.canvas; surface = tokens.isDark ? Forest.s950 : .white; line = tokens.line
      primary = tokens.textPrimary; secondary = tokens.isDark ? Forest.s300 : Forest.s600
      arabic = tokens.isDark ? .white : Forest.s900; accent = tokens.accent
    case .sepia:
      canvas = Color(hex: 0xf8efdb); surface = Color(hex: 0xfbf5e3); line = Color(hex: 0xe8dcb6)
      primary = Color(hex: 0x3b2a17); secondary = Color(hex: 0x6b5634); arabic = Color(hex: 0x2c1d0a); accent = Color(hex: 0xa06c2a)
    case .night:
      canvas = Color(hex: 0x0b0d12); surface = Color(hex: 0x11141c); line = Color(hex: 0x1d2230)
      primary = Color(hex: 0xe8d9b3); secondary = Color(hex: 0xa6916b); arabic = Color(hex: 0xf3e1b6); accent = Color(hex: 0xf59e0b)
    }
  }
}

struct MushafPalette {
  var canvas: Color
  var ink: Color
  var muted: Color
  var gold: Color
  var accent: Color
  var header: Color
  var border: Color
  var mark: Color
  var isDark: Bool

  init(theme: MushafTheme, appIsDark: Bool) {
    isDark = theme == .night || (theme == .auto && appIsDark)
    if theme == .sepia {
      canvas = Color(hex: 0xf2e8d5); ink = Color(hex: 0x3a2e20); muted = Color(hex: 0x8a7a62)
      gold = Color(hex: 0xa0721e); accent = Color(hex: 0x5f6b2c); header = Color(hex: 0xeadcc0)
      border = Color(hex: 0xc9a464); mark = Color(hex: 0xe6d3a8)
    } else if isDark {
      canvas = Color(hex: 0x0b110e); ink = Color(hex: theme == .auto ? 0xf5f7f5 : 0xc7d0ca); muted = Color(hex: 0x6a766f)
      gold = Color(hex: theme == .auto ? 0xdca843 : 0xc9a04f); accent = Color(hex: 0x4fa383)
      header = Color(hex: 0x1a1a10); border = Color(hex: 0x7c581c); mark = Color(hex: 0x2a2414)
    } else {
      canvas = Color(hex: 0xf5f7f5); ink = Color(hex: 0x161d1a); muted = Color(hex: 0x6a766f)
      gold = Color(hex: 0xc48f2b); accent = Color(hex: 0x1f7356); header = Color(hex: 0xfcf7ec)
      border = Color(hex: 0xe6bd62); mark = Color(hex: 0xf7ebcd)
    }
  }
}

enum TajweedColors {
  static let values: [String: UInt32] = [
    "ham_wasl": 0x9ca3af, "laam_shamsiyah": 0x9ca3af, "slnt": 0x9ca3af, "idgham_mutajanisayn": 0x9ca3af,
    "madda_normal": 0x3b82f6, "madda_permissible": 0x2563eb, "madda_obligatory": 0x1d4ed8, "madda_necessary": 0x1e3a8a,
    "ghunnah": 0xf97316, "ikhafa": 0xa21caf, "ikhafa_shafawi": 0xc026d3, "idgham_ghunnah": 0x16a34a,
    "idgham_wo_ghunnah": 0x15803d, "idgham_shafawi": 0x22c55e, "iqlab": 0x0ea5e9, "qalaqah": 0xdc2626,
  ]
  static let legend: [(String, UInt32)] = [("madd", 0x3b82f6), ("ghunnah", 0xf97316), ("qalqalah", 0xdc2626), ("ikhfa", 0xa21caf), ("idgham", 0x16a34a), ("iqlab", 0x0ea5e9), ("silent", 0x9ca3af)]
}
