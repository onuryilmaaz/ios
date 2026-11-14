import Testing
@testable import Salah

struct AppColorTests {
  @Test func everyColorHasElevenSteps() {
    for color in AppColor.allCases {
      #expect(color.scales.accent.count == 11)
      #expect(color.scales.neutral.count == 11)
    }
  }

  /// Yeşil değişmedi; diğerlerinin üst alan tonu Ramazan renklerinin kendisi. Android `AppColorTest` ile aynı.
  @Test func forestUnchangedAndHeroesMatchRamadan() {
    #expect(AppColor.forest.scales.accent[6] == 0x1f7356)
    #expect(AppColor.forest.scales.neutral[10] == 0x131b17)
    #expect(AppColor.navy.scales.accent[9] == 0x10203f)
    #expect(AppColor.purple.scales.accent[9] == 0x2a1e4a)
    #expect(AppColor.burgundy.scales.accent[9] == 0x3f1420)
  }

  @Test func ramadanPhaseMapping() {
    #expect(AppColor.of(.night) == .navy)
    #expect(AppColor.of(.dawn) == .purple)
    #expect(AppColor.of(.dusk) == .burgundy)
  }
}

/// Özel renk: paletteki her seçimde ölçek tam ve accent-600 üzerinde beyaz yazı okunur (WCAG 4.5:1).
struct CustomPaletteTests {
  func contrast(_ a: UInt32, _ b: UInt32) -> Double {
    let la = CustomPalette.luminance(a), lb = CustomPalette.luminance(b)
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
  }

  @Test func everyGridSeedIsReadable() {
    // Tekerleğin her yeri (15 derece, 5 doygunluk) ve uç renkler.
    let wheel = stride(from: 0.0, to: 360.0, by: 15.0).flatMap { h in [0.0, 0.03, 0.06, 0.09, 0.12].map { CustomPalette.toRGB(l: CustomPalette.accentL[6], c: $0, h: h) } }
    let seeds = wheel + [0xFF0000, 0x00FF00, 0x0000FF, 0xFFFF00, 0xFFFFFF, 0x000000, 0xFF00FF]
    for seed in seeds {
      let s = CustomPalette.scales(seed: seed)
      #expect(s.accent.count == 11 && s.neutral.count == 11)
      #expect(contrast(s.accent[6], 0xFFFFFF) >= 4.5, "accent-600 \(CustomPalette.format(seed))")
      #expect(contrast(s.accent[9], 0xFFFFFF) >= 7, "accent-900 \(CustomPalette.format(seed))")
    }
  }

  @Test func hueIsKept() {
    let (_, _, h) = CustomPalette.oklch(0x2E8A6A)
    let (_, _, h6) = CustomPalette.oklch(CustomPalette.scales(seed: 0x2E8A6A).accent[6])
    #expect(abs(h - h6) < 3)
  }

  @Test func parseAndFormat() {
    #expect(CustomPalette.parse("#1f7356") == 0x1F7356)
    #expect(CustomPalette.parse("1F7356") == 0x1F7356)
    #expect(CustomPalette.parse("#12345") == nil)
    #expect(CustomPalette.parse("#GGGGGG") == nil)
    #expect(CustomPalette.format(0x0A0B0C) == "#0A0B0C")
  }
}
