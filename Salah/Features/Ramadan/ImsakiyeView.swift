import SwiftUI

/// Ramazan imsakiyesi: bugün üstte büyük, altında ayın günleri.
struct ImsakiyeView: View {
  @Environment(\.tokens) private var tokens
  @Environment(\.dismiss) private var dismiss
  @State private var days: [PrayerDay]?
  @State private var failed = false
  @State private var attempt = 0
  @State private var sharing = false

  var body: some View {
    let window = RamadanSchedule.window(ReligiousCalendarService.cached())
    VStack(spacing: 0) {
      header(window)
      if let days, !days.isEmpty {
        table(days)
      } else if failed || days != nil {
        message
      } else {
        Spacer()
        ProgressView().tint(tokens.accent)
        Spacer()
      }
    }
    .background(tokens.canvas)
    .toolbar(.hidden, for: .navigationBar)
    .statusBar(.light)
    .task(id: attempt) { await load(window) }
    .fullScreenCover(isPresented: $sharing) {
      ImsakiyeShareSheet(days: days ?? [], place: Locations.selectedDisplayName, window: window)
        .environment(\.tokens, tokens)
    }
  }

  private func header(_ window: RamadanWindow) -> some View {
    let now = Date()
    let tint = RamadanTint.current(nil, now: now)
    let calendar = Calendar.current
    let row = days?.first { $0.localDay.map(calendar.isDateInToday) == true }
    let times = row?.times ?? PrayerTimesService.cachedDays(districtId: Locations.selectedDistrictId).first { $0.localDay.map(calendar.isDateInToday) == true }?.times
    let date = now.formatted(Date.FormatStyle.dateTime.day().month(.wide).weekday(.wide).locale(Localizer.shared.locale))
    return VStack(alignment: .leading, spacing: 0) {
      HStack {
        headerButton(dirIcon("chevron-back"), t("common.back")) { dismiss() }
        Spacer()
        Text(t("imsakiye.short")).font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
        Spacer()
        if let days, !days.isEmpty {
          headerButton("share-outline", t("common.share")) { sharing = true }
        } else {
          Color.clear.frame(width: 44, height: 44)
        }
      }
      Text(t("imsakiye.todayLine", ["date": date, "place": Locations.selectedDisplayName]))
        .font(.system(size: 13)).foregroundStyle(.white.opacity(0.8)).padding(.top, 12)
      HStack(spacing: 10) {
        tile(t("prayers.imsak"), times?["imsak"] ?? "--:--", background: tint.surface, ink: .white)
        tile(t("ramadan.iftar"), times?["aksam"] ?? "--:--", background: tint.accent, ink: tint.hero)
      }
      .padding(.top, 9)
      if let left = RamadanPlan.kadirDaysLeft(window, now: now, calendar: calendar) {
        Text(left == 0 ? t("imsakiye.kadirTonight") : t("imsakiye.kadir", ["days": left]))
          .font(.system(size: 13)).foregroundStyle(.white.opacity(0.85)).padding(.top, 10)
      }
    }
    .padding(.horizontal, 17.5)
    .padding(.top, 7)
    .padding(.bottom, 17.5)
    .background {
      UnevenRoundedRectangle(bottomLeadingRadius: 28, bottomTrailingRadius: 28).fill(tint.hero).ignoresSafeArea(edges: .top)
    }
  }

  private func headerButton(_ icon: String, _ label: String, action: @escaping () -> Void) -> some View {
    Button {
      Haptics.impact(.light)
      action()
    } label: {
      Ionicon(icon, size: 19, color: .white).frame(width: 44, height: 44).background(.white.opacity(0.1), in: .circle)
    }
    .buttonStyle(PressableStyle())
    .accessibilityLabel(label)
  }

  private func tile(_ label: String, _ value: String, background: Color, ink: Color) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(label).font(.system(size: 13)).foregroundStyle(ink.opacity(0.85))
      Text(value).font(.system(size: 32, weight: .light)).foregroundStyle(ink).tabularNumbers()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 14).padding(.vertical, 11)
    .background(background, in: .rect(cornerRadius: 18))
  }

  private var message: some View {
    VStack(spacing: 0) {
      Spacer()
      Ionicon("calendar-outline", size: 44, color: tokens.inkSubtle)
      Text(t(failed ? "imsakiye.loadFailed" : "imsakiye.notReady")).font(.system(size: 15)).foregroundStyle(tokens.textSecondary)
        .multilineTextAlignment(.center).padding(.top, 16).padding(.horizontal, 32)
      if failed {
        AppButton(title: t("common.retry")) { attempt += 1 }.frame(width: 180).padding(.top, 20)
      }
      Spacer()
    }
  }

  private func dateText(_ date: Date) -> String {
    date.formatted(Date.FormatStyle.dateTime.day().month(.abbreviated).weekday(.abbreviated).locale(Localizer.shared.locale))
  }

  private func table(_ days: [PrayerDay]) -> some View {
    let today = Calendar.current.startOfDay(for: Date())
    return VStack(spacing: 0) {
      row(moon: nil, day: t("imsakiye.dayColumn"), date: t("imsakiye.dateColumn"), imsak: t("prayers.imsak"), iftar: t("ramadan.iftar"), header: true, today: false, past: false)
        .padding(.top, 10)
      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack(spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.offset) { index, day in
              let local = day.localDay ?? .distantPast
              row(moon: index + 1, day: "\(index + 1)", date: dateText(local), imsak: day.times["imsak"] ?? "", iftar: day.times["aksam"] ?? "",
                  header: false, today: local == today, past: local < today)
                .id(index)
            }
          }
          .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .onAppear {
          if let i = days.firstIndex(where: { $0.localDay == today }) { proxy.scrollTo(max(0, i - 2), anchor: .top) }
        }
      }
    }
  }

  private func row(moon: Int?, day: String, date: String, imsak: String, iftar: String, header: Bool, today: Bool, past: Bool) -> some View {
    let color = header ? tokens.textSecondary : past ? tokens.inkSubtle : tokens.textPrimary
    return HStack(spacing: 6) {
      Group {
        if let moon {
          RamadanMoonView(day: moon, size: 18, disc: today ? Accent.s900 : tokens.fill, lit: today ? Gold.s300 : tokens.inkSubtle.opacity(past ? 0.3 : 0.55))
        }
      }
      .frame(width: 20)
      Text(day).frame(width: 28, alignment: .leading)
      Text(date).frame(maxWidth: .infinity, alignment: .leading).lineLimit(1).minimumScaleFactor(0.8)
      Text(imsak).frame(width: 50, alignment: .trailing)
      Text(iftar).frame(width: 50, alignment: .trailing)
    }
    .font(.system(size: header ? 12 : 15, weight: today ? .semibold : .regular)).foregroundStyle(color).tabularNumbers()
    .padding(.horizontal, 10).padding(.vertical, 10)
    .background(today ? Gold.s300.opacity(tokens.isDark ? 0.14 : 0.22) : .clear, in: .rect(cornerRadius: 14))
    .padding(.horizontal, 14)
  }

  private func load(_ window: RamadanWindow) async {
    failed = false
    #if DEBUG
    if DebugLaunch.ramadan != nil {
      let base = PrayerTimes(imsak: "05:48", gunes: "07:10", ogle: "12:50", ikindi: "15:50", aksam: "18:21", yatsi: "19:40")
      days = (0..<window.days).compactMap { offset in
        Calendar.current.date(byAdding: .day, value: offset, to: window.start).map {
          PrayerDay(date: ISO8601DateFormatter().string(from: $0), times: base, hijri_date: .init(month: 9))
        }
      }
      if UserDefaults.standard.bool(forKey: "SalahDebugShare") {
        try? await Task.sleep(for: .seconds(1))
        sharing = true
      }
      return
    }
    #endif
    do {
      days = try await PrayerTimesService.imsakiye(districtId: Locations.selectedDistrictId, window: window)
    } catch {
      failed = true
    }
  }
}

/// Paylaşılan imsakiye kartı: ayet ve hadis kartlarıyla aynı zemin, ayın tamamı iki sütunda.
struct ImsakiyeShareSheet: View {
  private let tint = RamadanTint.current(nil)
  let days: [PrayerDay]
  let place: String
  let window: RamadanWindow

  private var today: Date { Calendar.current.startOfDay(for: Date()) }
  private var todayIndex: Int? { days.firstIndex { $0.localDay == today } }

  var body: some View {
    let fallback = ([t("imsakiye.shareTitle", ["place": place])] + days.enumerated().map { i, d in
      "\(i + 1). \(d.localDay.map(dateText) ?? "")  \(d.times["imsak"] ?? "")  \(d.times["aksam"] ?? "")"
    }).joined(separator: "\n")
    ShareImageSheet(fallbackText: fallback, cardColor: tint.hero) {
      ShareCardHeader(label: nil)
      RamadanMoonView(day: (todayIndex ?? 13) + 1, size: 58, disc: tint.surface, lit: tint.accent)
      Text(t("imsakiye.title")).font(.system(size: 24, weight: .bold)).foregroundStyle(.white).multilineTextAlignment(.center).padding(.top, 12)
      Text(place).font(.system(size: 14, weight: .medium)).foregroundStyle(tint.accent).multilineTextAlignment(.center).padding(.top, 3)
      GoldDivider().padding(.vertical, 15)
      if let i = todayIndex {
        HStack(spacing: 8) {
          tile(t("prayers.imsak"), days[i].times["imsak"] ?? "", background: tint.surface, ink: .white)
          tile(t("ramadan.iftar"), days[i].times["aksam"] ?? "", background: tint.accent, ink: tint.hero)
        }
        .padding(.bottom, 14)
      }
      let half = (days.count + 1) / 2
      HStack(alignment: .top, spacing: 12) {
        column(from: 0, to: half)
        column(from: half, to: days.count)
      }
    }
  }

  private func dateText(_ date: Date) -> String {
    date.formatted(Date.FormatStyle.dateTime.day().month(.abbreviated).locale(Localizer.shared.locale))
  }

  private func tile(_ label: String, _ value: String, background: Color, ink: Color) -> some View {
    VStack(spacing: 0) {
      Text(label).font(.system(size: 12)).foregroundStyle(ink.opacity(0.85))
      Text(value).font(.system(size: 26, weight: .light)).foregroundStyle(ink).tabularNumbers()
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 9)
    .background(background, in: .rect(cornerRadius: 14))
  }

  private func column(from: Int, to: Int) -> some View {
    VStack(spacing: 1) {
      HStack(spacing: 3) {
        Spacer(minLength: 0)
        Text(t("prayers.imsak")).frame(width: 34, alignment: .trailing)
        Text(t("ramadan.iftar")).frame(width: 34, alignment: .trailing)
      }
      .font(.system(size: 9.5)).foregroundStyle(.white.opacity(0.7)).lineLimit(1).minimumScaleFactor(0.7).padding(.horizontal, 5).padding(.bottom, 3)
      ForEach(from..<to, id: \.self) { i in
        let on = i == todayIndex
        HStack(spacing: 3) {
          Text("\(i + 1)").frame(width: 15, alignment: .leading)
          Text(days[i].localDay.map(dateText) ?? "").font(.system(size: 10, weight: on ? .semibold : .regular)).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(on ? tint.hero : .white.opacity(0.72))
          Text(days[i].times["imsak"] ?? "").frame(width: 34, alignment: .trailing)
          Text(days[i].times["aksam"] ?? "").frame(width: 34, alignment: .trailing)
        }
        .font(.system(size: 11, weight: on ? .semibold : .regular))
        .foregroundStyle(on ? tint.hero : .white)
        .tabularNumbers()
        .padding(.horizontal, 5)
        .padding(.vertical, 3.5)
        .background(on ? tint.accent : .clear, in: .rect(cornerRadius: 7))
      }
    }
    .frame(maxWidth: .infinity)
  }
}
