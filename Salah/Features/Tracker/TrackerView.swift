import SwiftUI

/// İbadet Defteri sekmesi. RN: screens/user/TrackerScreen.tsx
struct TrackerView: View {
  @Environment(\.tokens) private var tokens
  @Environment(\.scenePhase) private var scenePhase
  @State private var formType: ActivityType? = DebugLaunch.form

  var body: some View {
    let store = TrackerStore.shared
    let insights = InsightsStore.shared
    VStack(spacing: 0) {
      StandardHeader(title: t("tracker.title"), showBackButton: false) { ProfileButton() }
      ScrollViewReader { proxy in
      ScrollView {
        VStack(spacing: 0) {
          hero(store.todayLogs)
            .padding(.bottom, 14)

          GroupedCard {
            ForEach(Array(ActivityType.allCases.enumerated()), id: \.element) { i, type in
              if i > 0 { RowDivider(leading: 68) }
              ActivityRow(type: type, logs: store.todayLogs) { open(type) }
            }
          }

          if !store.todayLogs.isEmpty {
            SectionLabel(t("tracker.todayEntries")).padding(.top, 21)
            GroupedCard {
              ForEach(Array(store.todayLogs.enumerated()), id: \.element.id) { i, log in
                if i > 0 { RowDivider() }
                LogRow(log: log)
              }
            }
          }

          if AuthStore.shared.isAuthenticated && !insights.unavailable {
            SectionLabel(t("insights.section")).padding(.top, 21).id("insights")
            VStack(spacing: 14) {
              RecapCard()
              HeatmapCard()
              HatimCard()
            }
          }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 24)
      }
      .scrollIndicators(.hidden)
      .refreshable { await load() }
      .task(id: AppLinks.shared.pendingInsights) {
        // salah://istatistik ile gelince istatistikler bölümüne kaydır.
        guard AppLinks.shared.pendingInsights else { return }
        try? await Task.sleep(for: .milliseconds(300))
        withAnimation { proxy.scrollTo("insights", anchor: .top) }
        AppLinks.shared.pendingInsights = false
      }
      }
    }
    .background(tokens.canvas)
    .task { await load() }
    // İbadet widget'ı / derin bağlantıyla gelen tür: ilgili kayıt formu açılır.
    .task(id: AppLinks.shared.pendingForm) {
      guard let type = AppLinks.shared.pendingForm else { return }
      AppLinks.shared.pendingForm = nil
      formType = type
    }
    .onChange(of: store.todayLogs.count) { Task { await insights.fetchAll() } }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { Task { await load() } }
    }
    .sheet(item: $formType) { type in
      LogFormView(type: type) { formType = nil }
        .presentationDetents([.fraction(0.8), .fraction(0.9), .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(tokens.surface)
        .presentationCornerRadius(24)
        .environment(\.tokens, tokens)
    }
  }

  private func hero(_ logs: [TrackerLog]) -> some View {
    let types = Set(logs.compactMap(\.type)).count
    let date = Date().formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Localizer.shared.locale))
    return HStack(alignment: .bottom) {
      VStack(alignment: .leading, spacing: 3.5) {
        Text(date.capitalized(with: Localizer.shared.locale))
          .font(.system(size: 15))
          .foregroundStyle(.white.opacity(0.7))
        HStack(alignment: .firstTextBaseline, spacing: 5.25) {
          Text("\(logs.count)")
            .font(.system(size: 44, weight: .light))
            .foregroundStyle(.white)
            .tabularNumbers()
          Text(t("tracker.hero.entries"))
            .font(.system(size: 15))
            .foregroundStyle(.white.opacity(0.75))
        }
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 0) {
        Text("\(types)/\(ActivityType.allCases.count)")
          .font(.system(size: 22, weight: .semibold))
          .foregroundStyle(Gold.s300)
          .tabularNumbers()
        Text(t("tracker.hero.types"))
          .font(.system(size: 13))
          .foregroundStyle(.white.opacity(0.6))
      }
    }
    .padding(17.5)
    .background(tokens.isDark ? Accent.s900 : Accent.s800, in: .rect(cornerRadius: 21))
  }

  private func open(_ type: ActivityType) {
    Haptics.impact(.light)
    formType = type
  }

  private func load() async {
    TrackerStore.shared.ensureFreshToday()
    async let logs: Void = TrackerStore.shared.fetchTodayLogs()
    async let stats: Void = InsightsStore.shared.fetchAll()
    _ = await (logs, stats)
  }
}

extension ActivityType: Identifiable {
  var id: String { rawValue }
}

private struct ActivityRow: View {
  @Environment(\.tokens) private var tokens
  let type: ActivityType
  let logs: [TrackerLog]
  let onTap: () -> Void

  var body: some View {
    let total = TrackerText.aggregate(logs, type)
    let count = logs.filter { $0.type == type }.count
    let has = count > 0
    let summary =
      has
      ? (total > 0 ? "\(formatNumber(total)) \(type.unit)".trimmingCharacters(in: .whitespaces) : t("tracker.summary.entries", ["count": count]))
        + (count > 1 ? t("tracker.summary.moreEntries", ["count": count]) : "")
      : t("tracker.summary.none")

    Button(action: onTap) {
      HStack(spacing: 10.5) {
        Ionicon(type.icon, size: 19, color: has ? tokens.accent : tokens.inkMuted)
          .frame(width: 35, height: 35)
          .background(has ? (tokens.isDark ? Accent.s900 : Accent.s50) : tokens.fill, in: .circle)
        VStack(alignment: .leading, spacing: 1.75) {
          Text(type.label)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(tokens.textPrimary)
          Text(summary)
            .font(.system(size: 13, weight: has ? .medium : .regular))
            .foregroundStyle(has ? (tokens.isDark ? Accent.s400 : Accent.s700) : tokens.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        Ionicon("add-circle-outline", size: 24, color: tokens.accent)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 10.5)
      .contentShape(.rect)
    }
    .buttonStyle(PressableStyle(pressedOpacity: 0.6))
    .accessibilityLabel(t("tracker.addA11y", ["label": type.label, "summary": summary]))
  }
}

private struct LogRow: View {
  @Environment(\.tokens) private var tokens
  let log: TrackerLog

  var body: some View {
    let label = log.type?.label ?? log.activity_type
    HStack(spacing: 10.5) {
      VStack(alignment: .leading, spacing: 1.75) {
        Text(label)
          .font(.system(size: 15, weight: .medium))
          .foregroundStyle(tokens.textPrimary)
        Text(TrackerText.valueLabel(log))
          .font(.system(size: 13))
          .foregroundStyle(tokens.textSecondary)
        if let notes = log.notes, !notes.isEmpty {
          Text(notes)
            .font(.system(size: 13))
            .lineSpacing(2)
            .foregroundStyle(tokens.isDark ? Forest.s300 : Forest.s600)
            .lineLimit(3)
            .padding(.top, 3.5)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      Button {
        AppAlert.confirm(
          t("tracker.delete.title"), t("tracker.delete.message"),
          confirmText: t("tracker.delete.confirm"), destructive: true
        ) {
          Haptics.impact(.medium)
          try? await TrackerStore.shared.delete(log.id)
        }
      } label: {
        Ionicon("trash-outline", size: 17, color: tokens.inkSubtle)
          .frame(width: 31.5, height: 31.5)
      }
      .buttonStyle(PressableStyle())
      .accessibilityLabel(t("tracker.delete.a11y", ["label": label]))
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10.5)
  }
}

/// Sekme kökü başlığındaki profil düğmesi. RN: StandardHeader `showProfile`.
struct ProfileButton: View {
  @Environment(\.tokens) private var tokens
  /// Varsayılan: oturum varsa Ana Sayfa yığınında profil, yoksa giriş (RN StandardHeader `showProfile`).
  var action: (() -> Void)?

  var body: some View {
    Button(action: {
      Haptics.impact(.light)
      if let action { action() } else { Self.openProfile() }
    }) {
      UserAvatar(iconColor: tokens.inkMuted)
        .frame(width: 35, height: 35)
        .background(tokens.surface, in: .circle)
        .clipShape(.circle)
        .overlay(Circle().stroke(tokens.line, lineWidth: 1))
    }
    .buttonStyle(PressableStyle())
    .accessibilityLabel(t("common.profile"))
  }

  static func openProfile() {
    guard AuthStore.shared.isAuthenticated else { return AuthFlow.shared.present() }
    HomeNavigation.shared.path = [.profile]
    NotificationNavigation.shared.requestHome()
  }
}
