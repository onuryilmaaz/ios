import SwiftUI

/// Alt sekmeler. RN: navigation/UserNavigator.tsx (iOS'ta native UITabBar, SF Symbols).
/// Kur'an, İbadet ve Sor sekmeleri giriş ister; misafirde tam ekran giriş seçenekleri açılır.
struct RootView: View {
  @Environment(\.tokens) private var tokens

  enum Tab: Hashable {
    case home, quran, tracker, assistant

    var requiresAuthentication: Bool { self != .home }
  }

  @State private var tab: Tab = DebugLaunch.tab ?? .home
  @State private var debugShare = DebugLaunch.share

  var body: some View {
    TabView(selection: Binding(get: { tab }, set: { select($0) })) {
      HomeView()
        .tabItem { Label(t("tabs.home"), systemImage: "house.fill") }
        .tag(Tab.home)
      SurahBrowserView()
        .tabItem { Label(t("tabs.quran"), systemImage: "book.fill") }
        .tag(Tab.quran)
      TrackerView()
        .tabItem { Label(t("tabs.tracker"), systemImage: "chart.bar.fill") }
        .tag(Tab.tracker)
      AssistantView()
        .tabItem { Label(t("tabs.assistant"), systemImage: "sparkles") }
        .tag(Tab.assistant)
    }
    // RN: aktif #1f7356 / koyu #2e8a6a
    .tint(tokens.isDark ? Accent.s500 : Accent.s600)
    .fullScreenCover(isPresented: Bindable(AuthFlow.shared).isPresented) {
      AuthFlowView()
        .environment(\.tokens, tokens)
        .environment(\.layoutDirection, Localizer.shared.layoutDirection)
        .environment(\.locale, Localizer.shared.locale)
    }
    #if DEBUG
    .fullScreenCover(isPresented: Binding(get: { debugShare != nil }, set: { if !$0 { debugShare = nil } })) {
      DebugSharePreview(kind: debugShare ?? "").environment(\.tokens, tokens)
    }
    #endif
    .onAppear {
      if let route = DebugLaunch.auth { AuthFlow.shared.present(route) }
      if let route = DebugLaunch.route { HomeNavigation.shared.path = [route] }
      #if DEBUG
      if let link = UserDefaults.standard.string(forKey: "SalahDebugURL"), let url = URL(string: link) {
        Task { try? await Task.sleep(for: .seconds(1)); open(url) }
      }
      #endif
      #if DEBUG
      if let section = DebugLaunch.notifications {
        NotificationStore.shared.preview(section)
        if section == "adhanModal" { AdhanPlayer.shared.preview() }
      }
      #endif
      if NotificationNavigation.shared.inspiration != nil { tab = .home }
    }
    .onOpenURL { open($0) }
    .onChange(of: NotificationNavigation.shared.homeRequest) {
      tab = .home
    }
    .onChange(of: AuthStore.shared.user) { OzelGunStore.shared.syncAccount() }
    .onChange(of: AuthStore.shared.isAuthenticated) { _, authed in
      // Oturum kapanınca giriş isteyen sekmede kalınmaz.
      if !authed, tab.requiresAuthentication { tab = .home }
      if !authed { QuranAudioPlayer.shared.stop() }
      if !authed { HomeNavigation.shared.path.removeAll() }
    }
  }

  private func select(_ next: Tab) {
    guard next != tab else { return }
    Haptics.impact(.light)
    if next.requiresAuthentication, !AuthStore.shared.isAuthenticated {
      AuthFlow.shared.present()
      return
    }
    tab = next
  }

  private func open(_ url: URL) {
    guard let target = AppLinks.target(for: url) else { return }
    switch target {
    case .home(let route):
      tab = .home
      HomeNavigation.shared.path = route.map { [$0] } ?? []
    case .tracker(let form, let insights):
      if AuthStore.shared.isAuthenticated {
        AppLinks.shared.pendingForm = form
        AppLinks.shared.pendingInsights = insights
      }
      if tab != .tracker { select(.tracker) }
    }
  }

}

/// Yalnız Debug: ekran görüntüsü/doğrulama için açılış argümanları.
///   -SalahDebugTab tracker      → giriş duvarını atlayıp sekmeyi açar
///   -SalahDebugForm quran       → İbadet kayıt formunu açar
enum DebugLaunch {
  /// Görsel kontroller ve test host'u canlı backend'e istek göndermez.
  static var isIsolated: Bool {
    #if DEBUG
      let env = ProcessInfo.processInfo.environment
      return env["SALAH_TEST_ISOLATED"] == "1" || UserDefaults.standard.bool(forKey: "SalahDebugOffline") || splashPreview || adminPreview || notifications != nil || quran != nil || qibla != nil || calendar != nil || ozelGun != nil
        || env["XCTestConfigurationFilePath"] != nil || env["XCTestBundlePath"] != nil
        || NSClassFromString("XCTestCase") != nil
    #else
      return false
    #endif
  }

  static var splashPreview: Bool {
    #if DEBUG
    UserDefaults.standard.bool(forKey: "SalahDebugSplash") || splashFrame != nil || splashReduceMotion
    #else
    false
    #endif
  }

  static var splashFrame: String? {
    #if DEBUG
    let frame = UserDefaults.standard.string(forKey: "SalahDebugSplashFrame")
    return frame == "start" || frame == "brand" ? frame : nil
    #else
    nil
    #endif
  }

  static var splashReduceMotion: Bool {
    #if DEBUG
    UserDefaults.standard.bool(forKey: "SalahDebugReduceMotion")
    #else
    false
    #endif
  }

  static var adminPreview: Bool {
    #if DEBUG
    UserDefaults.standard.bool(forKey: "SalahDebugAdmin")
    #else
    false
    #endif
  }

  /// -SalahDebugShare streak|recap|cuma|bayram|kandil → paylaşım görselini örnek veriyle açar.
  static var share: String? {
    #if DEBUG
      return UserDefaults.standard.string(forKey: "SalahDebugShare")
    #else
      return nil
    #endif
  }

  static var notifications: String? {
    #if DEBUG
      return UserDefaults.standard.string(forKey: "SalahDebugNotifications")
    #else
      return nil
    #endif
  }

  static var quran: String? {
    #if DEBUG
    return UserDefaults.standard.string(forKey: "SalahDebugQuran")
    #else
    return nil
    #endif
  }
  static var qibla: String? {
    #if DEBUG
    return UserDefaults.standard.string(forKey: "SalahDebugQibla")
    #else
    return nil
    #endif
  }
  static var calendar: String? {
    #if DEBUG
    return UserDefaults.standard.string(forKey: "SalahDebugCalendar")
    #else
    return nil
    #endif
  }
  static var ozelGun: String? {
    #if DEBUG
    return UserDefaults.standard.string(forKey: "SalahDebugOzelGun")
    #else
    return nil
    #endif
  }
  static var mushafPage: Int? {
    #if DEBUG
    return UserDefaults.standard.object(forKey: "SalahDebugMushafPage").map { _ in UserDefaults.standard.integer(forKey: "SalahDebugMushafPage") }
    #else
    return nil
    #endif
  }

  static var tab: RootView.Tab? {
    #if DEBUG
      switch UserDefaults.standard.string(forKey: "SalahDebugTab") {
      case "quran": return .quran
      case "tracker": return .tracker
      case "assistant": return .assistant
      default: return nil
      }
    #else
      return nil
    #endif
  }

  ///   -SalahDebugAuth welcome|login|register|otp|forgot|reset → giriş akışını açar
  static var auth: AuthFlow.Route?? {
    #if DEBUG
      switch UserDefaults.standard.string(forKey: "SalahDebugAuth") {
      case "welcome": return .some(nil)
      case "login": return .login
      case "register": return .register
      case "otp": return .otp(email: "ornek@email.com", password: nil)
      case "forgot": return .forgot
      case "reset": return .reset(email: "ornek@email.com")
      default: return nil
      }
    #else
      return nil
    #endif
  }

  ///   -SalahDebugRoute settings|profile|account|location → Ana sayfa yığınında ekranı açar
  static var route: HomeRoute? {
    #if DEBUG
      switch UserDefaults.standard.string(forKey: "SalahDebugRoute") {
      case "settings": return .settings
      case "profile": return .profile
      case "account": return .account
      case "location": return .location
      case "password": return .changePassword
      case "qibla": return .qibla
      case "layout": return .layout
      case "calendar": return .calendar
      case "ozelGun": return .ozelGun
      case "dua": return .dua
      case "esma": return .esma
      case "hutbe": return .hutbe
      case "history": return .history
      case "admin": return .admin
      case "adminUsers": return .adminUsers
      case "adminDetail": return .adminUser("preview-user")
      case "adminRoles": return .adminRoles
      case "adminSelf": return .adminUser(AuthStore.shared.user?.id ?? "")
      case "alarms": return .alarms
      default: return nil
      }
    #else
      return nil
    #endif
  }

  ///   -SalahDebugDua category|detail|share → Dua ekranında sayfayı açar (rota `dua`)
  static var dua: String? {
    #if DEBUG
      return UserDefaults.standard.string(forKey: "SalahDebugDua")
    #else
      return nil
    #endif
  }

  ///   -SalahDebugEsma detail|share → Esmaül Hüsna penceresini açar (rota `esma`)
  static var esma: String? {
    #if DEBUG
      return UserDefaults.standard.string(forKey: "SalahDebugEsma")
    #else
      return nil
    #endif
  }

  static var form: ActivityType? {
    #if DEBUG
      return UserDefaults.standard.string(forKey: "SalahDebugForm").flatMap(ActivityType.init(rawValue:))
    #else
      return nil
    #endif
  }
}

#if DEBUG
  /// Paylaşım görsellerinin örnek veriyle önizlemesi (yalnız Debug).
  private struct DebugSharePreview: View {
    let kind: String

    var body: some View {
      let names = Localizer.shared.list("common.weekdaysShort")
      switch kind {
      case "streak":
        StreakShareSheet(
          streak: 42, longest: 57,
          week: [5, 5, 3, 5, 5, 0, 2].enumerated().map { i, n in WeekDay(label: names.indices.contains(i) ? names[i] : "", isToday: i == 6, count: n) })
      case "recap":
        RecapShareSheet(
          recap: .init(
            period: "week", from: "2026-10-12", to: "2026-10-18", days: 7, prayers: 31, possiblePrayers: 35, kaza: 2, perfectDays: 5,
            byPrayerTime: ["fajr": 5, "dhuhr": 7, "asr": 7, "maghrib": 7, "isha": 5], quranPages: 24, activities: [:], currentStreak: 12, highestStreak: 30),
          range: "12 - 18")
      case "cuma":
        GreetingShareSheet(kind: .cuma, dateText: GreetingKind.dateText(Date()))
      default:
        let k = GreetingKind(rawValue: kind) ?? .bayram
        GreetingShareSheet(kind: k, dayName: t(k == .kandil ? "religiousDays.berat" : "religiousDays.ramazan_bayram_1"), dateText: GreetingKind.dateText(Date()))
      }
    }
  }
#endif
