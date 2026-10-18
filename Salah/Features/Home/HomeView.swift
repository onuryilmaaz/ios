import SwiftUI

/// Ana sayfa. RN: screens/user/HomeScreen.tsx
@Observable
final class HomeModel {
  private(set) var today: PrayerDay?
  private(set) var isLoading = false
  private(set) var locationName = ""
  @ObservationIgnored private var inspirationFilledOn = ""

  func load() async {
    let districtId = Locations.selectedDistrictId
    locationName = Locations.selectedDisplayName
    if today == nil { isLoading = true }
    defer { isLoading = false }
    if let day = await PrayerTimesService.today(districtId: districtId) { today = day }
    WidgetSync.updatePrayer(today?.times)
    // Kilit ekranı ilham widget'ı kart gizliyken de dolsun (kart görünürse kendisi yazar).
    if inspirationFilledOn != localDateString(),
      !HomeLayoutStore.shared.sections.contains(where: { $0.key == .dailyInspiration && $0.visible })
    {
      inspirationFilledOn = localDateString()
      await InspirationModel().load()
    }
  }
}

/// Ana sayfa yığınının yolu; başka sekmeler de (giriş duvarı) buraya ekran itebilir.
@Observable
final class HomeNavigation {
  static let shared = HomeNavigation()
  var path: [HomeRoute] = []
}

struct HomeView: View {
  @Environment(\.tokens) private var tokens
  @Environment(\.scenePhase) private var scenePhase
  @State private var model = HomeModel()
  @Bindable private var nav = HomeNavigation.shared
  @State private var celebrationStreak: Int?

  var body: some View {
    NavigationStack(path: $nav.path) {
      content
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: HomeRoute.self) { $0.destination }
    }
    .fullScreenCover(item: Binding(get: { celebrationStreak.map(Celebration.init) }, set: { celebrationStreak = $0?.streak })) { c in
      StreakCelebration(streak: c.streak) { celebrationStreak = nil }
        .presentationBackground(.clear)
    }
    .transaction { if celebrationStreak != nil { $0.disablesAnimations = true } }
  }

  private var content: some View {
    let auth = AuthStore.shared
    let layout = HomeLayoutStore.shared
    return VStack(spacing: 0) {
      HomeHeader(
        onQibla: { push(.qibla) },
        onProfile: { auth.isAuthenticated ? push(.profile) : AuthFlow.shared.present() }
      )
      ScrollView {
        VStack(spacing: 0) {
          PrayerHeroCard(
            today: model.today, isLoading: model.isLoading, locationName: model.locationName,
            onLocation: { push(.location) },
            onAlarms: { push(.alarms) }
          )
          .background(alignment: .top) {
            // Aşağı çekince (bounce) üstte açık zemin görünmesin.
            tokens.hero.frame(height: 600).offset(y: -600)
          }
          .background(tokens.hero, in: UnevenRoundedRectangle(bottomLeadingRadius: 32, bottomTrailingRadius: 32))
          .padding(.bottom, 17.5)

          MuteBanner()
          ForbiddenTimeBanner(times: model.today?.times)
          CumaCard { push(.hutbe) }
          HolidayGreetingCard()

          if NotificationNavigation.shared.inspiration != nil, !layout.sections.contains(where: { $0.key == .dailyInspiration && $0.visible }) {
            DailyInspirationCard()
          }
          ForEach(layout.sections.filter(\.visible), id: \.key) { section in
            sectionView(section.key, isAuthenticated: auth.isAuthenticated)
          }

          Button {
            Haptics.impact(.light)
            push(.layout)
          } label: {
            HStack(spacing: 5.25) {
              Ionicon("options-outline", size: 16, color: tokens.inkMuted)
              Text(t("home.editLayout"))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(tokens.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8.75)
          }
          .buttonStyle(PressableStyle(pressedOpacity: 0.6))
          .padding(.top, 3.5)
        }
        .padding(.bottom, 24)
      }
      .scrollIndicators(.hidden)
      .refreshable { await refresh() }
    }
    .background(tokens.canvas)
    // Başlık her iki temada da koyu zümrüt: durum çubuğu yazıları açık.
    .statusBar(.light)
    .task { await refresh() }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { Task { await refresh() } }
    }
    .onChange(of: LocationChanges.shared.nonce) { Task { await model.load() } }
    .onChange(of: AuthStore.shared.user) { Task { await OzelGunStore.shared.fetch() } }
  }

  @ViewBuilder
  private func sectionView(_ key: HomeLayoutStore.Key, isAuthenticated: Bool) -> some View {
    switch key {
    case .prayerTracker:
      PrayerTrackerCard(
        times: model.today?.times,
        onAuthRequired: { AuthFlow.shared.present() },
        onCelebrate: { celebrationStreak = $0 }
      )
    case .streak:
      if isAuthenticated { StreakCard() }
    case .quickActions:
      if isAuthenticated { QuickActionsCard { push($0) } }
    case .dailyInspiration:
      DailyInspirationCard()
    case .dayRing:
      if let times = model.today?.times { DayRingCard(times: times) }
    case .alarms:
      AlarmsCard { push(.alarms) }
    }
  }

  private func push(_ route: HomeRoute) {
    nav.path.append(route)
  }

  private struct Celebration: Identifiable {
    let streak: Int
    var id: Int { streak }
  }

  private func refresh() async {
    GamificationStore.shared.ensureFreshToday()
    async let times: Void = model.load()
    if AuthStore.shared.isAuthenticated {
      async let stats: Void = GamificationStore.shared.fetchStats()
      async let period: Void = OzelGunStore.shared.fetch()
      _ = await (times, stats, period)
    } else {
      await times
    }
  }
}
