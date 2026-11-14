import SwiftUI
import WidgetKit

@main
struct SitePongLiveActivityWidgetBundle: WidgetBundle {
  var body: some Widget {
    // Home screen widgets
    PrayerTimesWidget()
    PrayerTrackerWidget()
    AmelWidget()
    InspirationWidget()

    // Kilit ekranı widget'ları (iOS 16+)
    SalahNextPrayerLockWidget()
    SalahTrackerLockWidget()

    // Ramazan
    RamadanFastWidget()
    RamadanTimetableWidget()
    RamadanLockWidget()

    // Gün çemberi
    DayRingWidget()

    // Zikirmatik (dokunarak sayar, iOS 17+)
    DhikrWidget()

    // Hedeflerim: kaza, ezber tekrarı, teheccüd
    GoalsWidget()

    // Standby (iOS 17+)
    StandbyPrayerWidget()

    // Live Activity
    SitePongLiveActivityWidgetLiveActivity()

    // Alarm ertele geri sayımı (AlarmKit, iOS 26+)
    if #available(iOS 26.0, *) {
      SalahAlarmLiveActivity()
    }
  }
}
