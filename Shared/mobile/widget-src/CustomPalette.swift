import Foundation

/// Kullanıcının paletten seçtiği tek renkten 11 adımlı (50...950) accent ve nötr ölçek üretir. Uygulama
/// (`AppColor.custom`) ve widget (`WidgetAppColor.custom`) aynı dosyayı derler; Android `CustomPalette.kt` aynı formül.
///
/// OKLCH: ton seçilen renkten gelir. Açıklık adımları hazır paletlerden (lacivert, mor, bordo ortalaması) sabittir; bu
/// yüzden hangi renk seçilirse seçilsin accent-600 üzerinde beyaz yazı okunur kalır. Doygunluk en fazla 0,12'dir
/// (Derin Orman'ın sakin tonu); sRGB dışına taşan adımda doygunluk düşürülür.
nonisolated enum CustomPalette {
  static let defaultSeed: UInt32 = 0x1F7356

  static let accentL: [Double] = [0.968, 0.926, 0.850, 0.763, 0.669, 0.589, 0.517, 0.442, 0.384, 0.263, 0.243]
  static let accentChroma: [Double] = [0.07, 0.17, 0.31, 0.42, 0.54, 0.86, 1.0, 0.92, 0.88, 0.77, 0.69]
  static let neutralL: [Double] = [0.974, 0.955, 0.918, 0.851, 0.706, 0.556, 0.455, 0.431, 0.334, 0.288, 0.215]
  static let neutralC: [Double] = [0.0028, 0.0047, 0.0067, 0.0103, 0.015, 0.0175, 0.0165, 0.0201, 0.0201, 0.0195, 0.0158]
  static let maxChroma = 0.12

  static func scales(seed: UInt32) -> (accent: [UInt32], neutral: [UInt32]) {
    let (_, c, h) = oklch(seed)
    let peak = min(c, maxChroma)
    // Gri seçimde nötrler de griye yaklaşır.
    let tint = min(1, c / 0.02)
    let accent = accentL.indices.map { toRGB(l: accentL[$0], c: peak * accentChroma[$0], h: h) }
    let neutral = neutralL.indices.map { toRGB(l: neutralL[$0], c: neutralC[$0] * tint, h: h) }
    return (accent, neutral)
  }

  /// "#1F7356" / "1f7356" → 0x1F7356.
  static func parse(_ text: String) -> UInt32? {
    let s = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "")
    guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
    return v
  }

  static func format(_ v: UInt32) -> String { String(format: "#%06X", v & 0xFFFFFF) }

  /// sRGB → OKLCH (L, C, h derece).
  static func oklch(_ rgb: UInt32) -> (Double, Double, Double) {
    func lin(_ v: UInt32) -> Double {
      let c = Double(v & 0xFF) / 255
      return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }
    let r = lin(rgb >> 16), g = lin(rgb >> 8), b = lin(rgb)
    let l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
    let m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
    let s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
    let L = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
    let A = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
    let B = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
    var h = atan2(B, A) * 180 / .pi
    if h < 0 { h += 360 }
    return (L, (A * A + B * B).squareRoot(), h)
  }

  /// OKLCH → sRGB; renk sRGB dışındaysa sığan en yüksek doygunluk ikili aramayla bulunur (kenarda şerit oluşmaz).
  static func toRGB(l: Double, c: Double, h: Double) -> UInt32 {
    if let rgb = convert(l: l, c: c, h: h) { return rgb }
    var lo = 0.0, hi = c
    for _ in 0..<20 {
      let mid = (lo + hi) / 2
      if convert(l: l, c: mid, h: h) != nil { lo = mid } else { hi = mid }
    }
    return convert(l: l, c: lo, h: h) ?? 0
  }

  private static func convert(l L: Double, c: Double, h: Double) -> UInt32? {
    let a = c * cos(h * .pi / 180), b = c * sin(h * .pi / 180)
    let l = pow(L + 0.3963377774 * a + 0.2158037573 * b, 3)
    let m = pow(L - 0.1055613458 * a - 0.0638541728 * b, 3)
    let s = pow(L - 0.0894841775 * a - 1.2914855480 * b, 3)
    let lin = [
      4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
      -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
      -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
    ]
    let eps = 0.0001
    guard lin.allSatisfy({ $0 >= -eps && $0 <= 1 + eps }) else { return nil }
    let bytes = lin.map { v -> UInt32 in
      let x = min(1, max(0, v))
      let srgb = x <= 0.0031308 ? 12.92 * x : 1.055 * pow(x, 1 / 2.4) - 0.055
      return UInt32((srgb * 255).rounded())
    }
    return bytes[0] << 16 | bytes[1] << 8 | bytes[2]
  }

  /// WCAG bağıl parlaklık (kontrast testi için).
  static func luminance(_ rgb: UInt32) -> Double {
    func lin(_ v: UInt32) -> Double {
      let c = Double(v & 0xFF) / 255
      return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * lin(rgb >> 16) + 0.7152 * lin(rgb >> 8) + 0.0722 * lin(rgb)
  }
}
