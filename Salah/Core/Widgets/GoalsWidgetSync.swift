import Foundation
import WidgetKit

/// "Hedeflerim" widget'ının verisini App Group'a yazar (kaza, ezber, teheccüd). Değişmediyse widget yenilenmez.
@MainActor
enum GoalsWidgetSync {
  private static let teheccudDaysKey = "@salah_teheccud_days_v1"

  static func publish(now: Date = Date()) {
    guard !DebugLaunch.isIsolated else { return }
    let today = GoalsShared.ymd(now)
    let signedIn = AuthStore.shared.isAuthenticated
    let kaza = KazaStore.shared
    let tracker = TrackerStore.shared
    let teheccudToday = signedIn && tracker.logsDate == today
      && tracker.todayLogs.contains { $0.activity_type == "nafile" && $0.text("type") == "teheccud" }

    // Bu ay teheccüd kaydedilen geceler (cihazda tutulur; bu özellikten önceki aylar sayılmaz).
    let month = String(today.prefix(7))
    var days = Set((LocalStore.decode([String].self, teheccudDaysKey) ?? []).filter { $0.hasPrefix(month) })
    if teheccudToday { days.insert(today) }
    LocalStore.encode(days.sorted(), for: teheccudDaysKey)

    let snapshot = GoalsShared.Snapshot(
      kaza: kaza.available ? kaza.total : nil,
      hifzDue: HifzStore.shared.due(now).count,
      hifzTotal: HifzStore.shared.cards.count,
      teheccudToday: signedIn ? teheccudToday : nil,
      teheccudMonth: signedIn ? days.count : 0,
      day: today)
    guard GoalsShared.load() != snapshot else { return }
    GoalsShared.save(snapshot)
    WidgetCenter.shared.reloadTimelines(ofKind: "SalahGoalsWidget")
  }
}
