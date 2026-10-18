import SwiftUI

/// Son 14 günün namaz kayıtlarını düzeltme. RN: screens/user/PrayerHistoryEditScreen.tsx
struct PrayerHistoryView: View {
  @Environment(\.tokens) private var tokens
  @State private var selected = Calendar.current.startOfDay(for: Date())
  @State private var done: Set<String> = []
  @State private var loading = false
  @State private var updating: String?

  private static let prayers: [(id: String, label: String)] = [
    ("fajr", "Sabah"), ("dhuhr", "Öğle"), ("asr", "İkindi"), ("maghrib", "Akşam"), ("isha", "Yatsı"),
  ]

  private var days: [Date] {
    let today = Calendar.current.startOfDay(for: Date())
    return (0..<14).compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: today) }
  }

  var body: some View {
    VStack(spacing: 0) {
      StandardHeader(title: t("history.title"))
      dateStrip
      ScrollView {
        VStack(spacing: 16) {
          header
          VStack(alignment: .leading, spacing: 0) {
            Text(t("history.fivePrayers"))
              .font(.system(size: 13, weight: .medium))
              .foregroundStyle(tokens.textSecondary)
              .padding(.leading, 3.5)
              .padding(.bottom, 7)
            list
          }
          info.padding(.bottom, 84)
        }
        .padding(16)
        .padding(.bottom, 24)
      }
      .scrollIndicators(.hidden)
    }
    .background(tokens.canvas)
    .toolbar(.hidden, for: .navigationBar)
    // Oturum açılışta sonradan yüklenebilir; o zaman da yeniden okunur.
    .task(id: "\(dateString)|\(AuthStore.shared.isAuthenticated)") { await load() }
  }

  private var dateStrip: some View {
    ScrollView(.horizontal) {
      HStack(spacing: 7) {
        let weekdays = Localizer.shared.list("common.weekdaysShort")
        ForEach(days, id: \.self) { d in
          let isSelected = d == selected
          let isToday = Calendar.current.isDateInToday(d)
          // common.weekdaysShort Pazartesi'den başlar; weekday Pazar=1.
          let idx = (Calendar.current.component(.weekday, from: d) + 5) % 7
          Button {
            Haptics.impact(.light)
            selected = d
          } label: {
            VStack(spacing: 1.75) {
              Text(weekdays.indices.contains(idx) ? weekdays[idx] : "")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isSelected ? Accent.s100 : tokens.textSecondary)
              Text("\(Calendar.current.component(.day, from: d))")
                .font(.system(size: 15.75, weight: .semibold))
                .foregroundStyle(isSelected ? .white : tokens.textPrimary)
                .tabularNumbers()
              Circle()
                .fill(isToday && !isSelected ? Accent.s500 : .clear)
                .frame(width: 3.5, height: 3.5)
            }
            .frame(width: 49)
            .padding(.vertical, 8.75)
            .background(isSelected ? (tokens.isDark ? Accent.s500 : Accent.s600) : (tokens.isDark ? Forest.s900 : Forest.s100), in: .rect(cornerRadius: 14))
          }
          .buttonStyle(PressableStyle())
          .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
      }
      .padding(.horizontal, 16)
    }
    .scrollIndicators(.hidden)
    .padding(.vertical, 7)
    .background(tokens.surface)
    .overlay(alignment: .bottom) { Rectangle().fill(tokens.line).frame(height: 1) }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(t(Calendar.current.isDateInToday(selected) ? "history.today" : "history.pastDay"))
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(tokens.isDark ? Accent.s400 : Accent.s600)
      Text(selected.formatted(.dateTime.day().month(.wide).year().locale(Localizer.shared.locale)))
        .font(.system(size: 17.5, weight: .semibold))
        .foregroundStyle(tokens.textPrimary)
        .padding(.top, 3.5)
      Text(t("history.count", ["count": done.count]))
        .font(.system(size: 10.5))
        .foregroundStyle(tokens.textSecondary)
        .tabularNumbers()
        .padding(.top, 1.75)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(17.5)
    .background(tokens.surface, in: .rect(cornerRadius: 21))
    .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
  }

  private var list: some View {
    VStack(spacing: 0) {
      ForEach(Array(Self.prayers.enumerated()), id: \.element.id) { i, p in
        if i > 0 { Rectangle().fill(tokens.isDark ? Forest.s800 : Forest.s100).frame(height: 1) }
        if loading {
          HStack(spacing: 10.5) {
            RoundedRectangle(cornerRadius: 14).fill(tokens.fill).frame(width: 35, height: 35)
            RoundedRectangle(cornerRadius: 4).fill(tokens.fill).frame(width: 110, height: 14)
            Spacer()
            Circle().fill(tokens.fill).frame(width: 28, height: 28)
          }
          .padding(.horizontal, 14)
          .padding(.vertical, 12.25)
        } else {
          row(p.id, p.label)
        }
      }
    }
    .background(tokens.surface, in: .rect(cornerRadius: 21))
    .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
    .accessibilityLabel(loading ? t("common.loading") : "")
  }

  private func row(_ id: String, _ label: String) -> some View {
    let isDone = done.contains(id)
    return Button { Task { await toggle(id) } } label: {
      HStack(spacing: 10.5) {
        Ionicon(prayerIcon(id), size: 18, color: tokens.accent)
          .frame(width: 35, height: 35)
          .background(tokens.isDark ? Accent.s900 : Accent.s50, in: .circle)
        VStack(alignment: .leading, spacing: 1.75) {
          Text(prayerLabel(label))
            .font(.system(size: 12.25, weight: .semibold))
            .foregroundStyle(tokens.textPrimary)
          if isDone {
            Text(t("history.prayed"))
              .font(.system(size: 12, weight: .bold))
              .foregroundStyle(tokens.isDark ? Accent.s400 : Accent.s600)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        if updating == id {
          ProgressView().tint(tokens.accent).frame(width: 28, height: 28)
        } else if isDone {
          Ionicon("checkmark", size: 18, color: .white)
            .frame(width: 28, height: 28)
            .background(Accent.s500, in: .circle)
        } else {
          Circle()
            .strokeBorder(tokens.isDark ? Forest.s600 : Forest.s300, lineWidth: 2)
            .frame(width: 28, height: 28)
        }
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 12.25)
      .contentShape(.rect)
    }
    .buttonStyle(PressableStyle(pressedOpacity: 0.7))
    .disabled(updating == id)
    .accessibilityAddTraits(isDone ? .isSelected : [])
  }

  private var info: some View {
    HStack(alignment: .top, spacing: 7) {
      Ionicon("information-circle", size: 16, color: Amber.s500).padding(.top, 2)
      Text(t("history.info"))
        .font(.system(size: 12))
        .lineSpacing(8)
        .foregroundStyle(tokens.isDark ? Amber.s300 : Amber.s700)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(14)
    .background(tokens.isDark ? Amber.s500.opacity(0.1) : Amber.s50, in: .rect(cornerRadius: 14))
  }

  private var dateString: String { localDateString(selected) }

  private func load() async {
    guard AuthStore.shared.isAuthenticated else { return }
    struct Response: Decodable {
      struct Log: Decodable { let prayer_time: String }
      let data: [Log]?
    }
    let date = dateString
    loading = true
    defer { loading = false }
    do {
      let res = try await APIClient.shared.get("/prayer/by-date/\(date)", as: Response.self)
      guard date == dateString else { return }
      done = Set((res.data ?? []).map(\.prayer_time))
    } catch {
      Toast.error(t("common.error"), t("history.loadFailed"))
    }
  }

  private func toggle(_ id: String) async {
    guard updating == nil else { return }
    Haptics.impact(.medium)
    updating = id
    defer { updating = nil }
    let wasDone = done.contains(id)
    let body: JSONValue = ["prayer_time": .string(id), "date": .string(dateString)]
    do {
      if wasDone {
        try await APIClient.shared.send("DELETE", "/prayer/track", body: body)
        done.remove(id)
      } else {
        try await APIClient.shared.send("POST", "/prayer/track", body: ["prayer_time": .string(id), "is_kaza": .bool(false), "date": .string(dateString)])
        done.insert(id)
      }
      // Seri ve bugünün işaretleri sunucuda yeniden hesaplandı.
      Task { await GamificationStore.shared.fetchStats(force: true) }
    } catch {
      Toast.error(t("common.error"), (error as? APIError)?.serverMessage ?? t("history.actionFailed"))
    }
  }
}
