import ActivityKit
import AppIntents
import Foundation
import SwiftUI

#if canImport(AlarmKit)
  @preconcurrency import AlarmKit
#endif

/// AlarmKit (iOS 26+). Alarmlar Saat uygulamasındaki gibi sessiz modu ve Odak'ı delerek
/// kilit ekranında tam ekran çalar. RN: widget-src/SalahAlarmModule.swift (aynı kurallar).
///
/// Her senkronda bekleyen (çalmamış) alarmların hepsi silinip liste yeniden kurulur;
/// çalan ya da ertelenmiş alarmlara dokunulmaz. iOS 26 öncesinde her şey no-op.
enum AlarmKitBridge {
  struct Spec: Sendable {
    let fireDate: Date
    let title: String
    /// prayer | tahajjud | sahur | custom
    let kind: String
    /// Widget vakit kimliği (sabah, ogle, …); "Kıldım" için.
    let prayerId: String
    /// Paketteki ses dosyası; boşsa sistem alarm sesi.
    let sound: String
    /// none | mark | snooze
    let secondary: String
    let secondaryLabel: String
    let snoozeSeconds: Double
    let snoozeTitle: String
    /// iOS 26.0'da zorunlu "Durdur" düğmesi (26.1+ sistem kendisi çizer).
    let stopLabel: String
  }

  static var isSupported: Bool {
    #if canImport(AlarmKit)
      if #available(iOS 26.0, *) { return true }
    #endif
    return false
  }

  static var authorization: AlarmStore.Auth {
    #if canImport(AlarmKit)
      if #available(iOS 26.0, *) { return status(AlarmManager.shared.authorizationState) }
    #endif
    return .unsupported
  }

  static func requestAuthorization() async -> AlarmStore.Auth {
    #if canImport(AlarmKit)
      if #available(iOS 26.0, *) {
        guard let state = try? await AlarmManager.shared.requestAuthorization() else { return .denied }
        return status(state)
      }
    #endif
    return .unsupported
  }

  static func sync(_ specs: [Spec]) async -> (scheduled: Int, limitReached: Bool) {
    #if canImport(AlarmKit)
      if #available(iOS 26.0, *) { return await AlarmSyncer.shared.sync(specs) }
    #endif
    return (0, false)
  }

  #if canImport(AlarmKit)
    @available(iOS 26.0, *)
    private static func status(_ state: AlarmManager.AuthorizationState) -> AlarmStore.Auth {
      switch state {
      case .authorized: .authorized
      case .denied: .denied
      case .notDetermined: .notDetermined
      @unknown default: .notDetermined
      }
    }
  #endif
}

#if canImport(AlarmKit)

  /// Senkronlar AlarmStore'da sıraya girer (iki senkron birbirinin kurduğunu silmez);
  /// burada ana aktörde çalışılır.
  @available(iOS 26.0, *)
  @MainActor
  private final class AlarmSyncer {
    static let shared = AlarmSyncer()

    /// Zümrüt (Tokens.accent açık tema).
    private let tint = Color(red: 0x1f / 255, green: 0x73 / 255, blue: 0x56 / 255)

    func sync(_ specs: [AlarmKitBridge.Spec]) async -> (scheduled: Int, limitReached: Bool) {
      let manager = AlarmManager.shared
      for alarm in (try? manager.alarms) ?? [] where alarm.state == .scheduled {
        try? manager.cancel(id: alarm.id)
      }
      guard manager.authorizationState == .authorized else {
        WidgetBridge.publishAlarmDates([])
        return (0, false)
      }

      let now = Date()
      var scheduled = 0
      var dates: [Date] = []
      var limitReached = false
      // Yakından uzağa: üst sınıra takılırsak en yakın alarmlar kurulmuş olur.
      for spec in specs.filter({ $0.fireDate > now }).sorted(by: { $0.fireDate < $1.fireDate }) {
        let id = UUID()
        do {
          _ = try await manager.schedule(id: id, configuration: configuration(for: spec, id: id))
          scheduled += 1
          dates.append(spec.fireDate)
        } catch AlarmManager.AlarmError.maximumLimitReached {
          limitReached = true
          break
        } catch {
          continue
        }
      }
      WidgetBridge.publishAlarmDates(dates)
      return (scheduled, limitReached)
    }

    private func configuration(for spec: AlarmKitBridge.Spec, id: UUID) -> AlarmManager.AlarmConfiguration<SalahAlarmMetadata> {
      let title = LocalizedStringResource(String.LocalizationValue(spec.title))
      let label = LocalizedStringResource(String.LocalizationValue(spec.secondaryLabel))
      let metadata = SalahAlarmMetadata(kind: spec.kind, prayerId: spec.prayerId)
      let sound: AlertConfiguration.AlertSound = spec.sound.isEmpty ? .default : .named(spec.sound)
      let schedule = Alarm.Schedule.fixed(spec.fireDate)

      switch spec.secondary {
      case "mark" where !spec.prayerId.isEmpty:
        let presentation = AlarmPresentation(
          alert: alert(spec, title: title, secondary: AlarmButton(text: label, textColor: .white, systemImageName: "checkmark.circle.fill"), behavior: .custom))
        return .alarm(
          schedule: schedule,
          attributes: AlarmAttributes(presentation: presentation, metadata: metadata, tintColor: tint),
          secondaryIntent: SalahAlarmMarkPrayerIntent(alarmID: id.uuidString, prayerId: spec.prayerId),
          sound: sound)

      case "snooze":
        let presentation = AlarmPresentation(
          alert: alert(spec, title: title, secondary: AlarmButton(text: label, textColor: .white, systemImageName: "zzz"), behavior: .countdown),
          countdown: .init(title: LocalizedStringResource(String.LocalizationValue(spec.snoozeTitle))))
        return AlarmManager.AlarmConfiguration(
          countdownDuration: .init(preAlert: nil, postAlert: spec.snoozeSeconds),
          schedule: schedule,
          attributes: AlarmAttributes(presentation: presentation, metadata: metadata, tintColor: tint),
          sound: sound)

      default:
        return .alarm(
          schedule: schedule,
          attributes: AlarmAttributes(presentation: AlarmPresentation(alert: alert(spec, title: title)), metadata: metadata, tintColor: tint),
          sound: sound)
      }
    }

    private func alert(
      _ spec: AlarmKitBridge.Spec, title: LocalizedStringResource, secondary: AlarmButton? = nil,
      behavior: AlarmPresentation.Alert.SecondaryButtonBehavior? = nil
    ) -> AlarmPresentation.Alert {
      if #available(iOS 26.1, *) {
        return .init(title: title, secondaryButton: secondary, secondaryButtonBehavior: behavior)
      }
      let stop = AlarmButton(text: LocalizedStringResource(String.LocalizationValue(spec.stopLabel)), textColor: .white, systemImageName: "stop.circle")
      return .init(title: title, stopButton: stop, secondaryButton: secondary, secondaryButtonBehavior: behavior)
    }
  }

  /// Alarm ekranındaki "Kıldım": alarmı susturur ve namazı işaretler. Uygulama içinde
  /// çalışır; ağ yoksa istek offline kuyruğa girer, uygulama açılınca gönderilir.
  /// (RN sürümü widget'taki MarkPrayerIntent'i çağırıyordu; widget'lar taşınınca ortaklaşır.)
  @available(iOS 26.0, *)
  struct SalahAlarmMarkPrayerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Mark Prayer From Alarm"
    static let isDiscoverable = false

    @Parameter(title: "Alarm ID")
    var alarmID: String

    @Parameter(title: "Prayer ID")
    var prayerId: String

    init() {}

    init(alarmID: String, prayerId: String) {
      self.alarmID = alarmID
      self.prayerId = prayerId
    }

    func perform() async throws -> some IntentResult {
      if let id = UUID(uuidString: alarmID) { try? AlarmManager.shared.stop(id: id) }
      await AlarmMarkPrayer.mark(widgetID: prayerId)
      return .result()
    }
  }

#endif

/// "Kıldım" işaretlemesi (widget kimliği → backend kimliği, vakti geçtiyse kaza).
enum AlarmMarkPrayer {
  static let backendID = ["sabah": "fajr", "ogle": "dhuhr", "ikindi": "asr", "aksam": "maghrib", "yatsi": "isha"]

  static func mark(widgetID: String, now: Date = Date()) async {
    guard let id = backendID[widgetID] else { return }
    let times = await PrayerTimesService.today(districtId: Locations.selectedDistrictId)?.times
    _ = try? await GamificationStore.shared.trackPrayer(id, isKaza: times.map { isExpired(id, times: $0, now: now) } ?? false)
  }

  /// Vakit penceresi kapandı mı (ana sayfa takip kartıyla aynı kural; imsaktan önce dünkü gün).
  static func isExpired(_ id: String, times: PrayerTimes, now: Date) -> Bool {
    let cal = Calendar.current
    let nowMin = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
    func minutes(_ s: String) -> Int {
      let p = s.split(separator: ":").compactMap { Int($0) }
      return (p.first ?? 0) * 60 + (p.count > 1 ? p[1] : 0)
    }
    if id == "isha" { return false }
    if nowMin < minutes(times.imsak) { return true }
    let end: String =
      switch id {
      case "fajr": times.gunes
      case "dhuhr": times.ikindi
      case "asr": times.aksam
      default: times.yatsi
      }
    return nowMin >= minutes(end)
  }
}
