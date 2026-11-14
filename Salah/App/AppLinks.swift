import Foundation

/// `salah://` derin bağlantıları (widget'lar ve bildirimler). RN: App.tsx `handleUrl`.
///   home | prayer → Ana sayfa, qibla, alarms, hutbe → ana sayfa yığını,
///   istatistik → İbadet sekmesinde istatistikler, tracker/<tür> → ilgili kayıt formu.
///   paywall: premium kapalıyken erişim zaten açık, yok sayılır.
@Observable
final class AppLinks {
  static let shared = AppLinks()

  /// İbadet sekmesi açılınca gösterilecek kayıt formu (bir kez tüketilir).
  var pendingForm: ActivityType?
  /// İstatistikler bölümüne kaydırma isteği (bir kez tüketilir).
  var pendingInsights = false

  enum Target: Equatable {
    case home(HomeRoute?)
    case tracker(ActivityType?, insights: Bool)
  }

  static func target(for url: URL) -> Target? {
    guard let scheme = url.scheme?.lowercased(), ["salah", "com.onur6541.salah"].contains(scheme) else { return nil }
    let parts = ([url.host ?? ""] + url.pathComponents.filter { $0 != "/" }).filter { !$0.isEmpty }
    switch parts.first?.lowercased() {
    case "home", "prayer": return .home(nil)
    case "qibla": return .home(.qibla)
    case "alarms": return .home(.alarms)
    case "hutbe": return .home(.hutbe)
    case "hatim": return .home(.hatimPlan)
    case "imsakiye": return .home(.imsakiye)
    case "oruc": return .home(.fastJournal)
    case "zekat": return .home(.zakat)
    case "kaza": return .home(.kaza)
    case "zikir": return .home(.dhikr)
    case "seri":
      if let code = parts.dropFirst().first { MainActor.assumeIsolated { StreakCircleAPI.pendingCode = code.uppercased() } }
      return .home(.circles)
    case "grup":
      if let code = parts.dropFirst().first { MainActor.assumeIsolated { HatimGroupAPI.pendingCode = code } }
      return .home(.hatimGroups)
    case "istatistik": return .tracker(nil, insights: true)
    case "tracker": return .tracker(parts.dropFirst().first.flatMap { ActivityType(rawValue: $0) }, insights: false)
    default: return nil
    }
  }
}
