import SwiftUI

/// RN HijriCalendarScreen: Hicri ay, bu ayın günleri ve en yakın altı dini gün.
struct HijriCalendarView: View {
  @Environment(\.tokens) private var tokens
  @Environment(\.scenePhase) private var scenePhase
  private var store: HijriCalendarStore { .shared }

  var body: some View {
    let grid = store.grid
    let events = grid.events(store.religiousDays)
    VStack(spacing: 0) {
      StandardHeader(title: t("calendar.title"))
      ScrollView {
        VStack(spacing: 16) {
          todayBadge
          monthCard(grid, events: events)
          if !events.isEmpty { monthEvents(events) }
          upcoming
        }.padding(16).padding(.bottom, 24)
      }.scrollIndicators(.hidden)
    }
    .background(tokens.canvas).toolbar(.hidden, for: .navigationBar)
    .onAppear {
      if DebugLaunch.calendar == nil { store.updateClock(); store.goToday() }
    }
    .task(id: scenePhase) { if scenePhase == .active { await store.refresh() } }
    .task {
      while !Task.isCancelled {
        do { try await Task.sleep(for: .seconds(60)) } catch { return }
        if scenePhase == .active { store.updateClock() }
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
      Task { await store.refresh() }
    }
  }

  private var todayBadge: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 1.75) {
        Text(t("calendar.todayLine", ["date": HijriCalendarText.hijri(store.today)]))
          .font(.system(size: 10.5, weight: .semibold)).foregroundStyle(tokens.isDark ? Accent.s400 : Accent.s700)
        Text(gregorian(store.now, "dMMMMyyyy")).font(.system(size: 12))
          .foregroundStyle(tokens.isDark ? Accent.s500.opacity(0.8) : Accent.s600.opacity(0.7))
      }.padding(.horizontal, 14).padding(.vertical, 8.75)
        .background(tokens.isDark ? Accent.s500.opacity(0.1) : Accent.s50, in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(tokens.isDark ? Accent.s800 : Accent.s200, lineWidth: 1))
        .layoutPriority(1)
      Spacer(minLength: 0)
      if !store.isViewingToday {
        Button { Haptics.impact(.light); store.goToday() } label: {
          Text(t("calendar.backToToday")).font(.system(size: 10.5, weight: .bold)).multilineTextAlignment(.center)
            .foregroundStyle(tokens.isDark ? Forest.s300 : Forest.s600)
            .padding(.horizontal, 10.5).padding(.vertical, 7).background(tokens.surface, in: .rect(cornerRadius: 10.5))
            .overlay(RoundedRectangle(cornerRadius: 10.5).stroke(tokens.line, lineWidth: 1))
        }.buttonStyle(PressableStyle())
      }
    }
  }

  private func monthCard(_ grid: HijriMonthGrid, events: [Int: ReligiousDay]) -> some View {
    VStack(spacing: 0) {
      HStack {
        monthButton("chevron-back", label: "calendar.prevMonth", delta: -1)
        VStack(spacing: 0) {
          Text("\(HijriCalendarText.monthName(grid.month.month)) \(String(grid.month.year))")
            .font(.system(size: 15.75, weight: .semibold)).foregroundStyle(tokens.textPrimary)
          Text(gregorian(grid.start, "MMMMyyyy")).font(.system(size: 12)).foregroundStyle(tokens.isDark ? Forest.s500 : Forest.s400)
        }.frame(maxWidth: .infinity)
        monthButton("chevron-forward", label: "calendar.nextMonth", delta: 1)
      }.padding(14)
      divider
      HStack(spacing: 0) {
        let names = Localizer.shared.list("common.weekdaysShort")
        ForEach(0..<7) { index in
          Text(names.indices.contains(index) ? names[index] : "")
            .font(.system(size: 12, weight: .medium)).foregroundStyle(index == 4 ? tokens.accent : tokens.isDark ? Forest.s500 : Forest.s400)
            .frame(maxWidth: .infinity)
        }
      }.padding(.horizontal, 10.5).padding(.top, 10.5)
      VStack(spacing: 0) {
        ForEach(0..<(grid.cells.count / 7), id: \.self) { row in
          HStack(alignment: .top, spacing: 0) {
            ForEach(0..<7) { col in
              if let day = grid.cells[row * 7 + col] {
                dayCell(day, friday: col == 4, date: grid.date(day), special: events[day])
              } else { Color.clear.frame(height: 31.5).frame(maxWidth: .infinity).padding(.vertical, 3.5).accessibilityHidden(true) }
            }
          }
        }
      }.padding(.horizontal, 10.5).padding(.top, 7).padding(.bottom, 14)
      divider
      HStack(spacing: 14) {
        legend("calendar.legendToday", color: Accent.s600, size: 10.5)
        legend("calendar.legendSpecial", color: Amber.s400, size: 5.25)
        Spacer(minLength: 0)
      }.padding(.horizontal, 14).padding(.vertical, 10.5)
    }.background(tokens.surface, in: .rect(cornerRadius: 21))
      .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
  }

  private func monthButton(_ icon: String, label: String, delta: Int) -> some View {
    Button { Haptics.impact(.light); store.move(delta) } label: {
      Ionicon(dirIcon(icon), size: 18, color: tokens.inkMuted).frame(width: 31.5, height: 31.5)
        .overlay(RoundedRectangle(cornerRadius: 10.5).stroke(tokens.isDark ? Forest.s700 : Forest.s200, lineWidth: 1))
        .frame(width: 44, height: 44).contentShape(.rect)
    }.buttonStyle(PressableStyle()).accessibilityLabel(t(label))
  }

  private func dayCell(_ day: Int, friday: Bool, date: Date, special: ReligiousDay?) -> some View {
    let today = store.isViewingToday && day == store.today.day
    let ink: Color = today ? .white : special != nil ? tokens.isDark ? Amber.s400 : Amber.s600 : friday ? tokens.accent : tokens.isDark ? Forest.s300 : Forest.s700
    let background: Color = today ? tokens.isDark ? Accent.s500 : Accent.s600 : special != nil ? tokens.isDark ? Amber.s500.opacity(0.1) : Amber.s50 : .clear
    return VStack(spacing: 1.75) {
      Text("\(day)").font(.system(size: 12.25, weight: .bold)).foregroundStyle(ink)
        .frame(width: 31.5, height: 31.5).background(background, in: .circle)
      if special != nil && !today { Circle().fill(Amber.s400).frame(width: 3.5, height: 3.5) }
    }.frame(maxWidth: .infinity).padding(.vertical, 3.5)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel((["\(day) \(HijriCalendarText.monthName(store.viewMonth.month)) \(store.viewMonth.year)", gregorian(date, "dMMMMyyyy"), special?.name, today ? t("calendar.today") : nil].compactMap { $0 }).joined(separator: ", "))
  }

  private func legend(_ key: String, color: Color, size: Double) -> some View {
    HStack(spacing: 5.25) {
      Circle().fill(color).frame(width: size, height: size)
      Text(t(key)).font(.system(size: 12, weight: .bold)).foregroundStyle(Forest.s400)
    }
  }

  private func monthEvents(_ events: [Int: ReligiousDay]) -> some View {
    section("calendar.thisMonth") {
      ForEach(events.keys.sorted(), id: \.self) { day in
        if let event = events[day] {
          monthEvent(day, event: event)
          if day != events.keys.max() { divider }
        }
      }
    }
  }

  private func monthEvent(_ day: Int, event: ReligiousDay) -> some View {
    let past = event.date < store.calendar.calendar.startOfDay(for: store.now)
    return HStack(spacing: 10.5) {
      Text("\(day)").font(.system(size: 12.25, weight: .semibold)).foregroundStyle(tokens.isDark ? Amber.s400 : Amber.s600)
        .frame(width: 35, height: 35).background(tokens.isDark ? Amber.s500.opacity(0.1) : Amber.s50, in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(tokens.isDark ? Color(hex: 0x3d3418) : Amber.s200, lineWidth: 1))
      eventText(event.name, subtitle: "\(day) \(HijriCalendarText.monthName(store.viewMonth.month)) · \(gregorian(event.date, "dMMMM"))")
      if !past {
        Text(t("calendar.daysLeft", ["count": daysLeft(event.date)]))
          .font(.system(size: 10.5, weight: .bold)).foregroundStyle(Amber.s500)
      }
    }.padding(.horizontal, 14).padding(.vertical, 12.25).opacity(past ? 0.5 : 1)
  }

  private var upcoming: some View {
    let events = store.upcoming
    return section("calendar.upcoming") {
      ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
        HStack(spacing: 10.5) {
          Ionicon("star-outline", size: 18, color: tokens.isDark ? Accent.s500 : Accent.s600)
            .frame(width: 35, height: 35).background(tokens.isDark ? Accent.s500.opacity(0.1) : Accent.s50, in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(tokens.isDark ? Accent.s800 : Accent.s200, lineWidth: 1))
          eventText(event.name, subtitle: "\(event.hijriDate) · \(gregorian(event.date, "dMMMM"))")
          VStack(alignment: .trailing, spacing: 0) {
            Text("\(daysLeft(event.date))").font(.system(size: 15.75, weight: .semibold)).monospacedDigit().foregroundStyle(tokens.accent)
            Text(t("calendar.daysLeftShort")).font(.system(size: 12, weight: .medium)).foregroundStyle(Forest.s400)
          }
        }.padding(.horizontal, 14).padding(.vertical, 12.25)
        if index < events.count - 1 { divider }
      }
    }
  }

  private func eventText(_ title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 1.75) {
      Text(title).font(.system(size: 12.25, weight: .bold)).foregroundStyle(tokens.textPrimary)
      Text(subtitle).font(.system(size: 10.5)).foregroundStyle(tokens.isDark ? Forest.s500 : Forest.s400)
    }.frame(maxWidth: .infinity, alignment: .leading)
  }
  private func section<Content: View>(_ key: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 7) {
      Text(t(key)).font(.system(size: 13, weight: .medium)).foregroundStyle(tokens.textSecondary).padding(.leading, 3.5)
      VStack(spacing: 0, content: content).background(tokens.surface, in: .rect(cornerRadius: 21))
        .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
    }
  }
  private var divider: some View { Rectangle().fill(tokens.isDark ? Forest.s800 : Forest.s100).frame(height: 1) }
  private func gregorian(_ date: Date, _ template: String) -> String {
    HijriCalendarText.gregorian(date, template: template, calendar: store.calendar.calendar)
  }
  private func daysLeft(_ date: Date) -> Int { HijriCalendarText.daysLeft(until: date, now: store.now, calendar: store.calendar.calendar) }
}
