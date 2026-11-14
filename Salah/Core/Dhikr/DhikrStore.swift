import Foundation
import Observation
import WidgetKit

/// Zikirler. Arapça metin `DhikrShared`'da; ad, okunuş ve anlam dil dosyalarında (`dhikr.items.<id>`).
struct DhikrItem: Equatable, Sendable, Identifiable {
  let id: String
  let arabic: String
  /// Serbest zikirde varsayılan hedef.
  let target: Int

  static let all: [DhikrItem] = DhikrShared.items.map { .init(id: $0.id, arabic: DhikrShared.arabic[$0.id] ?? "", target: $0.target) }
  /// Tesbihatın son adımı (bir kez).
  static let tesbihatClosing = DhikrItem(id: "tesbihatClosing", arabic: DhikrShared.arabic["tesbihatClosing"] ?? "", target: 1)

  static func find(_ id: String) -> DhikrItem? { (all + [tesbihatClosing]).first { $0.id == id } }
}

/// Kurallar `DhikrShared`'da (widget ile ortak); burada uygulamanın kullandığı adlar.
enum DhikrPlan {
  typealias Tesbihat = DhikrShared.Tesbihat
  typealias Event = DhikrShared.Event
  static var tesbihat: [(id: String, target: Int)] { DhikrShared.steps }
  static let targets = [33, 99, 100, 500, 1000, 0]
  static func tap(_ s: Tesbihat) -> (Tesbihat, Event) { DhikrShared.tap(s) }
  static func reachedTarget(count: Int, target: Int) -> Bool { DhikrShared.reachedTarget(count: count, target: target) }
}

/// Zikirmatik durumu: App Group'ta (widget de sayar), sunucuya gitmez. Uygulama öne gelince yeniden okunur.
@MainActor
@Observable
final class DhikrStore {
  static let shared = DhikrStore()
  /// Eski (yalnız uygulama) kayıt; ilk açılışta App Group'a taşınır.
  private static let legacyKey = "@salah_dhikr_v1"
  private static let widgetKind = "SalahDhikrWidget"

  enum Mode: String, Codable, Sendable { case tesbihat, free }

  private var state: DhikrShared.State

  private init() {
    if let shared = DhikrShared.load() {
      state = shared
    } else {
      state = LocalStore.decode(DhikrShared.State.self, Self.legacyKey) ?? DhikrShared.State()
      DhikrShared.save(state)
    }
  }

  /// Widget'tan sayılanlar için (öne gelişte).
  func reload() {
    if let fresh = DhikrShared.load(), fresh != state { state = fresh }
  }

  var mode: Mode { Mode(rawValue: state.mode) ?? .tesbihat }
  var tesbihat: DhikrPlan.Tesbihat { state.tesbihat }
  var item: DhikrItem { DhikrItem.find(state.itemId) ?? DhikrItem.all[0] }
  var target: Int { state.target }
  var count: Int { state.count }
  /// Bugün çekilen toplam zikir.
  var today: Int { state.todayCount() }

  /// Ekranda gösterilen zikir ve hedef (moda göre).
  var current: (item: DhikrItem, count: Int, target: Int) {
    let c = state.current
    return (DhikrItem.find(c.id) ?? DhikrItem.all[0], c.count, c.target)
  }

  func setMode(_ mode: Mode) {
    state.mode = mode.rawValue
    persist()
  }

  func select(_ id: String) {
    guard id != state.itemId, let item = DhikrItem.find(id) else { return }
    state.itemId = id
    state.target = item.target
    state.count = 0
    persist()
  }

  func setTarget(_ value: Int) {
    state.target = max(0, value)
    persist()
  }

  /// Bir dokunuş; dönen olay titreşimi belirler.
  @discardableResult
  func tap() -> DhikrPlan.Event {
    reload()
    if mode == .tesbihat && state.tesbihat.done { return .finished }
    let (next, event) = DhikrShared.tap(state)
    state = next
    if event == .finished && mode == .tesbihat { UsageStore.shared.record("dhikr.tesbihat") }
    persist()
    return event
  }

  /// Son dokunuşu geri alır (adım başına; adım geçişi geri alınmaz).
  func undo() {
    switch mode {
    case .tesbihat:
      guard !state.tesbihat.done, state.tesbihat.count > 0 else { return }
      state.tesbihat.count -= 1
    case .free:
      guard state.count > 0 else { return }
      state.count -= 1
    }
    if today > 0 { state.today -= 1 }
    persist()
  }

  func reset() {
    switch mode {
    case .tesbihat: state.tesbihat = DhikrPlan.Tesbihat()
    case .free: state.count = 0
    }
    persist()
  }

  /// Widget'ı yeniler (ekrandan çıkarken ve arka plana geçerken; her dokunuşta değil).
  func syncWidget() {
    WidgetCenter.shared.reloadTimelines(ofKind: Self.widgetKind)
  }

  private func persist() {
    DhikrShared.save(state)
  }
}
