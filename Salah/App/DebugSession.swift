import Foundation

/// Yalnız Debug: simülatörde dokunmadan uçtan uca deneme. Release'te hiçbir şey yapmaz.
///
///   -SalahDebugLogin <kullanıcı> -SalahDebugPassword <şifre>   → Swift giriş akışıyla oturum açar
///   -SalahDebugAction <eylem>                                   → Swift store'ları üzerinden çalıştırır
///      track:<fajr|dhuhr|…> · untrack:<…> · log:quran · cleanupLogs · logout
///
/// Şifre koda yazılmaz; yalnız açılış argümanı olarak verilir. Test kayıtları
/// not alanındaki işaretle (`ios-native-test`) tanınır ve `cleanupLogs` yalnız onları siler.
enum DebugSession {
  static let testMarker = "ios-native-test"

  static func run() async {
    #if DEBUG
      let defaults = UserDefaults.standard
      if let user = defaults.string(forKey: "SalahDebugLogin"), let password = defaults.string(forKey: "SalahDebugPassword"),
        !AuthStore.shared.isAuthenticated
      {
        do {
          await AuthStore.shared.login(try await AuthAPI.login(email: user, password: password))
          print("[DebugSession] giriş başarılı: \(AuthStore.shared.user?.username ?? "?")")
        } catch {
          print("[DebugSession] giriş başarısız: \(error)")
        }
      }
      guard let action = defaults.string(forKey: "SalahDebugAction"), AuthStore.shared.isAuthenticated else { return }
      let parts = action.split(separator: ":").map(String.init)
      switch parts.first {
      case "track" where parts.count == 2:
        await GamificationStore.shared.fetchStats(force: true)
        let result = try? await GamificationStore.shared.trackPrayer(parts[1], isKaza: false)
        print("[DebugSession] track \(parts[1]): \(String(describing: result))")
      case "untrack" where parts.count == 2:
        try? await GamificationStore.shared.untrackPrayer(parts[1])
        print("[DebugSession] untrack \(parts[1])")
      case "log" where parts.count == 2:
        guard let type = ActivityType(rawValue: parts[1]) else { return }
        let log = try? await TrackerStore.shared.log(type, value: ["pages": .number(2)], notes: testMarker)
        print("[DebugSession] log \(type.rawValue): \(log?.id ?? "yok")")
      case "cleanupLogs":
        await TrackerStore.shared.fetchTodayLogs()
        for log in TrackerStore.shared.todayLogs where log.notes == testMarker {
          try? await TrackerStore.shared.delete(log.id)
          print("[DebugSession] silindi: \(log.id)")
        }
      case "logout":
        await AuthStore.shared.logout()
        print("[DebugSession] çıkış yapıldı")
      default:
        break
      }
      await GamificationStore.shared.fetchStats(force: true)
      await TrackerStore.shared.fetchTodayLogs()
    #endif
  }
}
