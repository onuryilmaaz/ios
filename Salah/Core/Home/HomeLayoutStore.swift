import Foundation

/// Ana sayfadaki kişiselleştirilebilir kartlar: sıra ve görünürlük cihazda
/// saklanır (RN ile aynı anahtar `home_layout_v1` ve biçim). Vakit kartı ve
/// durum şeritleri çekirdek olduğundan her zaman en üstte sabittir.
/// RN: store/home.store.ts
@Observable
final class HomeLayoutStore {
  static let shared = HomeLayoutStore()

  enum Key: String, Codable, CaseIterable, Sendable {
    case prayerTracker, streak, quickActions, dailyInspiration, dayRing, alarms

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
      }
    }
  }

  struct Section: Codable, Equatable, Sendable {
    var key: Key
    var visible: Bool
  }

  /// Varsayılan sıra; tümü görünür başlar.
  static let defaults: [Section] = [
    .init(key: .prayerTracker, visible: true),
    .init(key: .alarms, visible: true),
    .init(key: .streak, visible: true),
    .init(key: .quickActions, visible: true),
    .init(key: .dailyInspiration, visible: true),
    .init(key: .dayRing, visible: true),
  ]

  private static let storageKey = "home_layout_v1"

  private(set) var sections: [Section]

  private init() {
    sections = Self.load().map(Self.reconcile) ?? Self.defaults
  }

  func toggle(_ key: Key) {
    guard let i = sections.firstIndex(where: { $0.key == key }) else { return }
    sections[i].visible.toggle()
    persist()
  }

  func move(_ key: Key, by direction: Int) {
    guard let i = sections.firstIndex(where: { $0.key == key }) else { return }
    let target = i + direction
    guard sections.indices.contains(target) else { return }
    sections.swapAt(i, target)
    persist()
  }

  func reset() {
    sections = Self.defaults
    persist()
  }

  func isVisible(_ key: Key) -> Bool {
    sections.first { $0.key == key }?.visible ?? false
  }

  /// Kayıtlı düzeni varsayılanlarla uzlaştırır: bilinen kartların sırası korunur,
  /// yeni kartlar varsayılan sıradaki yerlerine görünür olarak eklenir,
  /// artık olmayanlar ve tekrarlar atılır.
  static func reconcile(_ stored: [Section]) -> [Section] {
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

  private func persist() {
    LocalStore.encode(sections, for: Self.storageKey)
  }
}
