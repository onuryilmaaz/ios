import SwiftUI

/// Oruç defteri: hafta düzeninde 29-30 ay; geçmiş günler de işaretlenir. Kaza sayacı burada.
struct FastJournalView: View {
  @Environment(\.dismiss) private var dismiss
  private let window = RamadanSchedule.window(ReligiousCalendarService.cached())
  private let tint = RamadanTint.current(nil)
  @State private var teravihTab = false

  var body: some View {
    let store = RamadanStore.shared
    let teravihCount = store.markCount("taraweeh", hijriYear: window.hijriYear)
    let now = Date()
    let todayKey = localDateString(now)
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: now)
    let isOn = today >= window.start && today <= window.last
    VStack(spacing: 0) {
      HStack {
        Button {
          Haptics.impact(.light)
          dismiss()
        } label: {
          Ionicon(dirIcon("chevron-back"), size: 20, color: .white).frame(width: 44, height: 44).background(.white.opacity(0.1), in: .circle)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(t("common.back"))
        Spacer()
        Text(t("ramadan.journal.title")).font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
        Spacer()
        Color.clear.frame(width: 44, height: 44)
      }
      .padding(.horizontal, 14).padding(.vertical, 7)
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          HStack(alignment: .lastTextBaseline, spacing: 9) {
            Text("\(teravihTab ? teravihCount : store.count(hijriYear: window.hijriYear))").font(.system(size: 68, weight: .ultraLight)).foregroundStyle(tint.accent).tabularNumbers()
            Text(teravihTab ? "/ \(window.days) \(t("ramadan.tab.teravih"))" : t("ramadan.journal.ofTotal", ["total": window.days])).font(.system(size: 16)).foregroundStyle(.white.opacity(0.85))
          }
          HStack(spacing: 8) {
            tab(false, "ramadan.tab.fast")
            tab(true, "ramadan.tab.teravih")
          }
          .padding(.top, 14)
          HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { i in
              Text(weekday(i)).font(.system(size: 12)).foregroundStyle(.white.opacity(0.72)).lineLimit(1).frame(maxWidth: .infinity)
            }
          }
          .padding(.top, 18)
          grid(todayKey: todayKey, today: today).padding(.top, 10)
          HStack(spacing: 16) {
            legend(tint.accent, "ramadan.journal.fasted")
            legend(.white.opacity(0.42), "ramadan.journal.missed")
            legend(.white.opacity(0.22), "ramadan.journal.upcoming")
          }
          .padding(.top, 18)
          Text(t("ramadan.nights.title")).font(.system(size: 17, weight: .semibold)).foregroundStyle(.white).padding(.top, 22)
          Text(t("ramadan.nights.hint")).font(.system(size: 13)).foregroundStyle(.white.opacity(0.8)).padding(.top, 2)
          NightsRow(window: window, doneColor: tint.accent, idleColor: tint.surface, ink: .white, doneInk: tint.hero).padding(.top, 10)
          kazaSuggestion(now: now).padding(.top, 18)
          if isOn {
            let fasted = store.isFasted(todayKey, hijriYear: window.hijriYear)
            Button {
              Haptics.impact(.medium)
              Task { await store.toggle(todayKey, hijriYear: window.hijriYear) }
            } label: {
              Text(t(fasted ? "ramadan.fasted" : "ramadan.fastToday")).font(.system(size: 16, weight: .semibold))
                .foregroundStyle(fasted ? tint.hero : .white)
                .frame(maxWidth: .infinity).padding(.vertical, 15)
                .background(fasted ? tint.accent : .white.opacity(0.1), in: .capsule)
            }
            .buttonStyle(PressableStyle())
            .padding(.top, 18)
          }
          kazaRow.padding(.top, isOn ? 10 : 24)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 24)
      }
      .scrollIndicators(.hidden)
    }
    .background(tint.hero)
    .toolbar(.hidden, for: .navigationBar)
    .statusBar(.light)
    .task { await RamadanStore.shared.sync(force: true) }
  }

  private func weekday(_ i: Int) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Localizer.shared.locale
    let symbols = calendar.shortWeekdaySymbols
    return symbols[(i + 1) % 7]
  }

  private func grid(todayKey: String, today: Date) -> some View {
    let calendar = Calendar.current
    // Pazartesi başlangıçlı hafta.
    let lead = (calendar.component(.weekday, from: window.start) + 5) % 7
    let cells: [Int?] = Array(repeating: nil, count: lead) + (1...window.days).map { Optional($0) }
    let rows = stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<min($0 + 7, cells.count)]) }
    return VStack(spacing: 10) {
      ForEach(rows.indices, id: \.self) { r in
        HStack(spacing: 0) {
          ForEach(0..<7, id: \.self) { slot in
            Group {
              if slot < rows[r].count, let day = rows[r][slot] { cell(day, todayKey: todayKey, today: today) } else { Color.clear.frame(height: 34) }
            }
            .frame(maxWidth: .infinity)
          }
        }
      }
    }
  }

  private func cell(_ day: Int, todayKey: String, today: Date) -> some View {
    let store = RamadanStore.shared
    let date = Calendar.current.date(byAdding: .day, value: day - 1, to: window.start) ?? window.start
    let key = localDateString(date)
    let done = teravihTab ? store.isMarked("taraweeh", day: key, hijriYear: window.hijriYear) : store.isFasted(key, hijriYear: window.hijriYear)
    let isToday = key == todayKey
    let future = date > today
    let lit: Color = done ? tint.accent : isToday ? tint.accent.opacity(0.6) : future ? .white.opacity(0.22) : .white.opacity(0.42)
    let status = t(done ? "ramadan.journal.fasted" : isToday ? "ramadan.journal.today" : future ? "ramadan.journal.upcoming" : "ramadan.journal.missed")
    return Button {
      Haptics.impact(.medium)
      Task {
        if teravihTab { await store.toggleMark("taraweeh", day: key, hijriYear: window.hijriYear) } else { await store.toggle(key, hijriYear: window.hijriYear) }
      }
    } label: {
      VStack(spacing: 3) {
        RamadanMoonView(day: day, size: 34, disc: tint.surface, lit: lit, ring: isToday ? tint.accent : nil)
        Text("\(day)").font(.system(size: 12, weight: isToday ? .bold : .regular))
          .foregroundStyle(future ? .white.opacity(0.72) : .white).tabularNumbers()
      }
    }
    .buttonStyle(PressableStyle())
    .disabled(future)
    .accessibilityLabel("\(day), \(status)")
  }

  private func tab(_ teravih: Bool, _ key: String) -> some View {
    let selected = teravihTab == teravih
    return Button {
      Haptics.impact(.light)
      teravihTab = teravih
    } label: {
      Text(t(key)).font(.system(size: 14, weight: .semibold)).foregroundStyle(selected ? tint.hero : .white)
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(selected ? tint.accent : .white.opacity(0.1), in: .capsule)
    }
    .buttonStyle(PressableStyle())
  }

  @ViewBuilder
  private func kazaSuggestion(now: Date) -> some View {
    let store = RamadanStore.shared
    let unmarked = RamadanPlan.unmarkedDays(window, now: now, marked: store.ledger.days(window.hijriYear), calendar: .current)
    let done = store.ledger.markDays(window.hijriYear, kind: "kaza")
    let toAdd = unmarked.filter { !done.contains($0) }
    if !toAdd.isEmpty {
      let ozelDays = Set(store.ledger.ozelGun[String(window.hijriYear)] ?? [])
      let ozel = toAdd.filter { ozelDays.contains($0) }.count
      VStack(alignment: .leading, spacing: 4) {
        Text(t("ramadan.kaza.title", ["count": toAdd.count])).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
        if ozel > 0 { Text(t("ramadan.kaza.ozel", ["count": ozel])).font(.system(size: 13)).foregroundStyle(tint.accent) }
        Text(t("ramadan.kaza.body")).font(.system(size: 13)).foregroundStyle(.white.opacity(0.8))
        Button {
          Haptics.notify(.success)
          Task {
            await store.applyKaza(hijriYear: window.hijriYear, days: toAdd)
            Toast.success(t("ramadan.kaza.added"))
          }
        } label: {
          Text(t("ramadan.kaza.add", ["count": toAdd.count])).font(.system(size: 14, weight: .semibold)).foregroundStyle(tint.hero)
            .frame(maxWidth: .infinity).padding(.vertical, 11)
            .background(tint.accent, in: .capsule)
        }
        .buttonStyle(PressableStyle())
        .padding(.top, 8)
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(tint.surface, in: .rect(cornerRadius: 21))
    }
  }

  private var kazaRow: some View {
    HStack(spacing: 0) {
      Text(t("ramadan.journal.kaza")).font(.system(size: 15)).foregroundStyle(.white)
      Spacer(minLength: 8)
      stepper("remove", t("ramadan.journal.kazaRemove"), -1)
      Text(t("ramadan.journal.kazaCount", ["count": RamadanStore.shared.ledger.kaza]))
        .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white).tabularNumbers().padding(.horizontal, 10)
      stepper("add", t("ramadan.journal.kazaAdd"), 1)
    }
    .padding(.horizontal, 16).padding(.vertical, 7)
    .background(tint.surface, in: .rect(cornerRadius: 21))
  }

  private func stepper(_ icon: String, _ label: String, _ delta: Int) -> some View {
    Button {
      Haptics.impact(.light)
      Task { await RamadanStore.shared.addKaza(delta) }
    } label: {
      Ionicon(icon, size: 17, color: .white)
        .frame(width: 32, height: 32).background(.white.opacity(0.1), in: .circle)
        .frame(width: 44, height: 44).contentShape(.rect)
    }
    .buttonStyle(PressableStyle())
    .accessibilityLabel(label)
  }

  private func legend(_ color: Color, _ key: String) -> some View {
    HStack(spacing: 6) {
      Circle().fill(color).frame(width: 11, height: 11)
      Text(t(key)).font(.system(size: 13)).foregroundStyle(.white.opacity(0.85))
    }
  }
}
