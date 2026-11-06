import Testing
@testable import Salah

struct WidgetThemeTests {
  @Test func missingOrUnknownValueFollowsThePhone() {
    #expect(WidgetTheme.from(nil) == .system)
    #expect(WidgetTheme.from("bogus") == .system)
  }

  /// Widget tarafı (WidgetThemeChoice) aynı metinleri okur.
  @Test func storedValuesMatchWidgetSide() {
    #expect(WidgetTheme.allCases.map(\.rawValue) == ["system", "light", "dark"])
    for theme in WidgetTheme.allCases { #expect(WidgetTheme.from(theme.rawValue) == theme) }
  }
}
