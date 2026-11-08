import SwiftUI

/// Web panelinden gelen modül durumu ve duyuruların saf hesabı.
enum AppControlLogic {
  struct Schedule: Codable, Equatable, Sendable {
    var from: String
    var to: String?
    var enabled: Bool
  }
  struct ModuleState: Codable, Equatable, Sendable {
    var enabled: Bool
    var schedule: Schedule?
    /** Kapalıyken de yönetici hesaplarında açık. */
    var adminPreview: Bool?
    /** Platforma göre kapalı sürümler. */
    var blockedVersions: [String: [String]]?
  }
  struct Maintenance: Codable, Equatable, Sendable {
    var active: Bool
    var title: [String: String]
    var body: [String: String]
    var platforms: [String]
    var startsAt: String
    var endsAt: String?
  }
  struct Announcement: Codable, Equatable, Sendable, Identifiable {
    var id: String
    var title: [String: String]
    var body: [String: String]
    var kind: String
    var platforms: [String]
    var frequency: String
    var startsAt: String
    var endsAt: String?
    var actionLabel: [String: String]?
    var actionUrl: String?
    /// "popup" ya da "banner" (ana sayfa bandı).
    var display: String?
    /// Boş: tüm diller.
    var languages: [String]?
    /// "all", "signed_in" ya da "guests".
    var audience: String?
    /// Platforma göre en düşük uygulama sürümü.
    var minVersions: [String: String]?
  }

  /// Panelden yönetilen içerik: günlere atanan ayet/hadis, tebrik metinleri, hutbe düzeltmeleri (metinsiz).
  struct Content: Codable, Equatable, Sendable {
    struct Daily: Codable, Equatable, Sendable {
      var date: String
      var kind: String
      var text: [String: String]
      var arabic: String
      var source: [String: String]
    }
    struct Hutbe: Codable, Equatable, Sendable {
      var id: String
      var lang: String
      var date: String
      var updatedAt: String
    }
    var daily: [Daily]?
    var greetings: [String: [String: String]]?
    var hutbe: [Hutbe]?
  }

  /// Hedeflemenin bu cihazdaki karşılığı.
  struct Viewer: Equatable, Sendable {
    var language: String
    var signedIn: Bool
    var version: String
  }

  static func date(_ text: String) -> Date? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let value = formatter.date(from: text) { return value }
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: text)
  }

  /// Satırı olmayan modül açıktır. Aralığın içindeyken aralığın değeri, dışındayken ana değer geçerlidir.
  static func isOn(_ state: ModuleState?, now: Date) -> Bool {
    guard let state else { return true }
    if let schedule = state.schedule, let from = date(schedule.from), now >= from {
      if let raw = schedule.to, let to = date(raw) {
        if now < to { return schedule.enabled }
      } else {
        return schedule.enabled
      }
    }
    return state.enabled
  }

  /// Zamanlama ve sürüm engeli, sonra yöneticiye açıklık. Sunucudaki `moduleVisible` ile aynı.
  static func visible(_ state: ModuleState?, now: Date, platform: String, version: String, admin: Bool) -> Bool {
    guard let state else { return true }
    let blocked = (state.blockedVersions?[platform] ?? []).contains { UpdatePolicy.compare($0, version) == 0 }
    return (isOn(state, now: now) && !blocked) || (admin && state.adminPreview == true)
  }

  static func maintenanceActive(_ m: Maintenance?, platform: String, now: Date) -> Bool {
    guard let m, m.active, m.platforms.contains(platform), let start = date(m.startsAt), start <= now else { return false }
    if let raw = m.endsAt, let end = date(raw) { return end > now }
    return true
  }

  /// Platform, yayın aralığı ve hedefleme (dil, giriş durumu, en düşük sürüm).
  static func eligible(_ item: Announcement, platform: String, now: Date, viewer: Viewer?) -> Bool {
    guard item.platforms.contains(platform), let start = date(item.startsAt), start <= now else { return false }
    if let raw = item.endsAt, let end = date(raw), end <= now { return false }
    guard let viewer else { return true }
    if let languages = item.languages, !languages.isEmpty, !languages.contains(viewer.language) { return false }
    switch item.audience {
    case "signed_in": if !viewer.signedIn { return false }
    case "guests": if viewer.signedIn { return false }
    default: break
    }
    if let min = item.minVersions?[platform], !min.isEmpty, UpdatePolicy.compare(viewer.version, min) < 0 { return false }
    return true
  }

  /// Bu platformda şimdi gösterilebilecek, daha önce görülmemiş ilk pencere duyurusu.
  static func next(_ list: [Announcement], platform: String, now: Date, seen: Set<String>, viewer: Viewer? = nil) -> Announcement? {
    list.first { $0.display != "banner" && !seen.contains($0.id) && eligible($0, platform: platform, now: now, viewer: viewer) }
  }

  /// Ana sayfa bantları: kapatılmamış olanlar.
  static func banners(_ list: [Announcement], platform: String, now: Date, dismissed: Set<String>, viewer: Viewer?) -> [Announcement] {
    list.filter { $0.display == "banner" && !dismissed.contains($0.id) && eligible($0, platform: platform, now: now, viewer: viewer) }
  }

  /// Seçili dilde metin yoksa Türkçesi.
  static func text(_ value: [String: String], language: String) -> String {
    if let own = value[language]?.trimmingCharacters(in: .whitespacesAndNewlines), !own.isEmpty { return own }
    return value["tr"] ?? ""
  }

  static func isAllowedLink(_ url: String) -> Bool {
    url.hasPrefix("https://") || url.hasPrefix("salah://")
  }
}

/// `/app/config` içindeki uzak ayarlar. Mağaza sürümü gerektirmez: açılışta, her öne gelişte ve açıkken 5 dakikada bir okunur.
/// Okunamazsa son bilinen ayar, o da yoksa her modül açık kabul edilir: bu katman uygulamayı asla kilitlemez.
@MainActor
@Observable
final class AppControlStore {
  static let shared = AppControlStore()
  private static let key = "@salah_app_control_v1"
  private static let seenKey = "@salah_announcements_seen_v1"
  private static let dismissedKey = "@salah_banners_dismissed_v1"
  private static let viewedKey = "@salah_announcement_views_v1"
  private static let refreshInterval: TimeInterval = 300
  /// Bildirim merkezi gibi kısa geçişler aynı ayarı tekrar tekrar istemesin.
  private static let foregroundInterval: TimeInterval = 15

  struct Snapshot: Codable, Equatable {
    var modules: [String: AppControlLogic.ModuleState]?
    var announcements: [AppControlLogic.Announcement]?
    var content: AppControlLogic.Content?
  }

  private struct Config: Decodable {
    var modules: [String: AppControlLogic.ModuleState]?
    var announcements: [AppControlLogic.Announcement]?
    var ios: UpdatePolicy.Server?
    var maintenance: AppControlLogic.Maintenance?
    var content: AppControlLogic.Content?
  }

  private(set) var snapshot: Snapshot
  /// Yalnız sunucudan bu açılışta okunan bakım: ağ yoksa ekran açılmaz.
  private(set) var maintenance: AppControlLogic.Maintenance?
  /// Yönetici bakım ekranını bu açılış için geçti.
  private(set) var maintenanceDismissed = false
  private(set) var isRetrying = false
  /// Kapatılan bantlar (kalıcı).
  private(set) var dismissedBanners = Set(LocalStore.decode([String].self, AppControlStore.dismissedKey) ?? [])
  /// Zaman aralığı başlayınca ekranlar yeniden çizilsin diye dakikada bir değişir.
  private(set) var now = Date()
  @ObservationIgnored private var lastFetch: Date?
  @ObservationIgnored private var shownThisLaunch = Set<String>()

  private init() {
    #if DEBUG
    if let raw = UserDefaults.standard.string(forKey: "SalahDebugControl"), let data = Data(base64Encoded: raw), let value = try? JSONDecoder().decode(Config.self, from: data) {
      snapshot = Snapshot(modules: value.modules, announcements: value.announcements, content: value.content)
      maintenance = value.maintenance
      return
    }
    #endif
    snapshot = LocalStore.decode(Snapshot.self, Self.key) ?? Snapshot()
  }

  func isOn(_ module: String) -> Bool {
    AppControlLogic.visible(snapshot.modules?[module], now: now, platform: "ios", version: UpdateGate.currentVersion,
      admin: AuthStore.shared.user?.roles?.contains("admin") == true)
  }

  /// Bakım ekranı şimdi görünür mü (zamanlama dakikada bir yeniden hesaplanır).
  var showsMaintenance: Bool {
    !maintenanceDismissed && AppControlLogic.maintenanceActive(maintenance, platform: "ios", now: now)
  }

  func retryMaintenance() async {
    guard !isRetrying else { return }
    isRetrying = true
    await refresh()
    now = Date()
    isRetrying = false
  }

  func dismissMaintenance() { maintenanceDismissed = true }

  /// Panelde bu güne atanmış ayet ya da hadis.
  func dailyItem(for date: String) -> AppControlLogic.Content.Daily? {
    snapshot.content?.daily?.first { $0.date == date }
  }

  /// Panelde değiştirilmiş tebrik metni (seçili dil, yoksa Türkçe).
  func greeting(_ kind: String) -> String? {
    guard let message = snapshot.content?.greetings?[kind] else { return nil }
    let text = AppControlLogic.text(message, language: Localizer.shared.language.rawValue)
    return text.isEmpty ? nil : text
  }

  /// O Cuma ve dil için yayınlanmış düzeltilmiş hutbe.
  func hutbeOverride(lang: String, date: String) -> AppControlLogic.Content.Hutbe? {
    snapshot.content?.hutbe?.first { $0.lang == lang && $0.date == date }
  }

  private var viewer: AppControlLogic.Viewer {
    .init(language: Localizer.shared.language.rawValue, signedIn: AuthStore.shared.isAuthenticated, version: UpdateGate.currentVersion)
  }

  /// Ana sayfada gösterilecek bantlar.
  var banners: [AppControlLogic.Announcement] {
    AppControlLogic.banners(snapshot.announcements ?? [], platform: "ios", now: now, dismissed: dismissedBanners, viewer: viewer)
  }

  func dismissBanner(_ item: AppControlLogic.Announcement) {
    dismissedBanners.insert(item.id)
    LocalStore.encode(Array(dismissedBanners.suffix(100)), for: Self.dismissedKey)
    record(item.id, "dismiss")
  }

  func openBanner(_ item: AppControlLogic.Announcement) {
    guard let raw = item.actionUrl, AppControlLogic.isAllowedLink(raw), let url = URL(string: raw) else { return }
    record(item.id, "tap")
    UIApplication.shared.open(url)
  }

  /// Görülme cihaz başına bir kez sayılır.
  func markViewed(_ id: String) {
    var viewed = LocalStore.decode([String].self, Self.viewedKey) ?? []
    guard !viewed.contains(id) else { return }
    viewed.append(id)
    LocalStore.encode(Array(viewed.suffix(200)), for: Self.viewedKey)
    record(id, "view")
  }

  /// Panel sayaçları; hata olursa sessizce geçilir.
  private func record(_ id: String, _ type: String) {
    guard !DebugLaunch.isIsolated else { return }
    Task { _ = try? await APIClient.shared.send("POST", "/app/announcements/\(id)/event", body: ["type": .string(type)]) }
  }

  /// Uygulama öndeyken çalışır; sahne arka plana geçince görev iptal edilir.
  func run() async {
    var interval = Self.foregroundInterval
    while !Task.isCancelled {
      now = Date()
      if lastFetch.map({ now.timeIntervalSince($0) >= interval }) ?? true { await refresh() }
      interval = Self.refreshInterval
      if !showsMaintenance {
        UpdateGate.shared.presentPending()
        presentNext()
      }
      try? await Task.sleep(for: .seconds(60))
    }
  }

  private func refresh() async {
    #if DEBUG
    if UserDefaults.standard.string(forKey: "SalahDebugControl") != nil { return }
    #endif
    guard !DebugLaunch.isIsolated, let fresh = try? await APIClient.shared.get("/app/config", as: Config.self) else { return }
    lastFetch = Date()
    if let server = fresh.ios { UpdateGate.shared.apply(UpdatePolicy.evaluate(current: UpdateGate.currentVersion, server)) }
    maintenance = fresh.maintenance
    // Sunucu ayarları okuyamadıysa alanlar gelmez: elde olan korunur.
    guard fresh.modules != nil || fresh.announcements != nil else { return }
    let next = Snapshot(modules: fresh.modules, announcements: fresh.announcements, content: fresh.content)
    snapshot = next
    LocalStore.encode(next, for: Self.key)
  }

  private var seen: Set<String> {
    Set((LocalStore.decode([String].self, Self.seenKey) ?? [])).union(shownThisLaunch)
  }

  private func presentNext() {
    guard AlertCenter.shared.current == nil, !AuthFlow.shared.isPresented, TourStore.shared.tour == nil, OnboardingStore.shared.done,
      let item = AppControlLogic.next(snapshot.announcements ?? [], platform: "ios", now: now, seen: seen, viewer: viewer)
    else { return }
    shownThisLaunch.insert(item.id)
    if item.frequency == "once" {
      // Liste sınırlı kalsın: yalnız yakın zamanda görülenler tutulur.
      LocalStore.encode(Array(((LocalStore.decode([String].self, Self.seenKey) ?? []) + [item.id]).suffix(100)), for: Self.seenKey)
    }
    let language = Localizer.shared.language.rawValue
    markViewed(item.id)
    var buttons: [AppAlert.Button] = []
    if let raw = item.actionUrl, AppControlLogic.isAllowedLink(raw), let url = URL(string: raw), let label = item.actionLabel {
      buttons.append(.init(text: AppControlLogic.text(label, language: language)) { [weak self] in
        self?.record(item.id, "tap")
        UIApplication.shared.open(url)
      })
    }
    buttons.append(.init(text: t("common.ok"), style: buttons.isEmpty ? .default : .cancel) { [weak self] in self?.record(item.id, "dismiss") })
    AppAlert.show(item.kind == "warning" ? .warning : .info, AppControlLogic.text(item.title, language: language), AppControlLogic.text(item.body, language: language), buttons: buttons)
  }
}

/// Kapalı modülün yerine görünür. Ana sayfa yığınında geri düğmesi, sekmede başlıksız.
struct ModuleClosedView: View {
  @Environment(\.tokens) private var tokens
  var showBack = true

  var body: some View {
    VStack(spacing: 0) {
      if showBack { StandardHeader(title: "") }
      Spacer()
      EmptyState(icon: "lock-closed-outline", title: t("module.closedTitle"), message: t("module.closedBody")) { EmptyView() }
      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(tokens.canvas)
    .toolbar(.hidden, for: .navigationBar)
  }
}

/// Sekme içeriğini modül durumuna bağlar.
struct ModuleGated<Content: View>: View {
  let module: String
  @ViewBuilder var content: Content

  init(_ module: String, @ViewBuilder content: () -> Content) {
    self.module = module
    self.content = content()
  }

  var body: some View {
    if AppControlStore.shared.isOn(module) { content } else { ModuleClosedView(showBack: false) }
  }
}

/// Panelden açılan bakım ekranı. Metin panelden gelir; yönetici geçip uygulamayı kullanabilir.
struct MaintenanceView: View {
  @Environment(\.tokens) private var tokens
  let maintenance: AppControlLogic.Maintenance

  var body: some View {
    let store = AppControlStore.shared
    let language = Localizer.shared.language.rawValue
    VStack(spacing: 0) {
      Spacer()
      EmptyState(icon: "construct-outline", title: AppControlLogic.text(maintenance.title, language: language), message: message(language)) {
        VStack(spacing: 10.5) {
          AppButton(title: t("maintenance.retry"), variant: .primary, loading: store.isRetrying) {
            Haptics.impact(.medium)
            Task { await store.retryMaintenance() }
          }
          if AuthStore.shared.user?.roles?.contains("admin") == true {
            AppButton(title: t("maintenance.continueAdmin"), variant: .outline) {
              Haptics.impact(.light)
              store.dismissMaintenance()
            }
          }
        }
      }
      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(tokens.canvas)
    .contentShape(.rect)
    .accessibilityAddTraits(.isModal)
  }

  private func message(_ language: String) -> String {
    let body = AppControlLogic.text(maintenance.body, language: language)
    guard let raw = maintenance.endsAt, let end = AppControlLogic.date(raw) else { return body }
    let time = end.formatted(.dateTime.day().month(.abbreviated).hour().minute().locale(Localizer.shared.locale))
    return body + "\n\n" + t("maintenance.until", ["time": time])
  }
}

/// Ana sayfadaki duyuru bantları: panelde "Ana sayfa bandı" seçilen duyurular, kapatılana kadar.
struct AnnouncementBanners: View {
  @Environment(\.tokens) private var tokens

  var body: some View {
    let store = AppControlStore.shared
    let language = Localizer.shared.language.rawValue
    ForEach(store.banners, id: \.id) { item in
      let warning = item.kind == "warning"
      HStack(alignment: .top, spacing: 10.5) {
        Ionicon(warning ? "alert-circle-outline" : "megaphone-outline", size: 20, color: warning ? Gold.s600 : tokens.accent)
          .frame(width: 35, height: 35)
          .background(warning ? Gold.s100.opacity(tokens.isDark ? 0.15 : 1) : (tokens.isDark ? Accent.s900 : Accent.s50), in: .circle)
        VStack(alignment: .leading, spacing: 1.75) {
          Text(AppControlLogic.text(item.title, language: language)).font(.system(size: 15, weight: .semibold)).foregroundStyle(tokens.textPrimary)
          Text(AppControlLogic.text(item.body, language: language)).font(.system(size: 13)).foregroundStyle(tokens.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
          if let label = item.actionLabel, item.actionUrl != nil {
            Button {
              Haptics.impact(.light)
              store.openBanner(item)
            } label: {
              Text(AppControlLogic.text(label, language: language)).font(.system(size: 13, weight: .semibold)).foregroundStyle(tokens.accent)
                .padding(.horizontal, 14).padding(.vertical, 7).background(tokens.fill, in: .capsule)
            }
            .buttonStyle(PressableStyle()).padding(.top, 7)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        Button {
          Haptics.impact(.light)
          withAnimation(.easeOut(duration: 0.2)) { store.dismissBanner(item) }
        } label: {
          Ionicon("close", size: 18, color: tokens.inkSubtle).frame(width: 44, height: 44)
        }
        .buttonStyle(PressableStyle()).accessibilityLabel(t("common.close"))
        .padding(.top, -10).padding(.trailing, -10)
      }
      .padding(17.5)
      .background(tokens.surface, in: .rect(cornerRadius: 21))
      .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
      .padding(.horizontal, 14).padding(.bottom, 10.5)
      .onAppear { store.markViewed(item.id) }
    }
  }
}
