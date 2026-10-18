import Foundation
import Testing
@testable import Salah

/// Widget URL'leri (mobile/widget-src/Extension) ve RN App.tsx `handleUrl` ile aynı eşleme.
@MainActor
struct AppLinksTests {
  func target(_ s: String) -> AppLinks.Target? { AppLinks.target(for: URL(string: s)!) }

  @Test func widgetURLs() {
    #expect(target("salah://home") == .home(nil))
    #expect(target("salah://alarms") == .home(.alarms))
    #expect(target("salah://hutbe") == .home(.hutbe))
    #expect(target("salah://qibla") == .home(.qibla))
    #expect(target("salah://istatistik") == .tracker(nil, insights: true))
    #expect(target("salah://tracker/quran") == .tracker(.quran, insights: false))
    #expect(target("com.onur6541.salah://tracker/sadaka") == .tracker(.sadaka, insights: false))
  }

  @Test func unknownIgnored() {
    #expect(target("salah://tracker/unknown") == .tracker(nil, insights: false))
    #expect(target("salah://paywall") == nil)
    #expect(target("https://onur-yilmaz.com/home") == nil)
  }
}
