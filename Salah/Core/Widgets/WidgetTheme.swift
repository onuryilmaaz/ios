import Foundation
import Observation

/// Ayarlar'daki widget teması; uygulamanın kendi temasından bağımsızdır. Değerler widget tarafındaki
/// `WidgetThemeChoice` (SharedData.swift) ile aynı olmalı.
enum WidgetTheme: String, CaseIterable {
  case system, light, dark

  static func from(_ raw: String?) -> WidgetTheme { raw.flatMap(WidgetTheme.init) ?? .system }
}

@MainActor
@Observable
final class WidgetThemeStore {
  static let shared = WidgetThemeStore()

  private(set) var theme = WidgetTheme.from(WidgetBridge.widgetTheme)

  func set(_ value: WidgetTheme) {
    theme = value
    WidgetBridge.setWidgetTheme(value.rawValue)
  }
}
