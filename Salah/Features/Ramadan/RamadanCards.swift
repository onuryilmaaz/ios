import SwiftUI

/// Üst alanın altındaki Ramazan kartı: öncesinde yaklaşan gün sayısı, ayda yolculuk ve oruç defteri girişi.
struct RamadanCard: View {
  @Environment(\.tokens) private var tokens
  let today: PrayerDay?
  let onImsakiye: () -> Void
  let onHatim: () -> Void
  let onJournal: () -> Void
  @State private var religious = ReligiousCalendarService.cached()

  var body: some View {
    TimelineView(.everyMinute) { context in
      let window = RamadanSchedule.window(religious, now: context.date)
      switch RamadanSchedule.phase(window, now: context.date, today: today?.times) {
      case .none: EmptyView()
      case .upcoming(let daysLeft, let start): upcoming(daysLeft, start)
      case .active(let day, let total, _):
        RamadanJourneyCard(window: window, total: total, onJournal: onJournal, onHatim: onHatim)
        LastNightsCard(window: window)
        RamadanVerseCard(day: day)
      }
    }
    .task { religious = await ReligiousCalendarService.load() }
  }

  private func upcoming(_ daysLeft: Int, _ start: Date) -> some View {
    Button {
      Haptics.impact(.light)
      onImsakiye()
    } label: {
      BannerRow(icon: "moon-outline", iconColor: tokens.accent, iconBackground: tokens.isDark ? Accent.s900 : Accent.s50) {
        Text(daysLeft == 1 ? t("ramadan.upcoming.tomorrow") : t("ramadan.upcoming.title", ["days": daysLeft]))
          .font(.system(size: 15, weight: .semibold)).foregroundStyle(tokens.textPrimary)
        Text(t("ramadan.upcoming.subtitle", ["date": start.formatted(Date.FormatStyle.dateTime.day().month(.wide).locale(Localizer.shared.locale))]))
          .font(.system(size: 13)).foregroundStyle(tokens.textSecondary).padding(.top, 1.75)
      } trailing: {
        Ionicon(dirIcon("chevron-forward"), size: 16, color: tokens.inkSubtle)
      }
    }
    .buttonStyle(PressableStyle())
  }
}

/// Ana sayfa hatim planı kartı: yalnız plan varken ve girişliyken.
struct HatimPlanCard: View {
  @Environment(\.tokens) private var tokens
  @Environment(\.openURL) private var openURL
  let onOpen: () -> Void

  var body: some View {
    if HatimPlanStore.shared.plan != nil, AuthStore.shared.isAuthenticated, RamadanMode.shared.isOn() {
      Card {
        Button {
          Haptics.impact(.light)
          onOpen()
        } label: {
          HStack(spacing: 10.5) {
            Ionicon("book-outline", size: 20, color: tokens.accent)
              .frame(width: 35, height: 35)
              .background(tokens.isDark ? Accent.s900 : Accent.s50, in: .circle)
            VStack(alignment: .leading, spacing: 1.75) {
              Text(t("hatim.card.title")).font(.system(size: 15, weight: .semibold)).foregroundStyle(tokens.textPrimary)
              Text(subtitle).font(.system(size: 13)).foregroundStyle(tokens.textSecondary).tabularNumbers()
            }
            Spacer(minLength: 0)
            Ionicon(dirIcon("chevron-forward"), size: 16, color: tokens.inkSubtle)
          }
        }
        .buttonStyle(PressableStyle())
        if let p = HatimPlanStore.shared.progress(), !p.finished, !p.overdue {
          HatimBar(value: Double(p.todayRead) / Double(max(1, p.dailyTarget)))
            .padding(.top, 12.25)
          AppButton(title: t(p.todayDone ? "hatim.card.logMore" : "hatim.card.log"), variant: p.todayDone ? .outline : .primary) {
            Haptics.impact(.light)
            if let url = URL(string: "salah://tracker/quran") { openURL(url) }
          }
          .padding(.top, 12.25)
        }
      }
      .padding(.horizontal, 14)
      .padding(.bottom, 14)
      .task { if InsightsStore.shared.quran == nil { await InsightsStore.shared.fetchAll() } }
    }
  }

  private var subtitle: String {
    guard let p = HatimPlanStore.shared.progress() else { return t("common.loading") }
    if p.finished { return t("hatim.card.finished") }
    if p.overdue { return t("hatim.card.overdue") }
    return t("hatim.card.today", ["read": p.todayRead, "target": p.dailyTarget, "days": p.daysLeft])
  }
}

private struct HatimBar: View {
  @Environment(\.tokens) private var tokens
  let value: Double

  var body: some View {
    Capsule().fill(tokens.fill).frame(height: 6)
      .overlay(alignment: .leading) {
        GeometryReader { geo in
          Capsule().fill(tokens.accent).frame(width: geo.size.width * min(1, max(0, value)))
        }
      }
      .clipShape(.capsule)
      .accessibilityHidden(true)
  }
}

/// Ramazan penceresi ve durumu; Debug önizlemesinde `-SalahDebugRamadan` ile kurgusal tarih.
@MainActor
enum RamadanSchedule {
  static func window(_ religious: ReligiousCalendar, now: Date = Date(), calendar: Calendar = .current) -> RamadanWindow {
    #if DEBUG
    if let preview = DebugLaunch.ramadan {
      let today = calendar.startOfDay(for: now)
      let offset = preview == "upcoming" ? 12 : preview == "last" ? -28 : -4
      let start = calendar.date(byAdding: .day, value: offset, to: today)!
      return .init(hijriYear: 9999, start: start, last: calendar.date(byAdding: .day, value: 28, to: start)!, days: 29)
    }
    #endif
    let real = RamadanPlan.window(religious, now: now, calendar: calendar)
    return RamadanPlan.usesPreview(stored: RamadanMode.shared.stored, real: real, now: now, calendar: calendar)
      ? RamadanPlan.previewWindow(now: now, calendar: calendar) : real
  }

  /// Mod açıksa son on gece bildirimi. Önizlemede de gerçek takvime bakar: kurgusal geceye bildirim kurulmaz.
  static func nightsReminder(now: Date = Date(), calendar: Calendar = .current) -> RamadanNightsReminder? {
    guard RamadanMode.shared.isOn(now: now, calendar: calendar) else { return nil }
    let real = RamadanPlan.window(ReligiousCalendarService.cached(), now: now, calendar: calendar)
    return .init(nights: RamadanPlan.lastNights(real, calendar: calendar), kadir: RamadanPlan.kadirDate(real, calendar: calendar))
  }

  /// Ramazan'da Dinamik Ada çizelgesi; mod kapalı ya da gün dışındaysa nil.
  static func liveTimeline(today: PrayerTimes, now: Date = Date(), calendar: Calendar = .current) -> [(at: Date, window: PrayerWindow)]? {
    guard RamadanMode.shared.isOn(now: now, calendar: calendar) else { return nil }
    let w = window(ReligiousCalendarService.cached(), now: now, calendar: calendar)
    let days = PrayerTimesService.cachedDays(districtId: Locations.selectedDistrictId)
    let steps = RamadanPlan.countdownSteps(w, now: now, calendar: calendar) { day in
      calendar.isDate(day, inSameDayAs: now) ? today : days.first { $0.localDay == day }?.times
    }
    guard !steps.isEmpty else { return nil }
    return steps.map { step in
      var iftar = step.kind == .iftar
      #if DEBUG
      if let forced = UserDefaults.standard.string(forKey: "SalahDebugLive") { iftar = forced == "iftar" }
      #endif
      return (step.at, PrayerWindow(mode: .upcoming, prayerName: iftar ? "İftar" : "Sahur", start: nil, end: step.target, nextPrayer: iftar ? "Sahur" : "İftar"))
    }
  }

  static func phase(_ window: RamadanWindow, now: Date = Date(), today: PrayerTimes?, calendar: Calendar = .current) -> RamadanPhase {
    if RamadanMode.shared.isForcedOff { return .none }
    let next = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
    let tomorrow = PrayerTimesService.cachedDays(districtId: Locations.selectedDistrictId).first { $0.localDay == next }?.times
    return RamadanPlan.phase(window, now: now, today: today, tomorrow: tomorrow ?? today, calendar: calendar)
  }
}
