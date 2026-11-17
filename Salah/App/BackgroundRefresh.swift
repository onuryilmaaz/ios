import BackgroundTasks
import Foundation
import UIKit

/// Arka plan yenilemesi (BGAppRefresh): uygulama günlerce açılmasa da vakit önbelleği yeni aya taşınır,
/// widget verisi, bildirimler (7 gün) ve alarmlar (14 gün) ileri kaydırılır. Ne zaman çalışacağına sistem
/// karar verir (kullanım alışkanlığı, pil, ağ); en erken 12 saat sonrasına istenir.
enum BackgroundRefresh {
  static let identifier = "com.onur6541.salah.refresh"

  static func schedule() {
    guard !DebugLaunch.isIsolated else { return }
    let request = BGAppRefreshTaskRequest(identifier: identifier)
    request.earliestBeginDate = Date().addingTimeInterval(12 * 3600)
    try? BGTaskScheduler.shared.submit(request)
  }

  /// Sessiz bildirim (gece `plan_refresh`) ve BGAppRefresh buraya gelir. Sistemin tanıdığı süre kısa (~30 sn):
  /// önce bildirim planı kurulur, ayet indirmek gibi işler sona kalır; iş sürerken ek arka plan süresi istenir.
  @MainActor
  static func run() async {
    schedule()
    guard !DebugLaunch.isIsolated else { return }
    let task = BackgroundTime()
    defer { task.end() }
    let days = await PrayerTimesService.upcomingDays(districtId: Locations.selectedDistrictId)
    let today = Calendar.current.startOfDay(for: Date())
    WidgetSync.updatePrayer((days.first { $0.localDay == today } ?? days.first)?.times)
    // Önce alarmlar: tam vaktinde alarm olan vakitte bildirim atlanır.
    await AlarmStore.shared.sync()
    await NotificationStore.shared.reschedule(force: true)
    await WidgetSync.syncVerses()
  }
}

/// İş bitene kadar sistemden ek arka plan süresi; süre dolarsa sistem işi keser, uygulama askıya alınır.
@MainActor
private final class BackgroundTime {
  private var id: UIBackgroundTaskIdentifier = .invalid

  init() {
    id = UIApplication.shared.beginBackgroundTask(withName: "notification-plan") { [weak self] in self?.end() }
  }

  func end() {
    guard id != .invalid else { return }
    UIApplication.shared.endBackgroundTask(id)
    id = .invalid
  }
}
