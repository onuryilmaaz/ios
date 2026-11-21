import DeviceActivity
import Foundation

/// Kilit aralığı başlayınca seçili uygulamaları kilitler, bitince açar. Namaz zaten işaretliyse kilitlemez.
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
    unlock(activity)
  }

  /// 15 dakikadan kısa kilitlerde asıl bitiş bu uyarıyla gelir (aralık 15 dakikaya uzatılır).
  override func intervalWillEndWarning(for activity: DeviceActivityName) {
    super.intervalWillEndWarning(for: activity)
    unlock(activity)
  }

  /// Yalnız bu vaktin kilidi kalkar; sonraki vakit kilitlediyse dokunulmaz.
  private func unlock(_ activity: DeviceActivityName) {
    guard let (prayer, _) = PrayerLockShared.parse(activity.rawValue), PrayerLockShared.currentPrayer == prayer else { return }
    PrayerLockShared.unlock()
  }
}
