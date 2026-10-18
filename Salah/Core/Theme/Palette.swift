import SwiftUI

/// "Derin Orman" paleti. Değerler mobile/tailwind.config.js ile birebir aynıdır;
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

/// `slate-*`: hafif yeşile çalan nötrler.
enum Forest {
  static let s50 = Color(hex: 0xf5f7f5)
  static let s100 = Color(hex: 0xedf1ee)
  static let s200 = Color(hex: 0xdfe5e1)
  static let s300 = Color(hex: 0xc7d0ca)
  static let s400 = Color(hex: 0x97a39c)
  static let s500 = Color(hex: 0x6a766f)
  static let s600 = Color(hex: 0x4e5953)
  static let s700 = Color(hex: 0x46534c)
  static let s800 = Color(hex: 0x2d3933)
  static let s900 = Color(hex: 0x222d28)
  static let s950 = Color(hex: 0x131b17)
}

/// `accent-*` (= `teal-*`): derin zümrüt.
enum Accent {
  static let s50 = Color(hex: 0xeef6f2)
  static let s100 = Color(hex: 0xd6ebe1)
  static let s200 = Color(hex: 0xaed6c3)
  static let s300 = Color(hex: 0x7fbea2)
  static let s400 = Color(hex: 0x4fa383)
  static let s500 = Color(hex: 0x2e8a6a)
  static let s600 = Color(hex: 0x1f7356)
  static let s700 = Color(hex: 0x195c46)
  static let s800 = Color(hex: 0x154a39)
  static let s900 = Color(hex: 0x113c2f)
  static let s950 = Color(hex: 0x0f3a2b)
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
