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
