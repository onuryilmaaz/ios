import BackgroundTasks
import Foundation

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

  @MainActor
  static func run() async {
    schedule()
    guard !DebugLaunch.isIsolated else { return }
    let days = await PrayerTimesService.upcomingDays(districtId: Locations.selectedDistrictId)
    let today = Calendar.current.startOfDay(for: Date())
    WidgetSync.updatePrayer((days.first { $0.localDay == today } ?? days.first)?.times)
    await WidgetSync.syncVerses()
    // Önce alarmlar: tam vaktinde alarm olan vakitte bildirim atlanır.
    await AlarmStore.shared.sync()
    await NotificationStore.shared.reschedule(force: true)
  }
}
