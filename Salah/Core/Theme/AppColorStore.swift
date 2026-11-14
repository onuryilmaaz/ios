import Foundation
import Observation
import SwiftUI

/// Uygulama rengi: kullanıcı Ayarlar'dan seçer; Ramazan günlerinde seçimden bağımsız olarak saate göre
/// lacivert, mor ve bordo arasında kendisi geçer. `Accent` ve `Forest` buradan okur, böylece bütün ekranlar
/// yeniden çizilir. Widget'lar seçimi App Group'tan okur ve Ramazan tonunu kendileri hesaplar.
@MainActor
@Observable
final class AppColorStore {
  static let shared = AppColorStore()
  private static let key = "@salah_app_color_v1"
  private static let customKey = "@salah_app_color_custom_v1"

  /// Ayarlar'daki seçim.
  private(set) var choice: AppColor
  /// Ekranda olan renk (Ramazan'da saate göre).
  private(set) var current: AppColor
  private(set) var palette: AppPalette

  @ObservationIgnored private var timer: Timer?

  /// Özel renk ("#RRGGBB").
  private(set) var customHex: String

  private init() {
    let hex = LocalStore.string(Self.customKey).flatMap(CustomPalette.parse) ?? CustomPalette.defaultSeed
    AppColor.customSeed = hex
    customHex = CustomPalette.format(hex)
    let saved = LocalStore.string(Self.key).flatMap(AppColor.init) ?? .forest
    choice = saved
    current = saved
    palette = AppPalette(saved)
  }

  /// Ramazan otomatik tonu açıkken seçim yine kaydedilir; Ramazan bitince o renge dönülür.
  var isRamadanAuto: Bool { ramadanColor() != nil }

  func set(_ value: AppColor) {
    choice = value
    LocalStore.set(value.rawValue, for: Self.key)
    WidgetBridge.setAppColor(value.rawValue)
    refresh()
  }

  /// Paletten seçilen rengi kaydeder ve özel rengi etkinleştirir.
  func setCustom(_ rgb: UInt32) {
    AppColor.customSeed = rgb & 0xFFFFFF
    customHex = CustomPalette.format(rgb)
    LocalStore.set(customHex, for: Self.customKey)
    WidgetBridge.setCustomColor(customHex)
    choice = .custom
    LocalStore.set(AppColor.custom.rawValue, for: Self.key)
    WidgetBridge.setAppColor(AppColor.custom.rawValue)
    // Seçim zaten özelse `current` değişmez: palet elle yenilenir.
    if current == .custom { palette = AppPalette(.custom) }
    refresh()
  }

  /// Açılışta bir kez: dakikada bir Ramazan tonunu yeniden hesaplar.
  func start() {
    WidgetBridge.setCustomColor(customHex)
    WidgetBridge.setAppColor(choice.rawValue)
    refresh()
    guard timer == nil else { return }
    timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
      Task { @MainActor in AppColorStore.shared.refresh() }
    }
  }

  func refresh(now: Date = Date()) {
    let next = debugColor ?? ramadanColor(now: now) ?? choice
    guard next != current else { return }
    current = next
    palette = AppPalette(next)
  }

  private func ramadanColor(now: Date = Date()) -> AppColor? {
    guard RamadanMode.shared.isOn(now: now) else { return nil }
    let times = PrayerTimesService.cachedDays(districtId: Locations.selectedDistrictId)
      .first { $0.localDay.map { Calendar.current.isDate($0, inSameDayAs: now) } == true }?.times
    let window = RamadanSchedule.window(ReligiousCalendarService.cached(), now: now)
    guard case .active = RamadanSchedule.phase(window, now: now, today: times) else { return nil }
    #if DEBUG
    if let raw = UserDefaults.standard.string(forKey: "SalahDebugTint"), let phase = RamadanTintPhase(rawValue: raw) { return AppColor.of(phase) }
    #endif
    return AppColor.of(RamadanPlan.tint(now: now, today: times, calendar: .current))
  }

  /// Debug'da `-SalahDebugColor navy|purple|burgundy` (ekran görüntüleri için).
  private var debugColor: AppColor? {
    #if DEBUG
    return UserDefaults.standard.string(forKey: "SalahDebugColor").flatMap(AppColor.init)
    #else
    return nil
    #endif
  }
}
