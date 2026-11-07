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

  /// Bu platformda şimdi gösterilebilecek, daha önce görülmemiş ilk duyuru.
  static func next(_ list: [Announcement], platform: String, now: Date, seen: Set<String>) -> Announcement? {
    list.first { item in
      guard item.platforms.contains(platform), !seen.contains(item.id), let start = date(item.startsAt), start <= now else { return false }
      if let raw = item.endsAt, let end = date(raw), end <= now { return false }
      return true
    }
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
  private static let refreshInterval: TimeInterval = 300
  /// Bildirim merkezi gibi kısa geçişler aynı ayarı tekrar tekrar istemesin.
  private static let foregroundInterval: TimeInterval = 15

  struct Snapshot: Codable, Equatable {
    var modules: [String: AppControlLogic.ModuleState]?
    var announcements: [AppControlLogic.Announcement]?
  }

  private struct Config: Decodable {
    var modules: [String: AppControlLogic.ModuleState]?
    var announcements: [AppControlLogic.Announcement]?
    var ios: UpdatePolicy.Server?
  }

  private(set) var snapshot: Snapshot
  /// Zaman aralığı başlayınca ekranlar yeniden çizilsin diye dakikada bir değişir.
  private(set) var now = Date()
  @ObservationIgnored private var lastFetch: Date?
  @ObservationIgnored private var shownThisLaunch = Set<String>()

  private init() {
    #if DEBUG
    if let raw = UserDefaults.standard.string(forKey: "SalahDebugControl"), let data = Data(base64Encoded: raw), let value = try? JSONDecoder().decode(Snapshot.self, from: data) {
      snapshot = value
      return
    }
    #endif
    snapshot = LocalStore.decode(Snapshot.self, Self.key) ?? Snapshot()
  }

  func isOn(_ module: String) -> Bool {
    AppControlLogic.isOn(snapshot.modules?[module], now: now)
  }

  /// Uygulama öndeyken çalışır; sahne arka plana geçince görev iptal edilir.
  func run() async {
    var interval = Self.foregroundInterval
    while !Task.isCancelled {
      now = Date()
      if lastFetch.map({ now.timeIntervalSince($0) >= interval }) ?? true { await refresh() }
      interval = Self.refreshInterval
      UpdateGate.shared.presentPending()
      presentNext()
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
    // Sunucu ayarları okuyamadıysa alanlar gelmez: elde olan korunur.
    guard fresh.modules != nil || fresh.announcements != nil else { return }
    let next = Snapshot(modules: fresh.modules, announcements: fresh.announcements)
    snapshot = next
    LocalStore.encode(next, for: Self.key)
  }

  private var seen: Set<String> {
    Set((LocalStore.decode([String].self, Self.seenKey) ?? [])).union(shownThisLaunch)
  }

  private func presentNext() {
    guard AlertCenter.shared.current == nil, !AuthFlow.shared.isPresented, TourStore.shared.tour == nil, OnboardingStore.shared.done,
      let item = AppControlLogic.next(snapshot.announcements ?? [], platform: "ios", now: now, seen: seen)
    else { return }
    shownThisLaunch.insert(item.id)
    if item.frequency == "once" {
      // Liste sınırlı kalsın: yalnız yakın zamanda görülenler tutulur.
      LocalStore.encode(Array(((LocalStore.decode([String].self, Self.seenKey) ?? []) + [item.id]).suffix(100)), for: Self.seenKey)
    }
    let language = Localizer.shared.language.rawValue
    var buttons: [AppAlert.Button] = []
    if let raw = item.actionUrl, AppControlLogic.isAllowedLink(raw), let url = URL(string: raw), let label = item.actionLabel {
      buttons.append(.init(text: AppControlLogic.text(label, language: language)) { UIApplication.shared.open(url) })
    }
    buttons.append(.init(text: t("common.ok"), style: buttons.isEmpty ? .default : .cancel))
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
