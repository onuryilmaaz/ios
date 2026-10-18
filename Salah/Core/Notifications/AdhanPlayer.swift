import AVFoundation
import UIKit

enum AdhanTiming {
  static func allowed(key: String, preferences: NotificationPreferences, now: Date, lastKey: String?, lastDate: Date?) -> Bool {
    guard key != "gunes", preferences.adhanEnabled[key] == true, !preferences.isMuted(at: now) else { return false }
    return key != lastKey || lastDate.map { now.timeIntervalSince($0) >= 90 } ?? true
  }

  static func next(days: [PrayerDay], now: Date, calendar: Calendar = .current) -> (key: String, date: Date)? {
    var result: (key: String, date: Date)?
    for day in days {
      guard let base = NotificationPlan.parseDay(day.date, calendar: calendar) else { continue }
      for key in NotificationPreferences.prayers where key != "gunes" {
        guard let raw = day.times[key], let date = NotificationPlan.clock(raw, on: base, calendar: calendar), date > now else { continue }
        if result == nil || date < result!.date { result = (key, date) }
      }
    }
    return result
  }
}

/// Tam ezan yalnız foreground'da çalar. Kapalı uygulamada kısa UN sesi kullanılır.
@Observable
final class AdhanPlayer: NSObject, AVAudioPlayerDelegate {
  static let shared = AdhanPlayer()
  private(set) var activePrayer: String?
  @ObservationIgnored private var player: AVAudioPlayer?
  @ObservationIgnored private var timer: Task<Void, Never>?
  @ObservationIgnored private var lastKey: String?
  @ObservationIgnored private var lastDate: Date?
  @ObservationIgnored private var days: [PrayerDay] = []
  @ObservationIgnored private var isActive = false
  @ObservationIgnored private var pendingTap: (key: String, receivedAt: Date)?
  @ObservationIgnored private lazy var window = OverlayWindow(level: .init(rawValue: UIWindow.Level.alert.rawValue - 1)) { AdhanOverlay() }

  func activate() async {
    isActive = true
    guard !DebugLaunch.isIsolated else { return }
    if let tap = pendingTap {
      pendingTap = nil
      if Date().timeIntervalSince(tap.receivedAt) < 30 { _ = play(tap.key) }
    }
    let district = Locations.selectedDistrictId
    let fetched = await PrayerTimesService.upcomingDays(districtId: district)
    guard isActive, district == Locations.selectedDistrictId else { return }
    days = fetched
    scheduleNext()
  }

  func deactivate() {
    isActive = false
    timer?.cancel()
    timer = nil
    stop()
  }

  func receiveTap(_ key: String) {
    if isActive { _ = play(key) }
    else { pendingTap = (key, Date()) }
  }

  @discardableResult
  func play(_ key: String, test: Bool = false) -> Bool {
    let now = Date()
    // Timer ve bildirim aynı anda geldiyse ikinci çağrı da 'ses çalıyor' görsün.
    if activePrayer == key, player?.isPlaying == true { return true }
    guard test || (isActive && AdhanTiming.allowed(key: key, preferences: NotificationStore.shared.preferences,
      now: now, lastKey: lastKey, lastDate: lastDate)) else { return false }
    guard key != "gunes", NotificationPreferences.prayers.contains(key),
      let url = Bundle.main.url(forResource: key, withExtension: "mp3", subdirectory: "audio")
    else { return false }
    stop()
    QuranAudioPlayer.shared.stop()
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, mode: .default, options: [.duckOthers])
      try session.setActive(true)
      let audio = try AVAudioPlayer(contentsOf: url)
      audio.delegate = self
      guard audio.play() else { stop(); return false }
      player = audio
      activePrayer = key
      lastKey = key
      lastDate = now
      window.show()
      return true
    } catch {
      stop()
      return false
    }
  }

  func stop() {
    let hadPlayer = player != nil
    player?.stop()
    player = nil
    activePrayer = nil
    window.hide()
    // Foreground ezan yokken Kur'an'ın arka plan ses oturumunu kapatma.
    if hadPlayer { try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation]) }
  }

  private func scheduleNext() {
    timer?.cancel()
    guard isActive, let next = AdhanTiming.next(days: days, now: Date()) else { return }
    timer = Task { [weak self] in
      do { try await Task.sleep(for: .seconds(max(0, next.date.timeIntervalSinceNow))) }
      catch { return }
      guard let self, self.isActive else { return }
      _ = self.play(next.key)
      self.scheduleNext()
    }
  }

  nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    let finishedID = ObjectIdentifier(player)
    Task { @MainActor in
      // Geç gelen eski oynatıcı callback'i yeni ezanı durdurmasın.
      if self.player.map({ ObjectIdentifier($0) }) == finishedID { self.stop() }
    }
  }

  #if DEBUG
  func preview() { activePrayer = "ogle"; window.show() }
  #endif
}
