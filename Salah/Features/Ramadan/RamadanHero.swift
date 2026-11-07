import SwiftUI

/// Ayın aydınlık kısmı (birim çizgi RamadanMoon.outline).
struct RamadanMoonShape: Shape {
  let day: Int

  func path(in rect: CGRect) -> Path {
    let r = min(rect.width, rect.height) / 2
    let c = CGPoint(x: rect.midX, y: rect.midY)
    var path = Path()
    for (i, p) in RamadanMoon.outline(day: day).enumerated() {
      let point = CGPoint(x: c.x + p.x * r, y: c.y + p.y * r)
      if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
    }
    path.closeSubpath()
    return path
  }
}

/// Ramazan gününün ayı: disk üzerinde aydınlık kısım. Ay aynalanmaz, RTL'de de aynı yöne bakar.
struct RamadanMoonView: View {
  let day: Int
  let size: CGFloat
  let disc: Color
  let lit: Color
  var ring: Color?

  var body: some View {
    let inset: CGFloat = ring == nil ? 0 : 2
    ZStack {
      Circle().fill(disc).padding(inset)
      RamadanMoonShape(day: day).fill(lit).padding(inset)
      if let ring { Circle().stroke(ring, lineWidth: 1.5).padding(inset) }
    }
    .frame(width: size, height: size)
    .environment(\.layoutDirection, .leftToRight)
    .accessibilityHidden(true)
  }
}

/// Ana sayfanın üst alanı: Ramazan gününde Hilal, diğer günlerde normal vakit sayacı.
struct HomeHero: View {
  let today: PrayerDay?
  let isLoading: Bool
  let locationName: String
  let onLocation: () -> Void
  let onAlarms: () -> Void
  let onImsakiye: () -> Void
  @State private var religious = ReligiousCalendarService.cached()

  var body: some View {
    TimelineView(.everyMinute) { context in
      let window = RamadanSchedule.window(religious, now: context.date)
      if case .active(let day, _, let countdown) = RamadanSchedule.phase(window, now: context.date, today: today?.times) {
        RamadanHero(window: window, day: day, countdown: countdown, today: today, locationName: locationName, onLocation: onLocation, onAlarms: onAlarms, onImsakiye: onImsakiye)
      } else {
        PrayerHeroCard(today: today, isLoading: isLoading, locationName: locationName, onLocation: onLocation, onAlarms: onAlarms)
      }
    }
    .task { religious = await ReligiousCalendarService.load() }
  }
}

/// Hilal yönü: gün, ay ve iftar/sahur sayacı tek alanda.
struct RamadanHero: View {
  let window: RamadanWindow
  let day: Int
  let countdown: RamadanCountdown?
  let today: PrayerDay?
  let locationName: String
  let onLocation: () -> Void
  let onAlarms: () -> Void
  let onImsakiye: () -> Void

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      content(now: context.date)
    }
  }

  private func content(now: Date) -> some View {
    let store = RamadanStore.shared
    let key = localDateString(now)
    let fasted = store.isFasted(key, hijriYear: window.hijriYear)
    let headline = t(countdown?.kind == .sahur ? "ramadan.untilSahur" : "ramadan.untilIftar")
    return VStack(alignment: .leading, spacing: 0) {
      Text(t("ramadan.day", ["day": day]))
        .font(.system(size: 15, weight: .semibold)).foregroundStyle(Gold.s300)
      // Ay sağ üstte: hapların uzun adı ona binmesin.
      pills.padding(.top, 8).padding(.trailing, 100)
      Text(headline).font(.system(size: 16)).foregroundStyle(.white.opacity(0.85)).padding(.top, 26)
      Countdown(target: countdown?.target, now: now)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(headline)
      if let times = today?.times {
        HStack(spacing: 21) {
          // İftardan sonra geri sayım yarının sahurunda: saat de onun.
          slot("ramadan.sahur", countdown?.kind == .sahur ? formatHHMM(countdown!.target) : times["imsak"] ?? "")
          slot("ramadan.iftar", times["aksam"] ?? "")
        }
        Text(nextPrayer(times, now: now))
          .font(.system(size: 13)).foregroundStyle(.white.opacity(0.72)).tabularNumbers().padding(.top, 5)
      }
      HStack(spacing: 10.5) {
        Button {
          Haptics.impact(.medium)
          Task { await store.toggle(key, hijriYear: window.hijriYear) }
        } label: {
          HStack(spacing: 7) {
            Ionicon(fasted ? "checkmark-circle" : "ellipse-outline", size: 18, color: fasted ? Accent.s900 : Gold.s300)
            Text(t(fasted ? "ramadan.fasted" : "ramadan.fastToday")).font(.system(size: 15, weight: .semibold))
              .foregroundStyle(fasted ? Accent.s900 : .white).lineLimit(1)
          }
          .padding(.horizontal, 17).padding(.vertical, 12)
          .background(fasted ? Gold.s300 : .white.opacity(0.1), in: .capsule)
        }
        .buttonStyle(PressableStyle())
        Button {
          Haptics.impact(.light)
          onImsakiye()
        } label: {
          Text(t("imsakiye.short")).font(.system(size: 15, weight: .medium)).foregroundStyle(.white).lineLimit(1)
            .padding(.horizontal, 17).padding(.vertical, 12)
            .background(.white.opacity(0.1), in: .capsule)
        }
        .buttonStyle(PressableStyle())
      }
      .padding(.top, 15)
    }
    .padding(.horizontal, 17.5)
    .padding(.top, 10.5)
    .padding(.bottom, 17.5)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(alignment: .topTrailing) {
      RamadanMoonView(day: day, size: 92, disc: Accent.s800, lit: Gold.s300).padding(.top, 10.5).padding(.trailing, 17.5)
    }
  }

  private var pills: some View {
    HStack(spacing: 7) {
      if !locationName.isEmpty {
        Button {
          Haptics.impact(.light)
          onLocation()
        } label: {
          HStack(spacing: 3.5) {
            Ionicon("location", size: 12, color: .white.opacity(0.75))
            Text(locationName).font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.85)).lineLimit(1)
          }
          .padding(.horizontal, 8.75).padding(.vertical, 3.5)
          .background(.white.opacity(0.1), in: .capsule)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(t("settings.location.prayerLocation")): \(locationName)")
        .tourAnchor("home.location")
      }
      if AlarmStore.shared.supported {
        let next = AlarmStore.shared.authorized ? AlarmStore.shared.next : nil
        Button {
          Haptics.impact(.light)
          onAlarms()
        } label: {
          HStack(spacing: 3.5) {
            Ionicon(next == nil ? "alarm-outline" : "alarm", size: 12, color: next == nil ? .white.opacity(0.75) : Gold.s300)
            Text(next.map { formatHHMM($0.fireAt) } ?? t("alarm.quick.pill"))
              .font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.85)).tabularNumbers()
          }
          .padding(.horizontal, 8.75).padding(.vertical, 3.5)
          .background(.white.opacity(0.1), in: .capsule)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(t("alarm.screen.title"))
        .tourAnchor("home.alarms")
      }
    }
  }

  private func nextPrayer(_ times: PrayerTimes, now: Date) -> String {
    let w = PrayerWindow.compute(times, completed: GamificationStore.shared.stats?.today_prayers ?? [], now: now)
    let name = w.mode == .current ? w.nextPrayer : w.prayerName
    return t("ramadan.nextPrayer", ["prayer": prayerLabel(name), "time": formatHHMM(w.end)])
  }

  private func slot(_ key: String, _ time: String) -> some View {
    HStack(spacing: 5.25) {
      Text(t(key)).font(.system(size: 14)).foregroundStyle(.white.opacity(0.75))
      Text(time).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white).tabularNumbers()
    }
  }
}

/// 29 küçük ay; dokununca oruç defteri açılır. Hatim planı yoksa altında davet.
struct RamadanJourneyCard: View {
  @Environment(\.tokens) private var tokens
  let window: RamadanWindow
  let total: Int
  let onJournal: () -> Void
  let onHatim: () -> Void

  var body: some View {
    let store = RamadanStore.shared
    let today = localDateString()
    Card {
      Button {
        Haptics.impact(.light)
        onJournal()
      } label: {
        VStack(alignment: .leading, spacing: 12) {
          HStack(spacing: 5) {
            Text(t("ramadan.journey.title")).font(.system(size: 17, weight: .semibold)).foregroundStyle(tokens.textPrimary)
            Spacer(minLength: 0)
            Text(t("ramadan.fastCount", ["count": store.count(hijriYear: window.hijriYear), "total": total]))
              .font(.system(size: 13)).foregroundStyle(tokens.textSecondary).tabularNumbers()
            Ionicon(dirIcon("chevron-forward"), size: 14, color: tokens.inkSubtle)
          }
          VStack(spacing: 7) {
            ForEach(Array(stride(from: 1, through: total, by: 15)), id: \.self) { first in
              HStack(spacing: 0) {
                ForEach(0..<15, id: \.self) { slot in
                  let day = first + slot
                  Group {
                    if day <= total { moon(day, today: today) } else { Color.clear.frame(height: 18) }
                  }
                  .frame(maxWidth: .infinity)
                }
              }
            }
          }
        }
        .contentShape(.rect)
      }
      .buttonStyle(PressableStyle(pressedOpacity: 0.85))
      if HatimPlanStore.shared.plan == nil {
        Button {
          Haptics.impact(.light)
          onHatim()
        } label: {
          HStack(spacing: 7) {
            Ionicon("book-outline", size: 15, color: tokens.accent)
            Text(t("ramadan.hatimCta")).font(.system(size: 14, weight: .medium)).foregroundStyle(tokens.textPrimary)
            Spacer(minLength: 0)
            Ionicon(dirIcon("chevron-forward"), size: 14, color: tokens.inkSubtle)
          }
        }
        .buttonStyle(PressableStyle())
        .padding(.top, 14)
      }
    }
    .padding(.horizontal, 14)
    .padding(.bottom, 14)
  }

  private func moon(_ day: Int, today: String) -> some View {
    let date = localDateString(Calendar.current.date(byAdding: .day, value: day - 1, to: window.start) ?? window.start)
    let done = RamadanStore.shared.isFasted(date, hijriYear: window.hijriYear)
    let isToday = date == today
    let lit: Color = done || isToday ? Gold.s300 : date < today ? Forest.s400 : tokens.inkSubtle.opacity(0.3)
    return RamadanMoonView(day: day, size: 18, disc: done || isToday ? Accent.s900 : tokens.fill, lit: lit, ring: isToday ? Gold.s500 : nil)
  }
}

/// Akşam vaktinden sonra ana sayfada günde bir kez iftar anı ekranını açar.
struct IftarMomentHost: View {
  private static let shownKey = "@salah_iftar_moment_v1"
  let today: PrayerDay?
  let blocked: Bool
  @State private var window: RamadanWindow?
  @State private var religious = ReligiousCalendarService.cached()

  var body: some View {
    Color.clear
      .frame(width: 0, height: 0)
      .task(id: Trigger(day: today?.date, blocked: blocked)) {
        religious = await ReligiousCalendarService.load()
        while !Task.isCancelled {
          check()
          try? await Task.sleep(for: .seconds(60))
        }
      }
      .fullScreenCover(isPresented: Binding(get: { window != nil }, set: { if !$0 { window = nil } })) {
        if let window { IftarMomentView(window: window, today: today) { self.window = nil } }
      }
  }

  private struct Trigger: Equatable {
    let day: String?
    let blocked: Bool
  }

  private func check() {
    guard !blocked, window == nil else { return }
    let current = RamadanSchedule.window(religious)
    #if DEBUG
    // Kurgusal önizleme ekran görüntülerinde kendiliğinden açılmasın: yalnız bayrakla.
    if DebugLaunch.ramadan != nil {
      if UserDefaults.standard.bool(forKey: "SalahDebugIftar") { window = current }
      return
    }
    #endif
    guard !RamadanMode.shared.isForcedOff else { return }
    let shown = UserDefaults.standard.string(forKey: Self.shownKey)
    if RamadanPlan.iftarMomentDue(current, now: Date(), today: today?.times, shownDay: shown, calendar: .current) {
      UserDefaults.standard.set(localDateString(), forKey: Self.shownKey)
      window = current
    }
  }
}

struct IftarMomentView: View {
  @Environment(\.tokens) private var tokens
  let window: RamadanWindow
  let today: PrayerDay?
  let onClose: () -> Void

  var body: some View {
    let store = RamadanStore.shared
    let now = Date()
    let key = localDateString(now)
    let fasted = store.isFasted(key, hijriYear: window.hijriYear)
    let calendar = Calendar.current
    let day = max(1, (calendar.dateComponents([.day], from: window.start, to: calendar.startOfDay(for: now)).day ?? 0) + 1)
    let next = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
    let sahur = next <= window.last ? PrayerTimesService.cachedDays(districtId: Locations.selectedDistrictId).first { $0.localDay == next }?.times["imsak"] : nil
    return ZStack {
      Accent.s900.ignoresSafeArea()
      GeometryReader { geo in
        let h = geo.size.height
        ZStack {
          Circle().fill(Accent.s800).frame(width: h * 1.12, height: h * 1.12).position(x: geo.size.width / 2, y: h)
          Circle().fill(Accent.s700).frame(width: h * 0.72, height: h * 0.72).position(x: geo.size.width / 2, y: h)
        }
      }
      .ignoresSafeArea()
      VStack(spacing: 0) {
        HStack {
          Spacer()
          Button {
            Haptics.impact(.light)
            onClose()
          } label: {
            Ionicon("close", size: 20, color: .white).frame(width: 44, height: 44).background(.white.opacity(0.1), in: .circle)
          }
          .buttonStyle(PressableStyle())
          .accessibilityLabel(t("common.close"))
        }
        RamadanMoonView(day: day, size: 130, disc: Accent.s800, lit: Gold.s300).padding(.top, 8)
        Text(t("iftarMoment.adhan", ["time": today?.times["aksam"] ?? ""]))
          .font(.system(size: 15, weight: .semibold)).foregroundStyle(Gold.s300).tabularNumbers().padding(.top, 30)
        Text(t("iftarMoment.title")).font(.system(size: 32, weight: .bold)).foregroundStyle(.white).multilineTextAlignment(.center).padding(.top, 7)
        Text(t("iftarMoment.accept")).font(.system(size: 16)).foregroundStyle(.white.opacity(0.85)).padding(.top, 9)
        VStack(spacing: 10.5) {
          if !fasted {
            Button {
              Haptics.impact(.medium)
              Task { await store.toggle(key, hijriYear: window.hijriYear) }
            } label: {
              Text(t("iftarMoment.mark")).font(.system(size: 16, weight: .semibold)).foregroundStyle(Accent.s900)
                .frame(maxWidth: .infinity).padding(.vertical, 15).background(Gold.s300, in: .capsule)
            }
            .buttonStyle(PressableStyle())
          }
          Button {
            Haptics.impact(.light)
            onClose()
            HomeNavigation.shared.path.append(.dua)
          } label: {
            Text(t("iftarMoment.duas")).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
              .frame(maxWidth: .infinity).padding(.vertical, 15)
              .overlay(Capsule().stroke(.white.opacity(0.35), lineWidth: 1))
          }
          .buttonStyle(PressableStyle())
        }
        .padding(.top, 28)
        Spacer(minLength: 12)
        HStack(spacing: 10.5) {
          if let sahur { tile("iftarMoment.tomorrowSahur", sahur) }
          tile("iftarMoment.progress", "\(day) / \(window.days)")
        }
      }
      .padding(.horizontal, 24)
      .padding(.vertical, 14)
    }
    .statusBar(.light, priority: 1)
  }

  private func tile(_ key: String, _ value: String) -> some View {
    VStack(alignment: .leading, spacing: 1) {
      Text(t(key)).font(.system(size: 13)).foregroundStyle(.white.opacity(0.8))
      Text(value).font(.system(size: 24, weight: .semibold)).foregroundStyle(.white).tabularNumbers()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 16).padding(.vertical, 13)
    .background(Accent.s900, in: .rect(cornerRadius: 21))
  }
}
