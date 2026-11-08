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
        RamadanHero(tint: RamadanTint.current(today?.times, now: context.date), window: window, day: day, countdown: countdown, today: today, locationName: locationName, onLocation: onLocation, onAlarms: onAlarms, onImsakiye: onImsakiye)
      } else {
        PrayerHeroCard(today: today, isLoading: isLoading, locationName: locationName, onLocation: onLocation, onAlarms: onAlarms)
      }
    }
    .task { religious = await ReligiousCalendarService.load() }
  }
}

/// Hilal yönü: gün, ay ve iftar/sahur sayacı tek alanda.
struct RamadanHero: View {
  let tint: RamadanTint
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
        .font(.system(size: 15, weight: .semibold)).foregroundStyle(tint.accent)
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
            Ionicon(fasted ? "checkmark-circle" : "ellipse-outline", size: 18, color: fasted ? tint.hero : tint.accent)
            Text(t(fasted ? "ramadan.fasted" : "ramadan.fastToday")).font(.system(size: 15, weight: .semibold))
              .foregroundStyle(fasted ? tint.hero : .white).lineLimit(1)
          }
          .padding(.horizontal, 17).padding(.vertical, 12)
          .background(fasted ? tint.accent : .white.opacity(0.1), in: .capsule)
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
      RamadanMoonView(day: day, size: 92, disc: tint.surface, lit: tint.accent).padding(.top, 10.5).padding(.trailing, 17.5)
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
            Ionicon(next == nil ? "alarm-outline" : "alarm", size: 12, color: next == nil ? .white.opacity(0.75) : tint.accent)
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
      teravihRow(today: today).padding(.top, 14)
      HStack(spacing: 8) {
        if AppControlStore.shared.isOn("zakat") { tile("calculator-outline", "ramadan.tile.zakat", "ramadan.tile.zakatHint") { HomeNavigation.shared.path.append(.zakat) } }
        if AppControlStore.shared.isOn("hatim_groups") { tile("people-outline", "ramadan.tile.groups", "ramadan.tile.groupsHint") { HomeNavigation.shared.path.append(.hatimGroups) } }
        if HatimPlanStore.shared.plan == nil, AppControlStore.shared.isOn("hatim_plan") { tile("book-outline", "ramadan.tile.hatim", "ramadan.tile.hatimHint", onHatim) }
      }
      .fixedSize(horizontal: false, vertical: true)
      .padding(.top, 10)
    }
    .padding(.horizontal, 14)
    .padding(.bottom, 14)
  }

  private func teravihRow(today: String) -> some View {
    let store = RamadanStore.shared
    let on = store.isMarked("taraweeh", day: today, hijriYear: window.hijriYear)
    return Button {
      Haptics.impact(.medium)
      Task { await store.toggleMark("taraweeh", day: today, hijriYear: window.hijriYear) }
    } label: {
      HStack(spacing: 7) {
        Ionicon(on ? "checkmark-circle" : "ellipse-outline", size: 18, color: on ? tokens.surface : tokens.accent)
        Text(t(on ? "ramadan.teravih.done" : "ramadan.teravih.mark")).font(.system(size: 14, weight: .semibold)).foregroundStyle(on ? tokens.surface : tokens.textPrimary)
        Spacer(minLength: 0)
        Text(t("ramadan.teravih.count", ["count": store.markCount("taraweeh", hijriYear: window.hijriYear, today: today), "total": total]))
          .font(.system(size: 13)).foregroundStyle(on ? tokens.surface : tokens.textSecondary).tabularNumbers()
      }
      .padding(.horizontal, 14).padding(.vertical, 10)
      .background(on ? tokens.accent : tokens.fill, in: .capsule)
    }
    .buttonStyle(PressableStyle())
  }

  private func tile(_ icon: String, _ title: String, _ hint: String, _ action: @escaping () -> Void) -> some View {
    Button {
      Haptics.impact(.light)
      action()
    } label: {
      VStack(alignment: .leading, spacing: 10) {
        Ionicon(icon, size: 18, color: tokens.accent)
          .frame(width: 36, height: 36)
          .background(tokens.surface, in: .circle)
        VStack(alignment: .leading, spacing: 1) {
          Text(t(title)).font(.system(size: 14, weight: .semibold)).foregroundStyle(tokens.textPrimary).lineLimit(2).minimumScaleFactor(0.85)
          Text(t(hint)).font(.system(size: 12)).foregroundStyle(tokens.textSecondary).lineLimit(2).minimumScaleFactor(0.85)
        }
        Spacer(minLength: 0)
      }
      .padding(12)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .background(tokens.fill, in: .rect(cornerRadius: 16))
      .contentShape(.rect(cornerRadius: 16))
    }
    .buttonStyle(PressableStyle())
  }

  private func moon(_ day: Int, today: String) -> some View {
    let date = localDateString(Calendar.current.date(byAdding: .day, value: day - 1, to: window.start) ?? window.start)
    let done = RamadanStore.shared.isFasted(date, hijriYear: window.hijriYear)
    let isToday = date == today
    let lit: Color = done || isToday ? Gold.s300 : date < today ? Forest.s400 : tokens.inkSubtle.opacity(0.3)
    return RamadanMoonView(day: day, size: 18, disc: done || isToday ? RamadanTint.night.hero : tokens.fill, lit: lit, ring: isToday ? Gold.s500 : nil)
  }
}

/// Son on gecede ana sayfada.
struct LastNightsCard: View {
  @Environment(\.tokens) private var tokens
  let window: RamadanWindow

  var body: some View {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let nights = RamadanPlan.lastNights(window, calendar: calendar)
    if let first = nights.first, today >= first, today <= window.last {
      let done = nights.filter { RamadanStore.shared.isMarked("night", day: localDateString($0), hijriYear: window.hijriYear) }.count
      Card {
        HStack {
          Text(t("ramadan.nights.title")).font(.system(size: 17, weight: .semibold)).foregroundStyle(tokens.textPrimary)
          Spacer(minLength: 6)
          Text(t("ramadan.nights.count", ["done": done])).font(.system(size: 13)).foregroundStyle(tokens.textSecondary).tabularNumbers()
        }
        if let left = RamadanPlan.kadirDaysLeft(window, now: today, calendar: calendar) {
          Text(left == 0 ? t("imsakiye.kadirTonight") : t("imsakiye.kadir", ["days": left]))
            .font(.system(size: 13, weight: .medium)).foregroundStyle(tokens.gold).padding(.top, 2)
        }
        NightsRow(window: window, doneColor: Gold.s300, idleColor: tokens.fill, ink: tokens.textPrimary, doneInk: RamadanTint.night.hero).padding(.top, 12)
      }
      .padding(.horizontal, 14)
      .padding(.bottom, 14)
    }
  }
}

/// On gece, tek sıra. Gelecek geceler işaretlenmez.
struct NightsRow: View {
  let window: RamadanWindow
  let doneColor: Color
  let idleColor: Color
  let ink: Color
  let doneInk: Color

  var body: some View {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let kadir = RamadanPlan.kadirDate(window, calendar: calendar)
    HStack(spacing: 4) {
      ForEach(RamadanPlan.lastNights(window, calendar: calendar), id: \.self) { night in
        let key = localDateString(night)
        let on = RamadanStore.shared.isMarked("night", day: key, hijriYear: window.hijriYear)
        let number = (calendar.dateComponents([.day], from: window.start, to: night).day ?? 0) + 1
        Button {
          Haptics.impact(.light)
          Task { await RamadanStore.shared.toggleMark("night", day: key, hijriYear: window.hijriYear) }
        } label: {
          Text("\(number)").font(.system(size: 12, weight: night == kadir ? .bold : .medium)).foregroundStyle(on ? doneInk : ink).tabularNumbers()
            .frame(maxWidth: .infinity).frame(height: 38)
            .background(on ? doneColor : idleColor, in: .rect(cornerRadius: 10))
            .overlay { if night == kadir { RoundedRectangle(cornerRadius: 10).stroke(doneColor, lineWidth: 1.5) } }
        }
        .buttonStyle(PressableStyle())
        .disabled(night > today)
        .accessibilityLabel("\(t(night == kadir ? "ramadan.nights.kadir" : "ramadan.nights.title")) \(number)")
      }
    }
  }
}

/// Ramazan gününün ayeti: metin uygulamanın Kur'an verisinden, paylaşılabilir.
struct RamadanVerseCard: View {
  @Environment(\.tokens) private var tokens
  let day: Int
  @State private var verse: Verse?
  @State private var source = ""
  @State private var sharing = false

  var body: some View {
    // Boş Group'a bağlı .task hiç çalışmaz: görevin sahibi her zaman var olan bir kapsayıcı.
    VStack(spacing: 0) {
      if let verse {
        Card {
          HStack {
            Text(t("ramadan.verse.title", ["day": day])).font(.system(size: 13, weight: .semibold)).foregroundStyle(tokens.textSecondary)
            Spacer(minLength: 6)
            Button {
              Haptics.impact(.light)
              sharing = true
            } label: {
              Ionicon("share-outline", size: 17, color: tokens.inkSubtle).frame(width: 36, height: 36)
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel(t("common.share"))
          }
          Text(verse.translation.text).font(.system(size: 15)).lineSpacing(4).foregroundStyle(tokens.textPrimary).padding(.top, 2)
          Text(source).font(.system(size: 13, weight: .medium)).foregroundStyle(tokens.gold).padding(.top, 8)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
        .fullScreenCover(isPresented: $sharing) {
          ShareCardSheet(arabic: verse.verse_simplified, text: verse.translation.text, source: source, label: t("ramadan.verse.title", ["day": day]))
            .environment(\.tokens, tokens)
            .presentationBackground(.clear)
        }
      }
    }
    .task(id: day) {
      let ref = RamadanPlan.dailyVerse(day: day)
      guard let found = await QuranService.verse(surahId: ref.surah, verseNumber: ref.verse),
        let surah = await QuranService.surahs().first(where: { $0.id == ref.surah }) else { return }
      source = t("notif.verseRef", ["surah": surahName(surah, withSuffix: true), "verse": ref.verse])
      verse = found
    }
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
  private let tint = RamadanTint.night

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
      tint.hero.ignoresSafeArea()
      GeometryReader { geo in
        let h = geo.size.height
        ZStack {
          Circle().fill(tint.surface).frame(width: h * 1.12, height: h * 1.12).position(x: geo.size.width / 2, y: h)
          Circle().fill(.white.opacity(0.06)).frame(width: h * 0.72, height: h * 0.72).position(x: geo.size.width / 2, y: h)
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
        RamadanMoonView(day: day, size: 96, disc: tint.surface, lit: tint.accent)
        Text(t("iftarMoment.adhan", ["time": today?.times["aksam"] ?? ""]))
          .font(.system(size: 15, weight: .semibold)).foregroundStyle(tint.accent).tabularNumbers().padding(.top, 14)
        Text(t("iftarMoment.title")).font(.system(size: 32, weight: .bold)).foregroundStyle(.white).multilineTextAlignment(.center).padding(.top, 7)
        Text(t("iftarMoment.accept")).font(.system(size: 16)).foregroundStyle(.white.opacity(0.85)).padding(.top, 6)
        duaCard.padding(.top, 16)
        VStack(spacing: 10.5) {
          if !fasted {
            Button {
              Haptics.impact(.medium)
              Task { await store.toggle(key, hijriYear: window.hijriYear) }
            } label: {
              Text(t("iftarMoment.mark")).font(.system(size: 16, weight: .semibold)).foregroundStyle(tint.hero)
                .frame(maxWidth: .infinity).padding(.vertical, 15).background(tint.accent, in: .capsule)
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
        .padding(.top, 16)
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

  private var duaCard: some View {
    VStack(spacing: 6) {
      Text(t("iftarMoment.duaTitle")).font(.system(size: 13, weight: .semibold)).foregroundStyle(tint.accent)
      Text(t("iftarMoment.duaArabic")).font(.system(size: 22, weight: .bold)).lineSpacing(6).foregroundStyle(.white).multilineTextAlignment(.center)
      if !Localizer.shared.language.isRTL {
        Text(t("iftarMoment.duaReading")).font(.system(size: 13, weight: .medium)).foregroundStyle(.white).multilineTextAlignment(.center)
        Text(t("iftarMoment.duaMeaning")).font(.system(size: 13)).foregroundStyle(.white.opacity(0.85)).multilineTextAlignment(.center)
      }
      Text(t("iftarMoment.duaSource")).font(.system(size: 12)).foregroundStyle(.white.opacity(0.72))
    }
    .frame(maxWidth: .infinity)
    .padding(14)
    .background(.white.opacity(0.08), in: .rect(cornerRadius: 21))
  }

  private func tile(_ key: String, _ value: String) -> some View {
    VStack(alignment: .leading, spacing: 1) {
      Text(t(key)).font(.system(size: 13)).foregroundStyle(.white.opacity(0.8))
      Text(value).font(.system(size: 24, weight: .semibold)).foregroundStyle(.white).tabularNumbers()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 16).padding(.vertical, 13)
    .background(tint.hero, in: .rect(cornerRadius: 21))
  }
}
