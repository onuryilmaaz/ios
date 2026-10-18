import Foundation

struct PlannedNotification: Equatable, Sendable {
  enum Kind: String, Sendable { case prayerTime = "prayer_time", prayerReminder = "prayer_reminder", inspiration = "spiritual_reminder", religiousDay = "religious_day", friday = "cuma_reminder" }
  var id: String
  var date: Date
  var kind: Kind
  var prayerKey: String = ""
  var offset: Int = 0
  var adhan = false
  var dayID = ""
  var when = ""
  var title = ""
  var subtitle = ""
  var body = ""
  var arabic = ""
  var contentType = "ayet"
}

struct NotificationInspiration: Equatable, Sendable {
  var id: String
  var contentType: String
  var subtitle: String
  var body: String
  var arabic = ""
}

/// Saf planlayıcı: saat, takvim ve içerik havuzları dışarıdan verilir.
/// RN: services/notification.service.ts. Tarihler mutlak, saatler yereldir.
enum NotificationPlan {
  static let budget = 62
  static let prayerLimit = 44
  static let daysAhead = 3
  static let throttle: TimeInterval = 48 * 3600

  static func shouldRefresh(last: Double?, now: Date, force: Bool, hasPending: Bool) -> Bool {
    guard !force, hasPending, let last, last.isFinite else { return true }
    let elapsed = now.timeIntervalSince1970 * 1000 - last
    return elapsed < 0 || elapsed >= throttle * 1000
  }

  static func build(
    days: [PrayerDay], preferences p: NotificationPreferences, now: Date,
    calendar: Calendar = .current, verses: [NotificationInspiration] = [], hadiths: [NotificationInspiration] = [],
    religiousDays: [ReligiousDay] = [], alarmCovered: Set<String> = []
  ) -> [PlannedNotification] {
    guard p.enabled else { return [] }
    // Sessiz aralık sonrasını ŞİMDİ kur: uygulama kapalıyken de süre bitince
    // teslimat devam eder. Sessiz aralıktaki bildirimler atlanır.
    let cutoff = max(now, p.muteUntil ?? now)
    var plan: [PlannedNotification] = []
    for day in days.prefix(daysAhead) {
      guard let base = parseDay(day.date, calendar: calendar) else { continue }
      for key in NotificationPreferences.prayers where p.prayerEnabled[key] == true {
        guard let raw = day.times[key], let exact = clock(raw, on: base, calendar: calendar) else { continue }
        for offset in p.offsets where plan.count < prayerLimit {
          guard offset >= 0 else { continue }
          if offset == 0 && alarmCovered.contains(key) { continue }
          let date = exact.addingTimeInterval(-Double(offset) * 60)
          guard date > cutoff else { continue }
          plan.append(.init(id: "prayer.\(Int(exact.timeIntervalSince1970)).\(key).\(offset)", date: date,
                            kind: offset == 0 ? .prayerTime : .prayerReminder, prayerKey: key, offset: offset,
                            adhan: offset == 0 && key != "gunes" && p.adhanEnabled[key] == true))
        }
      }
    }

    if p.inspiration {
      let available = max(0, budget - plan.count - 8)
      let slots = Array(inspirationSlots(now: now, calendar: calendar).filter { $0 > cutoff }.prefix(available))
      let poolV = unique(verses.filter { ($0.body as NSString).length >= 60 })
      let poolH = unique(hadiths.filter { !$0.body.isEmpty })
      var vi = 0, hi = 0
      for (index, date) in slots.enumerated() {
        let useVerse = (index % 2 == 0 && !poolV.isEmpty) || poolH.isEmpty
        let pool = useVerse ? poolV : poolH
        guard !pool.isEmpty else { continue }
        let item = pool[(useVerse ? vi : hi) % pool.count]
        if useVerse { vi += 1 } else { hi += 1 }
        plan.append(.init(id: "inspiration.\(Int(date.timeIntervalSince1970))", date: date, kind: .inspiration,
                          title: t(useVerse ? "notif.verseTitle" : "notif.hadithTitle"), subtitle: item.subtitle,
                          body: item.body, arabic: item.arabic, contentType: useVerse ? "ayet" : "hadis"))
      }
    }

    let religiousLimit = max(0, budget - plan.count - 2)
    if p.religiousDays {
      var count = 0
      for day in religiousDays.filter({ $0.date >= now }).sorted(by: { $0.date < $1.date }).prefix(3) {
        for (delta, hour, when) in [(-1, 20, "before"), (0, 8, "morning")] where count < religiousLimit {
          guard let shifted = calendar.date(byAdding: .day, value: delta, to: day.date),
            let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: shifted), date > cutoff
          else { continue }
          let vars = ["name": day.name, "date": day.hijriDate]
          let prefix = when == "before" ? "notif.dayBefore" : "notif.dayOf"
          plan.append(.init(id: "religious.\(day.id).\(when)", date: date, kind: .religiousDay, dayID: day.id, when: when,
                            title: t(prefix + "Title", vars), subtitle: t("notif.blessedDay"), body: t(prefix + "Body", vars)))
          count += 1
        }
      }
    }

    if p.friday {
      let start = calendar.startOfDay(for: now)
      let delta = (6 - calendar.component(.weekday, from: start) + 7) % 7
      if let friday = calendar.date(byAdding: .day, value: delta, to: start) {
        for (shift, hour, when, prefix) in [(-1, 20, "thursday_evening", "notif.cumaEve"), (0, 9, "friday_morning", "notif.cuma")] where plan.count < budget {
          guard let day = calendar.date(byAdding: .day, value: shift, to: friday),
            let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day), date > cutoff
          else { continue }
          plan.append(.init(id: "friday.\(Int(date.timeIntervalSince1970))", date: date, kind: .friday, when: when,
                            title: t(prefix + "Title"), subtitle: t(prefix + "Subtitle"), body: t(prefix + "Body")))
        }
      }
    }
    return plan
  }

  static func inspirationSlots(now: Date, calendar: Calendar = .current) -> [Date] {
    stride(from: 2, through: 72, by: 2).compactMap { hour in
      let future = now.addingTimeInterval(Double(hour) * 3600)
      guard let date = calendar.dateInterval(of: .hour, for: future)?.start else { return nil }
      let h = calendar.component(.hour, from: date)
      return h >= 7 && h < 23 ? date : nil
    }.prefix(24).map { $0 }
  }

  static func parseDay(_ raw: String, calendar: Calendar) -> Date? {
    if raw.count == 10 {
      let pieces = raw.split(separator: "-").compactMap { Int($0) }
      guard pieces.count == 3 else { return nil }
      return calendar.date(from: DateComponents(year: pieces[0], month: pieces[1], day: pieces[2]))
    }
    guard let date = ISO8601DateFormatter.withFractionalSeconds.date(from: raw) ?? ISO8601DateFormatter().date(from: raw) else { return nil }
    return calendar.startOfDay(for: date)
  }

  static func clock(_ raw: String, on day: Date, calendar: Calendar) -> Date? {
    let parts = raw.split(separator: ":").compactMap { Int($0) }
    guard parts.count == 2, (0...23).contains(parts[0]), (0...59).contains(parts[1]) else { return nil }
    return calendar.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: day)
  }

  private static func unique(_ items: [NotificationInspiration]) -> [NotificationInspiration] {
    var seen = Set<String>()
    return items.filter { seen.insert($0.id).inserted }
  }
}
