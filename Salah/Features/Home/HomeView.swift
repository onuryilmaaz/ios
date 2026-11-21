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
  @State private var homeVisible = false
  @State private var tintClock = Date()
  @State private var screenSize: CGSize = .zero

  var body: some View {
    NavigationStack(path: $nav.path) {
      content
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: HomeRoute.self) { $0.destination }
    }
    .onChange(of: nav.path.count) { old, new in
      if new > old, let route = nav.path.last { UsageStore.shared.record("screen.\(route.usageName)") }
    }
    .fullScreenCover(item: Binding(get: { celebrationStreak.map(Celebration.init) }, set: { celebrationStreak = $0?.streak })) { c in
      StreakCelebration(streak: c.streak) {
        celebrationStreak = nil
        // Kutlama kapanınca (olumlu an) değerlendirme penceresi; kendi sınırları var.
        Task { await StoreReview.maybeRequest(streak: c.streak) }
      }
        .presentationBackground(.clear)
    }
    .transaction { if celebrationStreak != nil { $0.disablesAnimations = true } }
  }

  private var content: some View {
    let auth = AuthStore.shared
    let hero = ramadanHero
    return Group {
      if ReadableLayout.isSplit(screenSize) { splitLayout(hero) } else { stackedLayout(hero) }
    }
    .onGeometryChange(for: CGSize.self) { $0.size } action: { screenSize = $0 }
    .background(tokens.canvas)
    .background {
      IftarMomentHost(
        today: model.today,
        blocked: !homeVisible || !nav.path.isEmpty || AuthFlow.shared.isPresented || TourStore.shared.tour != nil || celebrationStreak != nil
      )
    }
    .onAppear { homeVisible = true }
    .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { tintClock = $0 }
    .onDisappear { homeVisible = false }
    // Başlık her iki temada da koyu zümrüt: durum çubuğu yazıları açık.
    .statusBar(.light)
    .task { await refresh() }
    // İlk açılışta (güncelleme alanlar dahil) bir kez ana sayfa turu; misafirken gördüyse girişten sonra
    // yalnız girişle gelen kartların kısa turu.
    .task(id: HomeTourTrigger(nonce: TourStore.shared.replayNonce, signedIn: auth.isAuthenticated, idle: TourStore.shared.tour == nil)) {
      let store = TourStore.shared
      let signedIn = auth.isAuthenticated
      let tour: Tour? =
        !store.isDone("home") ? .home(signedIn: signedIn)
        : signedIn && !store.isDone(Tour.homeAccount.id) ? .homeAccount
        : !store.isDone(Tour.homeNew.id) ? .homeNew
        : HomeLayoutStore.shared.isVisible(.prayerLock) && !store.isDone(Tour.homePrayerLock.id) ? .homePrayerLock : nil
      guard let tour else { return }
      await store.startIfNeeded(tour) {
        let anchors = TourStore.shared.anchors
        let screenReady =
          switch tour.id {
          case "home": anchors["home.hero"] != nil && anchors["home.location"] != nil
          case "homeAccount": anchors["home.streak"] != nil || anchors["home.quickActions"] != nil
          default: anchors["home.layout"] != nil
          }
        return screenReady && nav.path.isEmpty && !AuthFlow.shared.isPresented && celebrationStreak == nil
      }
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { Task { await refresh() } }
    }
    .onChange(of: LocationChanges.shared.nonce) { Task { await model.load() } }
    .onChange(of: AuthStore.shared.user) { Task { await OzelGunStore.shared.fetch() } }
  }

  private func header(_ hero: Color) -> some View {
    HomeHeader(
      color: hero,
      onQibla: { push(.qibla) },
      onProfile: { AuthStore.shared.isAuthenticated ? push(.profile) : AuthFlow.shared.present() }
    )
  }

  private var heroCard: some View {
    HomeHero(
      today: model.today, isLoading: model.isLoading, locationName: model.locationName,
      onLocation: { push(.location) },
      onAlarms: { push(.alarms) },
      onImsakiye: { push(.imsakiye) }
    )
  }

  /// Telefon ve geniş dikey ekran: başlık, vakit kartı ve kartlar tek sütunda (genişte ortalı).
  private func stackedLayout(_ hero: Color) -> some View {
    VStack(spacing: 0) {
      header(hero)
      ScrollViewReader { proxy in
        ScrollView {
          VStack(spacing: 0) {
            heroCard
              .readableColumn()
              .background(alignment: .top) {
                // Aşağı çekince (bounce) üstte açık zemin görünmesin.
                hero.frame(height: 600).offset(y: -600)
              }
              .background(hero, in: UnevenRoundedRectangle(bottomLeadingRadius: 32, bottomTrailingRadius: 32))
              .animation(.easeInOut(duration: 0.3), value: hero)
              .tourAnchor("home.hero")
              .padding(.bottom, 17.5)
            cards.readableColumn()
          }
          .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .refreshable { await refresh() }
        .tourScroll(proxy, top: "home.hero")
      }
    }
  }

  /// Geniş yatay ekran (Duo açık): solda sabit vakit paneli, sağda kayan kartlar.
  private func splitLayout(_ hero: Color) -> some View {
    HStack(spacing: 0) {
      VStack(spacing: 0) {
        header(hero)
        GeometryReader { panel in
          ScrollView {
            // Panelde dikey ortalanır; sığmazsa kayar.
            heroCard.tourAnchor("home.hero")
              .frame(minHeight: panel.size.height)
          }
          .scrollIndicators(.hidden)
          .scrollBounceBehavior(.basedOnSize)
        }
      }
      .frame(width: ReadableLayout.splitPanelWidth)
      .background(hero.ignoresSafeArea())
      .animation(.easeInOut(duration: 0.3), value: hero)

      ScrollViewReader { proxy in
        ScrollView {
          cards
            .readableColumn()
            .padding(.top, 17.5)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .refreshable { await refresh() }
        .tourScroll(proxy, top: nil)
      }
    }
  }

  /// Vakit kartının altındaki kartlar ve düzen düğmesi.
  private var cards: some View {
    let auth = AuthStore.shared
    let layout = HomeLayoutStore.shared
    return VStack(spacing: 0) {
      MuteBanner()
      AnnouncementBanners()
      ForbiddenTimeBanner(times: model.today?.times)
      CumaCard(onOpen: AppControlStore.shared.isOn("hutbe") ? { push(.hutbe) } : nil)
      RamadanCard(today: model.today, onImsakiye: { push(.imsakiye) }, onHatim: { push(.hatimPlan) }, onJournal: { push(.fastJournal) })
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
      .tourAnchor("home.layout")
      .padding(.top, 3.5)
    }
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
      if isAuthenticated { StreakCard(onCircles: StreakCircleAPI.available ? { push(.circles) } : nil).tourAnchor("home.streak") }
    case .quickActions:
      if isAuthenticated { QuickActionsCard { push($0) }.tourAnchor("home.quickActions") }
    case .dailyInspiration:
      DailyInspirationCard()
    case .dayRing:
      if let times = model.today?.times { DayRingCard(times: times) }
    case .alarms:
      if AppControlStore.shared.isOn("alarms") { AlarmsCard { push(.alarms) } }
    case .kaza:
      if KazaStore.shared.available { KazaCard { push(.kaza) }.tourAnchor("home.kaza") }
    case .dhikr:
      if AppControlStore.shared.isOn("dhikr") { DhikrCard { push(.dhikr) }.tourAnchor("home.dhikr") }
    case .prayerLock:
      #if PRAYER_LOCK
      PrayerLockCard { push(.prayerLock) }.tourAnchor("home.prayerLock")
      #else
      EmptyView()
      #endif
    }
  }

  /// Ramazan gününde üst alan rengi saate göre değişir; gerisi temada kalır.
  private var ramadanHero: Color {
    let window = RamadanSchedule.window(ReligiousCalendarService.cached())
    if case .active = RamadanSchedule.phase(window, today: model.today?.times) { return RamadanTint.current(model.today?.times, now: tintClock).hero }
    return tokens.hero
  }

  private func push(_ route: HomeRoute) {
    nav.path.append(route)
  }

  private struct HomeTourTrigger: Equatable {
    let nonce: Int
    let signedIn: Bool
    let idle: Bool
  }

  private struct Celebration: Identifiable {
    let streak: Int
    var id: Int { streak }
  }

  private func refresh() async {
    Task { await HatimPlanStore.shared.sync() }
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
