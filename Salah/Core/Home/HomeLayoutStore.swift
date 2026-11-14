import Foundation

/// Ana sayfadaki kişiselleştirilebilir kartlar: sıra ve görünürlük cihazda saklanır (RN ile aynı anahtar
/// `home_layout_v1` ve biçim). Vakit kartı ve durum şeritleri çekirdek olduğundan her zaman en üstte sabittir.
///
/// Varsayılan düzen panelden gelir (`/app/config` `homeLayout`, sunucu `homeLayout` özelliğini destekliyorsa);
/// gelmezse yerleşik düzen. Kullanıcı düzeni hiç değiştirmediyse panelin düzeni olduğu gibi uygulanır; değiştirdiyse
/// kendi düzeni korunur, yalnız yeni kartlar panelin varsayılan yeri ve görünürlüğüyle eklenir. Panelde kapatılan
/// kart (`home.<kart>` modülü) ana sayfadan da düzen ekranından da kalkar.
/// RN: store/home.store.ts
@Observable
final class HomeLayoutStore {
  static let shared = HomeLayoutStore()

  enum Key: String, Codable, CaseIterable, Sendable {
    case prayerTracker, streak, quickActions, dailyInspiration, dayRing, alarms, kaza, dhikr

    var labelKey: String { "homeSections.\(rawValue).label" }
    var descriptionKey: String { "homeSections.\(rawValue).description" }
    var icon: String {
      switch self {
      case .prayerTracker: "checkmark-done-circle-outline"
      case .streak: "flame-outline"
      case .quickActions: "apps-outline"
      case .dailyInspiration: "bulb-outline"
      case .alarms: "alarm-outline"
      case .dayRing: "sync-circle-outline"
      case .kaza: "hourglass-outline"
      case .dhikr: "finger-print-outline"
      }
    }
  }

  struct Section: Codable, Equatable, Sendable {
    var key: Key
    var visible: Bool
  }

  /// Yerleşik sıra (sunucudaki HOME_SECTIONS ile aynı); kaza kartı varsayılan gizli.
  static let defaults: [Section] = [
    .init(key: .prayerTracker, visible: true),
    .init(key: .alarms, visible: true),
    .init(key: .streak, visible: true),
    .init(key: .quickActions, visible: true),
    .init(key: .dhikr, visible: true),
    .init(key: .dailyInspiration, visible: true),
    .init(key: .dayRing, visible: true),
    .init(key: .kaza, visible: false),
  ]

  private static let storageKey = "home_layout_v1"

  /// Kullanıcının kaydettiği düzen; hiç değiştirmediyse nil.
  private var stored: [Section]?

  private init() {
    stored = Self.load()
  }

  /// Panelden gelen varsayılan (yoksa yerleşik).
  var baseDefaults: [Section] {
    guard AppControlStore.shared.supports("homeLayout"), let remote = AppControlStore.shared.snapshot.homeLayout else { return Self.defaults }
    return Self.remoteDefaults(order: remote.order, hidden: remote.hidden)
  }

  /// Tüm kartlar (kapalı modüller dahil) kayıtlı ya da varsayılan sırayla.
  private var all: [Section] {
    let base = baseDefaults
    return stored.map { Self.reconcile($0, defaults: base) } ?? base
  }

  /// Ana sayfada ve düzen ekranında gösterilecek kartlar.
  var sections: [Section] { all.filter { Self.available($0.key) } }

  /// Kart bu kullanıcıya sunulabilir mi: panelde açık ve gerekiyorsa sunucu/oturum hazır.
  static func available(_ key: Key) -> Bool {
    guard AppControlStore.shared.isOn("home.\(key.rawValue)") else { return false }
    switch key {
    case .alarms: return AppControlStore.shared.isOn("alarms")
    case .dhikr: return AppControlStore.shared.isOn("dhikr")
    case .kaza: return KazaStore.shared.available
    default: return true
    }
  }

  func toggle(_ key: Key) {
    var list = all
    guard let i = list.firstIndex(where: { $0.key == key }) else { return }
    list[i].visible.toggle()
    save(list)
  }

  /// Görünen listede bir yukarı/aşağı: arada gizli (kapalı modül) kart varsa onu atlar.
  func move(_ key: Key, by direction: Int) {
    let visibleKeys = sections.map(\.key)
    guard let at = visibleKeys.firstIndex(of: key), visibleKeys.indices.contains(at + direction) else { return }
    var list = all
    guard let i = list.firstIndex(where: { $0.key == key }), let j = list.firstIndex(where: { $0.key == visibleKeys[at + direction] }) else { return }
    list.swapAt(i, j)
    save(list)
  }

  /// Panelin (yoksa yerleşik) düzenine döner.
  func reset() {
    stored = nil
    LocalStore.remove(Self.storageKey)
  }

  func isVisible(_ key: Key) -> Bool {
    sections.first { $0.key == key }?.visible ?? false
  }

  /// Panelin sırası: bilinmeyen ve tekrarlanan anahtarlar atılır, eksik kartlar yerleşik yer ve görünürlükle eklenir.
  static func remoteDefaults(order: [String], hidden: [String]) -> [Section] {
    let hidden = Set(hidden)
    let listed = order.compactMap(Key.init(rawValue:)).map { Section(key: $0, visible: !hidden.contains($0.rawValue)) }
    return reconcile(listed, defaults: defaults)
  }

  /// Kayıtlı düzeni varsayılanlarla uzlaştırır: bilinen kartların sırası korunur,
  /// yeni kartlar varsayılan sıradaki yerlerine varsayılan görünürlükle eklenir,
  /// artık olmayanlar ve tekrarlar atılır.
  static func reconcile(_ stored: [Section], defaults: [Section] = defaults) -> [Section] {
    var seen = Set<Key>()
    var result: [Section] = []
    for item in stored where !seen.contains(item.key) {
      result.append(item)
      seen.insert(item.key)
    }
    for (i, def) in defaults.enumerated() where !seen.contains(def.key) {
      var at = 0
      for j in stride(from: i - 1, through: 0, by: -1) {
        if let prev = result.firstIndex(where: { $0.key == defaults[j].key }) {
          at = prev + 1
          break
        }
      }
      result.insert(def, at: at)
      seen.insert(def.key)
    }
    return result
  }

  /// Bilinmeyen anahtarlı kayıtlar (eski/yeni sürüm) tek tek atlanır.
  private static func load() -> [Section]? {
    guard let raw = LocalStore.string(storageKey), let data = raw.data(using: .utf8),
      let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
    else { return nil }
    return items.compactMap { item in
      guard let key = (item["key"] as? String).flatMap(Key.init(rawValue:)) else { return nil }
      return Section(key: key, visible: (item["visible"] as? Bool) != false)
    }
  }

  private func save(_ list: [Section]) {
    stored = list
    LocalStore.encode(list, for: Self.storageKey)
  }
}
