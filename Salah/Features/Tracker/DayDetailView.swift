import SwiftUI

/// İbadet Defteri'nde namaz geçmişinden seçilen gün: o günün beş vakti (işaretlenebilir), ibadet kayıtları ve
/// geriye dönük ibadet ekleme.
struct DayDetailView: View {
  @Environment(\.tokens) private var tokens
  let day: Date
  let onClose: () -> Void

  @State private var done: Set<String> = []
  @State private var logs: [TrackerLog] = []
  @State private var formType: ActivityType?
  /// Gün sayfası açıkken bir şey değişti: kapanınca istatistikler yenilenir.
  @State private var changed = false

  private var isToday: Bool { Calendar.current.isDateInToday(day) }
  private var date: String { localDateString(day) }

  var body: some View {
    VStack(spacing: 0) {
      header
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          SectionLabel(t("history.fivePrayers"))
          DayPrayerList(day: day, done: $done) { changed = true }

          SectionLabel(t("tracker.day.worship")).padding(.top, 21)
          GroupedCard {
            ForEach(Array(ActivityType.allCases.enumerated()), id: \.element) { i, type in
              if i > 0 { RowDivider(leading: 68) }
              ActivityRow(type: type, logs: logs) {
                Haptics.impact(.light)
                formType = type
              }
            }
          }

          if !logs.isEmpty {
            SectionLabel(t("tracker.day.entries")).padding(.top, 21)
            GroupedCard {
              ForEach(Array(logs.enumerated()), id: \.element.id) { i, log in
                if i > 0 { RowDivider() }
                LogRow(log: log) { await delete(log) }
              }
            }
          }
        }
        .padding(.horizontal, 16)
        .padding(.top, 7)
        .padding(.bottom, 32)
      }
      .scrollIndicators(.hidden)
    }
    .background(tokens.canvas)
    .task(id: date) { await load() }
    .onDisappear {
      guard changed else { return }
      Task {
        await InsightsStore.shared.fetchAll()
        if isToday { await TrackerStore.shared.fetchTodayLogs() }
      }
    }
    .sheet(item: $formType) { type in
      LogFormView(type: type, day: day, onSaved: { log in
        changed = true
        if log.date == date { logs.append(log) }
      }) { formType = nil }
        .presentationDetents([.fraction(0.8), .fraction(0.9), .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(tokens.surface)
        .presentationCornerRadius(24)
        .environment(\.tokens, tokens)
    }
  }

  private var header: some View {
    HStack(alignment: .top, spacing: 10.5) {
      VStack(alignment: .leading, spacing: 3.5) {
        Text(t(isToday ? "history.today" : "history.pastDay"))
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(tokens.isDark ? Accent.s400 : Accent.s600)
        Text(day.formatted(.dateTime.weekday(.wide).day().month(.wide).year().locale(Localizer.shared.locale)))
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(tokens.textPrimary)
          .accessibilityAddTraits(.isHeader)
        Text(t("history.count", ["count": done.count]))
          .font(.system(size: 13))
          .foregroundStyle(tokens.textSecondary)
          .tabularNumbers()
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      Button {
        Haptics.impact(.light)
        onClose()
      } label: {
        Ionicon("close", size: 18, color: tokens.inkMuted)
          .frame(width: 35, height: 35)
          .background(tokens.fill, in: .circle)
      }
      .buttonStyle(PressableStyle())
      .accessibilityLabel(t("common.close"))
    }
    .padding(.horizontal, 17.5)
    .padding(.top, 24)
    .padding(.bottom, 7)
  }

  private func load() async {
    struct Response: Decodable {
      var success: Bool
      var data: [TrackerLog]?
    }
    // Eski sunucuda bu uç yok: liste boş kalır, ekleme yine çalışır.
    guard let res = try? await APIClient.shared.get("/tracker/by-date/\(date)", as: Response.self), res.success else { return }
    logs = (res.data ?? []).filter { $0.type != nil }
  }

  private func delete(_ log: TrackerLog) async {
    // Bugünün listesinde yoksa liste değişmez; çevrimdışı ve kuyruk kuralları aynı.
    do { try await TrackerStore.shared.delete(log.id) } catch {
      Toast.error(t("common.error"), t("history.actionFailed"))
      return
    }
    logs.removeAll { $0.id == log.id }
    changed = true
  }
}
