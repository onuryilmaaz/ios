import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Kontrol Merkezi ve Eylem düğmesi (iOS 18+)
// Android'deki hızlı ayar kutucuklarının (tiles/QuickTiles.kt) karşılığı. Kontroller Eylem düğmesine de atanabilir.

/// O anki vakit: girmiş ve çıkışı geçmemiş vakit (Yatsı gece yarısından sonra da). Kılındıysa `done`.
func currentMarkablePrayer(at date: Date = Date()) -> (info: PrayerInfo, done: Bool)? {
  guard let widget = WidgetData.load() else { return nil }
  let completed = TrackerData.load()?.completedPrayers ?? []
  guard let info = allPrayers.last(where: { isPrayerAvailable($0, widget: widget, at: date) && !prayerWindowExpired(prayerId: $0.id, widget: widget, at: date) })
  else { return nil }
  let backend = widgetToBackendPrayerID[info.id] ?? info.id
  return (info, completed.contains(backend) || completed.contains(info.id))
}

/// "Kıldım": o anki vakti işaretler (widget'taki işaretle aynı kurallar ve sunucu çağrısı). Uygulamayı açmaz.
@available(iOS 18.0, *)
struct MarkCurrentPrayerIntent: AppIntent {
  static var title: LocalizedStringResource = "Mark current prayer"
  static var description = IntentDescription("Marks the current prayer as prayed in Salah.")

  func perform() async throws -> some IntentResult {
    if let current = currentMarkablePrayer(), !current.done {
      _ = try await MarkPrayerIntent(prayerId: current.info.id).perform()
    }
    ControlCenter.shared.reloadControls(ofKind: SalahControlKind.mark)
    return .result()
  }
}

/// Kontrol Merkezi'nden bir zikir sayar; sayı kontrolde görünür.
@available(iOS 18.0, *)
struct DhikrControlTapIntent: AppIntent {
  static var title: LocalizedStringResource = "Count dhikr"
  static var description = IntentDescription("Counts one dhikr in Salah's counter.")

  func perform() async throws -> some IntentResult {
    let state = DhikrShared.load() ?? DhikrShared.State()
    let next = state.mode != "free" && state.tesbihat.done ? { var s = state; s.tesbihat = DhikrShared.Tesbihat(); return s }() : DhikrShared.tap(state).0
    DhikrShared.save(next)
    ControlCenter.shared.reloadControls(ofKind: SalahControlKind.dhikr)
    WidgetCenter.shared.reloadTimelines(ofKind: "SalahDhikrWidget")
    return .result()
  }
}

enum SalahControlKind {
  static let mark = "com.onur6541.salah.control.mark"
  static let dhikr = "com.onur6541.salah.control.dhikr"
}

@available(iOS 18.0, *)
struct MarkPrayerControlProvider: ControlValueProvider {
  struct Value: Sendable {
    let title: String
    let done: Bool
  }

  var previewValue: Value { Value(title: WL.prayer("ogle"), done: false) }

  func currentValue() async throws -> Value {
    guard let current = currentMarkablePrayer() else { return Value(title: WL.t("control.noPrayer"), done: true) }
    return Value(title: current.done ? WL.t("control.prayed", current.info.label) : current.info.label, done: current.done)
  }
}

@available(iOS 18.0, *)
struct MarkPrayerControl: ControlWidget {
  var body: some ControlWidgetConfiguration {
    StaticControlConfiguration(kind: SalahControlKind.mark, provider: MarkPrayerControlProvider()) { value in
      ControlWidgetButton(action: MarkCurrentPrayerIntent()) {
        Label {
          Text(WL.t("control.mark"))
          Text(value.title)
        } icon: {
          Image(systemName: value.done ? "checkmark.circle.fill" : "checkmark.circle")
        }
      }
    }
    .displayName(LocalizedStringResource(stringLiteral: WL.t("control.markName")))
    .description(LocalizedStringResource(stringLiteral: WL.t("control.markDesc")))
  }
}

@available(iOS 18.0, *)
struct DhikrControlProvider: ControlValueProvider {
  struct Value: Sendable {
    let name: String
    let count: Int
    let target: Int
  }

  var previewValue: Value { Value(name: WL.t("dhikrW.subhanallah"), count: 0, target: 33) }

  func currentValue() async throws -> Value {
    let state = DhikrShared.rolled(DhikrShared.load() ?? DhikrShared.State())
    let current = state.current
    return Value(name: WL.t("dhikrW.\(current.id)"), count: current.count, target: current.target)
  }
}

@available(iOS 18.0, *)
struct DhikrControl: ControlWidget {
  var body: some ControlWidgetConfiguration {
    StaticControlConfiguration(kind: SalahControlKind.dhikr, provider: DhikrControlProvider()) { value in
      ControlWidgetButton(action: DhikrControlTapIntent()) {
        Label {
          Text(value.name)
          Text(value.target > 0 ? "\(value.count) / \(value.target)" : "\(value.count)")
        } icon: {
          Image(systemName: "circle.hexagongrid.circle")
        }
      }
    }
    .displayName(LocalizedStringResource(stringLiteral: WL.t("control.dhikrName")))
    .description(LocalizedStringResource(stringLiteral: WL.t("control.dhikrDesc")))
  }
}
