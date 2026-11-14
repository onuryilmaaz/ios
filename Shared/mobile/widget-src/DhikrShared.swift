import Foundation

/// Zikirmatik durumu ve kuralları. Uygulama (`DhikrStore`) ve widget (`DhikrWidget`, `DhikrTapIntent`) aynı dosyayı
/// derler; durum App Group'ta (`salah_dhikr_v1`) tutulur, böylece ana ekrandan sayılan zikir uygulamada da görünür.
/// Android `core/dhikr/DhikrStore.kt` aynı kurallar.
/// Tesbihat: Müslim, Mesâcid 146 (33 Sübhânallâh, 33 Elhamdülillâh, 33 Allâhü ekber, bir tehlil ile yüze tamamlanır).
nonisolated enum DhikrShared {
  static let suite = "group.com.onur6541.salah.shared"
  static let key = "salah_dhikr_v1"

  /// Arapça metinler (ad, okunuş ve anlam dil dosyalarında).
  static let arabic: [String: String] = [
    "subhanallah": "سُبْحَانَ اللّٰهِ",
    "elhamdulillah": "اَلْحَمْدُ لِلّٰهِ",
    "allahuekber": "اَللّٰهُ اَكْبَرُ",
    "tehlil": "لَا اِلٰهَ اِلَّا اللّٰهُ",
    "istigfar": "اَسْتَغْفِرُ اللّٰهَ",
    "salavat": "اَللّٰهُمَّ صَلِّ عَلٰى مُحَمَّدٍ",
    "tesbihatClosing": "لَا اِلٰهَ اِلَّا اللّٰهُ وَحْدَهُ لَا شَرِيكَ لَهُ لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلٰى كُلِّ شَيْءٍ قَدِيرٌ",
  ]
  /// Serbest zikirler ve varsayılan hedefleri.
  static let items: [(id: String, target: Int)] = [
    ("subhanallah", 33), ("elhamdulillah", 33), ("allahuekber", 33), ("tehlil", 100), ("istigfar", 100), ("salavat", 100),
  ]
  static let steps: [(id: String, target: Int)] = [("subhanallah", 33), ("elhamdulillah", 33), ("allahuekber", 33), ("tesbihatClosing", 1)]

  struct Tesbihat: Codable, Equatable, Sendable {
    var step = 0
    var count = 0
    var done = false
  }

  enum Event: Equatable, Sendable { case counted, stepDone, finished }

  struct State: Codable, Equatable, Sendable {
    var mode = "tesbihat"
    var tesbihat = Tesbihat()
    var itemId = "subhanallah"
    var target = 33
    var count = 0
    var day = ""
    var today = 0
    var completedTesbihat = 0

    /// Ekranda gösterilen zikir, sayı ve hedef.
    var current: (id: String, count: Int, target: Int) {
      if mode == "free" { return (itemId, count, target) }
      let step = DhikrShared.steps[min(tesbihat.step, DhikrShared.steps.count - 1)]
      return (step.id, tesbihat.done ? step.target : tesbihat.count, step.target)
    }

    func todayCount(_ now: Date = Date()) -> Int { day == DhikrShared.dayString(now) ? today : 0 }
  }

  /// Tesbihatta bir dokunuş: adım dolunca sonrakine geçer, son adımda tamamlanır.
  static func tap(_ s: Tesbihat) -> (Tesbihat, Event) {
    guard !s.done else { return (s, .finished) }
    var next = s
    next.count += 1
    guard next.count >= steps[next.step].target else { return (next, .counted) }
    if next.step == steps.count - 1 {
      next.done = true
      return (next, .finished)
    }
    next.step += 1
    next.count = 0
    return (next, .stepDone)
  }

  /// Serbest zikirde hedefe ulaşıldı mı (0 = hedefsiz); hedefin katlarında da.
  static func reachedTarget(count: Int, target: Int) -> Bool { target > 0 && count > 0 && count % target == 0 }

  /// Bir dokunuş (gün değiştiyse günlük toplam sıfırlanır).
  static func tap(_ state: State, now: Date = Date()) -> (State, Event) {
    var s = rolled(state, now: now)
    var event = Event.counted
    if s.mode == "free" {
      s.count += 1
      if reachedTarget(count: s.count, target: s.target) { event = .stepDone }
    } else {
      guard !s.tesbihat.done else { return (s, .finished) }
      (s.tesbihat, event) = tap(s.tesbihat)
      if event == .finished { s.completedTesbihat += 1 }
    }
    s.today += 1
    return (s, event)
  }

  static func rolled(_ state: State, now: Date = Date()) -> State {
    let day = dayString(now)
    guard state.day != day else { return state }
    var s = state
    s.day = day
    s.today = 0
    s.completedTesbihat = 0
    return s
  }

  static func dayString(_ d: Date) -> String {
    let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
    return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
  }

  static func load(_ defaults: UserDefaults? = UserDefaults(suiteName: suite)) -> State? {
    guard let data = defaults?.data(forKey: key) else { return nil }
    return try? JSONDecoder().decode(State.self, from: data)
  }

  static func save(_ state: State, _ defaults: UserDefaults? = UserDefaults(suiteName: suite)) {
    guard let data = try? JSONEncoder().encode(state) else { return }
    defaults?.set(data, forKey: key)
  }
}
