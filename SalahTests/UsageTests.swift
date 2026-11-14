import Testing
@testable import Salah

/// Sunucudaki USAGE_EVENT kuralı ve ekran adları.
@MainActor
struct UsageTests {
  @Test(arguments: ["app.open", "tab.quran", "screen.hatimGroup", "siri.mark", "quran.download"])
  func validEvents(_ e: String) { #expect(UsageStore.isValid(e)) }

  @Test(arguments: ["", "App.open", "screen.a.b.c", "screen.with space", "x.", "türkçe.ad"])
  func invalidEvents(_ e: String) { #expect(!UsageStore.isValid(e)) }

  @Test func routeNamesDropAssociatedValues() {
    #expect(HomeRoute.qibla.usageName == "qibla")
    #expect(HomeRoute.hatimGroup("abc").usageName == "hatimGroup")
    #expect(HomeRoute.kaza.usageName == "kaza")
    for name in [HomeRoute.history, .adminUser("x"), .fastJournal].map(\.usageName) { #expect(UsageStore.isValid("screen.\(name)")) }
  }
}
