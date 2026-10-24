import SwiftUI
import UIKit

/// Uygulama turu: ekranın gerçek öğelerini sırayla gösteren ipucu balonları.
///
/// Bir ekrana tur eklemek: öğeleri `.tourAnchor("quran.search")` ile işaretle, `Tour` tanımla (metinler
/// `tour.<adım anahtarı>.title|body`), ekran açılınca `TourStore.shared.startIfNeeded(...)`. Kaydırılan
/// içerikteki adımlar (`scroll`) `.tourScroll(proxy)` ile ekrana getirilir. Görünmeyen (gizli kart, ekran
/// dışında) öğelerin adımı atlanır. Tur bitince ya da geçilince bir daha kendiliğinden açılmaz; Ayarlar'dan
/// tekrar izlenebilir. Giriş isteyen sekmelerin turları ilk girişte açılır. Android `ui/Tour.kt` aynı yapı.
struct Tour: Sendable {
  struct Step: Sendable {
    /// `.tourAnchor` kimliği; `tabBar` sekme çubuğu.
    let anchor: String
    /// Balondaki Ionicons simgesi.
    let icon: String
    /// Kaydırılan içerikte: ekran dışında olsa da adım gösterilir, ekran ona kaydırılır.
    var scroll = false
    /// Metin anahtarı `tour.<text>.title|body`; verilmezse öğe kimliği.
    var key: String?

    var text: String { key ?? anchor }
  }

  let id: String
  let steps: [Step]
  /// Bitince birlikte görüldü sayılan turlar (girişliyken ana sayfa turu hesap adımlarını da içerir).
  var covers: [String] = []
  /// Tam ekran bir pencerenin (Mushaf) içinde gösterilir: katmanı o ekran kendisi çizer.
  var inline = false

  /// Ana sayfa; girişliyse seri ve kısayol adımları da eklenir.
  static func home(signedIn: Bool) -> Tour {
    let base: [Step] = [
      .init(anchor: "home.location", icon: "location"),
      .init(anchor: "home.hero", icon: "time-outline"),
      .init(anchor: "home.times", icon: "timer-outline"),
      .init(anchor: "home.tracker", icon: "checkmark-done-outline"),
      .init(anchor: "home.alarms", icon: "alarm-outline"),
    ]
    let tail: [Step] = [
      .init(anchor: "home.qibla", icon: "compass-outline"),
      .init(anchor: "home.profile", icon: "person-circle-outline"),
      .init(anchor: tabBarAnchor, icon: "apps-outline", key: "home.tabs"),
    ]
    return signedIn
      ? Tour(id: "home", steps: base + homeAccount.steps + tail, covers: [homeAccount.id])
      : Tour(id: "home", steps: base + tail)
  }

  /// Misafirken ana sayfa turunu görüp sonradan giriş yapana: yalnız girişle gelen kartlar.
  static let homeAccount = Tour(id: "homeAccount", steps: [
    .init(anchor: "home.streak", icon: "flame-outline", scroll: true),
    .init(anchor: "home.quickActions", icon: "grid-outline", scroll: true),
  ])

  static let quran = Tour(id: "quran", steps: [
    .init(anchor: "quran.search", icon: "search-outline"),
    .init(anchor: "quran.mushaf", icon: "book-outline"),
    .init(anchor: "quran.continue", icon: "bookmark-outline"),
    .init(anchor: "quran.list", icon: "list-outline"),
  ])

  static let tracker = Tour(id: "tracker", steps: [
    .init(anchor: "tracker.hero", icon: "today-outline"),
    .init(anchor: "tracker.activities", icon: "add-circle-outline"),
    .init(anchor: "tracker.insights", icon: "stats-chart-outline", scroll: true),
  ])

  static let assistant = Tour(id: "assistant", steps: [
    .init(anchor: "assistant.intro", icon: "sparkles-outline"),
    .init(anchor: "assistant.suggestions", icon: "chatbubbles-outline"),
    .init(anchor: "assistant.composer", icon: "create-outline"),
  ])

  /// Mushaf ilk açıldığında: sayfa hareketleri ve sure seçimi.
  static let mushaf = Tour(id: "mushaf", steps: [
    .init(anchor: "mushaf.page", icon: "swap-horizontal-outline"),
    .init(anchor: "mushaf.surahs", icon: "list-outline"),
  ], inline: true)

  /// Sor'da ilk cevap gelince: basılı tutup kopyalama.
  static let assistantChat = Tour(id: "assistantChat", steps: [
    .init(anchor: "assistant.copy", icon: "copy-outline", scroll: true),
  ])

  /// Alarmlar'da ilk özel alarm olunca: düzenleme ve silme.
  static let alarms = Tour(id: "alarms", steps: [
    .init(anchor: "alarms.custom", icon: "alarm-outline", scroll: true),
  ])

  static let allIds = ["home", "homeAccount", "quran", "tracker", "assistant", "mushaf", "assistantChat", "alarms"]
  static let tabBarAnchor = "tabBar"
}

@Observable
final class TourStore {
  static let shared = TourStore()

  private(set) var tour: Tour?
  /// Turun gösterilecek adımları (başlarken görünür olanlar).
  private(set) var steps: [Tour.Step] = []
  private(set) var index = 0
  /// Öğelerin pencere koordinatlarındaki yerleri.
  private(set) var anchors: [String: CGRect] = [:]

  var current: Tour.Step? { steps.indices.contains(index) ? steps[index] : nil }

  static func doneKey(_ id: String) -> String { "@salah_tour_\(id)_done" }

  func isDone(_ id: String) -> Bool {
    #if DEBUG
    // -SalahDebugTour YES: görülmüş olsa da her tur açılır (doğrulama).
    if UserDefaults.standard.bool(forKey: "SalahDebugTour") { return false }
    #endif
    return LocalStore.string(Self.doneKey(id)) == "true"
  }

  func setAnchor(_ id: String, _ rect: CGRect?) {
    guard anchors[id] != rect else { return }
    anchors[id] = rect
  }

  /// Tur daha önce görülmediyse ekran yerleşince başlatır. Başka bir pencere (giriş, uyarı)
  /// açıksa ya da kullanıcı ekrandan ayrıldıysa bu sefer açılmaz, bir sonraki gelişte denenir.
  func startIfNeeded(_ tour: Tour, when ready: @escaping () -> Bool) async {
    #if DEBUG
    let forced = UserDefaults.standard.bool(forKey: "SalahDebugTour")
    #else
    let forced = false
    #endif
    guard self.tour == nil, !isDone(tour.id), forced || !DebugLaunch.isIsolated else { return }
    // Öğeler yerleşsin, açılış geçişleri bitsin; veriyle gelen öğeler (konum) için en fazla ~15 sn beklenir.
    try? await Task.sleep(for: .milliseconds(900))
    var attempts = 0
    while !(ready() && AlertCenter.shared.current == nil) {
      attempts += 1
      guard attempts < 60, !Task.isCancelled else { return }
      try? await Task.sleep(for: .milliseconds(250))
    }
    guard !Task.isCancelled, self.tour == nil else { return }
    start(tour)
    #if DEBUG
    // -SalahDebugTourStep N: doğrulama için N. adımdan (0'dan) açar.
    if UserDefaults.standard.object(forKey: "SalahDebugTourStep") != nil, !steps.isEmpty {
      let step = UserDefaults.standard.integer(forKey: "SalahDebugTourStep")
      index = min(max(step, 0), steps.count - 1)
    }
    #endif
  }

  func start(_ tour: Tour) {
    if let tabBar = Self.tabBarFrame() { anchors[Tour.tabBarAnchor] = tabBar }
    let screen = Self.windowBounds()
    steps = tour.steps.filter { step in
      guard let rect = anchors[step.anchor], !rect.isEmpty else { return false }
      return step.scroll || screen.contains(rect)
    }
    guard !steps.isEmpty else { return }
    index = 0
    self.tour = tour
  }

  func next() {
    Haptics.impact(.light)
    if index + 1 < steps.count {
      index += 1
    } else {
      finish()
      Haptics.notify(.success)
    }
  }

  func skip() {
    Haptics.impact(.medium)
    finish()
  }

  /// Artınca turu başlatan ekran yeniden dener (Ayarlar'dan "tekrar izle").
  private(set) var replayNonce = 0

  /// Ayarlar'dan "tekrar izle": tüm turların görüldü bilgisini siler; ana sayfa turu hemen,
  /// sekmelerinki o sekmeye ilk girişte yeniden açılır.
  func replayAll() {
    for id in Tour.allIds { LocalStore.set(nil, for: Self.doneKey(id)) }
    replayNonce += 1
  }

  private func finish() {
    if let tour { for id in [tour.id] + tour.covers { LocalStore.set("true", for: Self.doneKey(id)) } }
    tour = nil
    steps = []
    index = 0
  }

  private static func keyWindow() -> UIWindow? {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first(where: \.isKeyWindow)
  }

  private static func windowBounds() -> CGRect { keyWindow()?.bounds ?? .zero }

  /// Balonun durum çubuğu ve ana ekran çizgisine taşmaması için.
  static func safeInsets() -> UIEdgeInsets { keyWindow()?.safeAreaInsets ?? .zero }

  /// Sistem sekme çubuğunun penceredeki yeri (SwiftUI `TabView` → `UITabBarController`).
  private static func tabBarFrame() -> CGRect? {
    func find(_ vc: UIViewController?) -> UITabBarController? {
      guard let vc else { return nil }
      if let tab = vc as? UITabBarController { return tab }
      for child in vc.children { if let found = find(child) { return found } }
      return nil
    }
    guard let tabBar = find(keyWindow()?.rootViewController)?.tabBar, !tabBar.isHidden else { return nil }
    return tabBar.convert(tabBar.bounds, to: nil)
  }
}

extension View {
  /// Öğeyi tur adımı için işaretler (yeri pencere koordinatlarında kaydedilir; `scrollTo` kimliği de olur).
  /// `nil`: hiçbir şey eklenmez (listede yalnız ilk satır gibi). Tembel listede satırlara ortak `.id(nil)`
  /// verilirse kimlikler çakışır ve satırlar boş çizilir.
  @ViewBuilder
  func tourAnchor(_ id: String?) -> some View {
    if let id {
      onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { TourStore.shared.setAnchor(id, $0) }
        .onDisappear { TourStore.shared.setAnchor(id, nil) }
        .id(id)
    } else {
      self
    }
  }

  /// Kaydırılan adımda içeriği öğeye kaydırır; tur bitince `top` kimliğine döner (`nil`: yerinde kalır).
  func tourScroll(_ proxy: ScrollViewProxy, top: String?) -> some View {
    onChange(of: TourStore.shared.current?.anchor) { _, anchor in
      if anchor == nil {
        guard let top else { return }
        withAnimation(.easeInOut(duration: 0.35)) { proxy.scrollTo(top, anchor: .top) }
      } else if let step = TourStore.shared.current, step.scroll {
        // Üste hizalanır: uzun kartlarda balona altta yer kalır.
        withAnimation(.easeInOut(duration: 0.35)) { proxy.scrollTo(step.anchor, anchor: .top) }
      }
    }
  }
}
