import DeviceActivity
import Foundation

/// Vakit girince seçili uygulamaları kilitler, süre dolunca açar. Namaz zaten işaretliyse kilitlemez.
final class PrayerLockMonitor: DeviceActivityMonitor {
  override func intervalDidStart(for activity: DeviceActivityName) {
    super.intervalDidStart(for: activity)
    guard let (prayer, day) = PrayerLockShared.parse(activity.rawValue), PrayerLockShared.settings().enabled,
      !PrayerLockShared.isPrayed(prayer, day: day)
    else { return }
    PrayerLockShared.lock(prayer: prayer)
  }

  override func intervalDidEnd(for activity: DeviceActivityName) {
    super.intervalDidEnd(for: activity)
    guard let (prayer, _) = PrayerLockShared.parse(activity.rawValue), PrayerLockShared.currentPrayer == prayer else { return }
    PrayerLockShared.unlock()
  }
}
