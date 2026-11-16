import SwiftUI

/// Bir günün beş vakti: kılındı işaretleme ve geri alma. Geçmiş Namazlar ekranı ve İbadet Defteri gün sayfası
/// birlikte kullanır; vakti girmemiş namaz kilitlidir.
struct DayPrayerList: View {
  @Environment(\.tokens) private var tokens
  let day: Date
  @Binding var done: Set<String>
  /// Bir vakit işaretlenince ya da geri alınınca.
  var onChange: () -> Void = {}
  @State private var loading = false
  @State private var updating: String?
  @State private var now = Date()
  /// Bugünün önbellekteki vakitleri (vakti girmemiş namazı kilitlemek için).
  @State private var todayTimes: PrayerTimes?

  private static let prayers: [(id: String, label: String)] = [
    ("fajr", "Sabah"), ("dhuhr", "Öğle"), ("asr", "İkindi"), ("maghrib", "Akşam"), ("isha", "Yatsı"),
  ]

  var body: some View {
    list
      // Oturum açılışta sonradan yüklenebilir; o zaman da yeniden okunur.
      .task(id: "\(dateString)|\(AuthStore.shared.isAuthenticated)") { await load() }
      // Ekran açıkken vakit girerse kilit kendiliğinden kalkar.
      .task {
        while !Task.isCancelled {
          now = Date()
          let today = Calendar.current.startOfDay(for: now)
          todayTimes = PrayerTimesService.cachedDays(districtId: Locations.selectedDistrictId)
            .first { $0.localDay == today }?.times
          try? await Task.sleep(for: .seconds(30))
        }
      }
  }

  private var selected: Date { Calendar.current.startOfDay(for: day) }

  private var dateString: String { localDateString(selected) }

  private func isLocked(_ id: String) -> Bool {
    !done.contains(id) && PrayerSlotGate.notYet(id, day: selected, now: now, times: todayTimes)
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
    let locked = isLocked(id)
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
          } else if locked {
            Text(t("history.notYet"))
              .font(.system(size: 12, weight: .medium))
              .foregroundStyle(tokens.textSecondary)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        if updating == id {
          ProgressView().tint(tokens.accent).frame(width: 28, height: 28)
        } else if locked {
          Ionicon("lock-closed-outline", size: 16, color: tokens.textSecondary)
            .frame(width: 28, height: 28)
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
      .opacity(locked ? 0.5 : 1)
    }
    .buttonStyle(PressableStyle(pressedOpacity: 0.7))
    .disabled(updating == id || locked)
    .accessibilityAddTraits(isDone ? .isSelected : [])
  }

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
    guard updating == nil, !isLocked(id) else { return }
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
      onChange()
    } catch {
      Toast.error(t("common.error"), (error as? APIError)?.serverMessage ?? t("history.actionFailed"))
    }
  }
}
