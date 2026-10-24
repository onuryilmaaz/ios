import SwiftUI

/// Günün beş vakti: dokununca kılındı (vakti geçtiyse kaza) olarak işaretlenir.
/// RN: components/home/PrayerTrackerCard.tsx
struct PrayerTrackerCard: View {
  @Environment(\.tokens) private var tokens
  let times: PrayerTimes?
  var onAuthRequired: () -> Void = {}
  /// 5/5 tamamlanıp seri arttığında (yeni seri sayısıyla).
  var onCelebrate: (Int) -> Void = { _ in }
  /// 5/5'i tamamlayan dokunuş sunucu yanıtını (yeni seri) bekliyor.
  @State private var awaitingStreak = false

  private struct Prayer {
    let id: String
    let name: String
    let timeKey: String
    let nextTimeKey: String?
  }

  private static let prayers = [
    Prayer(id: "fajr", name: "Sabah", timeKey: "imsak", nextTimeKey: "gunes"),
    Prayer(id: "dhuhr", name: "Öğle", timeKey: "ogle", nextTimeKey: "ikindi"),
    Prayer(id: "asr", name: "İkindi", timeKey: "ikindi", nextTimeKey: "aksam"),
    Prayer(id: "maghrib", name: "Akşam", timeKey: "aksam", nextTimeKey: "yatsi"),
    Prayer(id: "isha", name: "Yatsı", timeKey: "yatsi", nextTimeKey: nil),
  ]

  private enum SlotState { case loading, upcoming, current, expired }

  private var signedIn: Bool {
    AuthStore.shared.isAuthenticated || DebugLaunch.ozelGun?.hasPrefix("home") == true
  }

  var body: some View {
    let store = GamificationStore.shared
    let stats = store.stats
    let shown = signedIn ? (stats?.today_prayers.count ?? 0) : 0
    let total = Self.prayers.count

    TimelineView(.everyMinute) { context in
      Card {
        HStack(alignment: .center) {
          VStack(alignment: .leading, spacing: 1.75) {
            Text(t("home.tracker.title"))
              .font(.system(size: 17, weight: .semibold))
              .foregroundStyle(tokens.textPrimary)
              .accessibilityAddTraits(.isHeader)
            Text(t("home.tracker.progress", ["done": shown, "total": total]))
              .font(.system(size: 13))
              .foregroundStyle(tokens.textSecondary)
              .tabularNumbers()
          }
          Spacer()
          if shown == total {
            HStack(spacing: 3.5) {
              Ionicon("sparkles", size: 12, color: tokens.gold)
              Text(t("home.tracker.completed"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tokens.isDark ? Gold.s300 : Gold.s700)
            }
            .padding(.horizontal, 8.75)
            .padding(.vertical, 3.5)
            .background(tokens.isDark ? Gold.s700.opacity(0.2) : Gold.s50, in: .capsule)
          }
        }
        .padding(.bottom, 17.5)

        if signedIn && OzelGunStore.shared.isActive { exemptionBanner.padding(.bottom, 14) }

        HStack(spacing: 0) {
          ForEach(Self.prayers, id: \.id) { prayer in
            slot(prayer, stats: stats, isAuthenticated: signedIn, showSpinner: store.isLoading && stats == nil, now: context.date)
          }
        }
        if signedIn && OzelGunStore.shared.gender == "kadin" && !OzelGunStore.shared.isActive {
          Button { OzelGunActions.confirm(starting: true) } label: {
            HStack(spacing: 5.25) {
              Ionicon("snow-outline", size: 14, color: tokens.inkMuted)
              Text(t("home.tracker.ozelGunMine")).font(.system(size: 13, weight: .medium)).foregroundStyle(tokens.inkMuted)
            }.frame(maxWidth: .infinity).padding(.top, 10.5)
              .overlay(alignment: .top) { Rectangle().fill(tokens.isDark ? Forest.s800 : Forest.s100).frame(height: 1) }
          }.buttonStyle(PressableStyle()).padding(.top, 14).disabled(OzelGunStore.shared.isLoading || !OzelGunStore.shared.canManage)
        }
      }
      .contentShape(.rect)
      .onTapGesture { if !signedIn { onAuthRequired() } }
    }
    .tourAnchor("home.tracker")
    .padding(.horizontal, 14)
    .padding(.bottom, 10.5)
  }

  private var exemptionBanner: some View {
    HStack(spacing: 7) {
      Ionicon("snow-outline", size: 15, color: tokens.inkMuted)
      Text(t("home.tracker.ozelGunActive")).font(.system(size: 13)).foregroundStyle(tokens.isDark ? Forest.s300 : Forest.s700)
        .frame(maxWidth: .infinity, alignment: .leading)
      Button { OzelGunActions.confirm(starting: false) } label: {
        Text(t("home.tracker.ozelGunEnd")).font(.system(size: 13, weight: .semibold)).foregroundStyle(tokens.isDark ? Accent.s400 : Accent.s700)
      }.buttonStyle(PressableStyle()).disabled(OzelGunStore.shared.isLoading || !OzelGunStore.shared.canManage)
        .accessibilityLabel(t("home.tracker.ozelGunEndA11y"))
    }.padding(.horizontal, 10.5).padding(.vertical, 8.75).background(tokens.fill, in: .rect(cornerRadius: 10.5))
  }

  @ViewBuilder
  private func slot(_ prayer: Prayer, stats: GamificationStore.Stats?, isAuthenticated: Bool, showSpinner: Bool, now: Date) -> some View {
    let isTracked = isAuthenticated && (stats?.today_prayers.contains(prayer.id) ?? false)
    let isKaza = isAuthenticated && (stats?.kaza_prayers.contains(prayer.id) ?? false)
    let state = slotState(prayer, now: now)
    let isUpcoming = state == .upcoming
    let isCurrent = state == .current
    let isExpired = state == .expired
    let time = times?[prayer.timeKey] ?? "--:--"
    let showKazaLabel = isKaza || (isExpired && isAuthenticated && !isTracked)

    let status =
      isKaza ? t("home.tracker.status.kaza")
      : isTracked ? t("home.tracker.status.done")
      : isUpcoming ? t("home.tracker.status.upcoming")
      : isExpired ? t("home.tracker.status.expired")
      : t("home.tracker.status.notDone")

    Button {
      Task { await track(prayer, state: state, isAuthenticated: isAuthenticated) }
    } label: {
      VStack(spacing: 0) {
        ZStack {
          circleBackground(isTracked: isTracked, isKaza: isKaza, isCurrent: isCurrent && isAuthenticated, isExpired: isExpired && isAuthenticated)
          if showSpinner && !isTracked {
            ProgressView().tint(tokens.accent)
          } else {
            Ionicon(
              isTracked ? (isKaza ? "time-outline" : "checkmark")
                : !isAuthenticated ? "lock-closed-outline" : prayerIcon(prayer.id),
              size: isTracked ? 20 : 18,
              color: isTracked ? (isKaza ? .white : tokens.onAccent)
                : (isCurrent && isAuthenticated) ? tokens.gold : tokens.inkSubtle
            )
            .transition(.opacity)
          }
        }
        .frame(width: 52, height: 52)
        .padding(.bottom, 7)

        Text(prayerLabel(prayer.name))
          .font(.system(size: 13, weight: isCurrent || isTracked ? .semibold : .regular))
          .foregroundStyle(isCurrent || isTracked ? tokens.textPrimary : (tokens.isDark ? Forest.s400 : Forest.s600))
        Text(showKazaLabel ? t("home.tracker.kaza") : time)
          .font(.system(size: 10.5))
          .foregroundStyle(showKazaLabel ? (tokens.isDark ? Amber.s400 : Amber.s600) : (tokens.isDark ? Forest.s500 : Forest.s400))
          .tabularNumbers()
      }
      .frame(maxWidth: .infinity)
      .opacity((isAuthenticated && isUpcoming) || OzelGunStore.shared.isActive ? 0.4 : 1)
      .animation(.easeOut(duration: 0.2), value: isTracked)
    }
    .buttonStyle(PressableStyle())
    .disabled(isTracked || (isAuthenticated && (isUpcoming || OzelGunStore.shared.isActive)))
    .accessibilityLabel("\(prayerLabel(prayer.name)) \(time), \(status)")
  }

  @ViewBuilder
  private func circleBackground(isTracked: Bool, isKaza: Bool, isCurrent: Bool, isExpired: Bool) -> some View {
    if isTracked {
      Circle().fill(isKaza ? Amber.s500 : tokens.accent)
    } else if isCurrent {
      Circle()
        .fill(tokens.isDark ? Gold.s700.opacity(0.15) : Gold.s50)
        .overlay(Circle().strokeBorder(Gold.s400, lineWidth: 2))
    } else if isExpired {
      Circle().strokeBorder(tokens.isDark ? Forest.s600 : Forest.s300, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
    } else {
      Circle().fill(tokens.fill)
    }
  }

  private func slotState(_ prayer: Prayer, now: Date) -> SlotState {
    guard let times else { return .loading }
    let cal = Calendar.current
    let nowMin = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
    func minutes(_ hhmm: String) -> Int {
      let p = hhmm.split(separator: ":").compactMap { Int($0) }
      return (p.first ?? 0) * 60 + (p.count > 1 ? p[1] : 0)
    }
    // Gece yarısı ile imsak arası hâlâ önceki namaz günü.
    let inIslamicBridge = nowMin < minutes(times.imsak)
    let start = minutes(times[prayer.timeKey] ?? "00:00")

    if prayer.id == "isha" {
      return nowMin >= start || inIslamicBridge ? .current : .upcoming
    }
    if inIslamicBridge { return .expired }
    let end = prayer.nextTimeKey.flatMap { times[$0] }.map(minutes) ?? start + 240
    if nowMin < start { return .upcoming }
    return nowMin < end ? .current : .expired
  }

  private func track(_ prayer: Prayer, state: SlotState, isAuthenticated: Bool) async {
    guard isAuthenticated else {
      onAuthRequired()
      return
    }
    guard !OzelGunStore.shared.isActive, !DebugLaunch.isIsolated else { return }
    let store = GamificationStore.shared
    if state == .upcoming || (store.stats?.today_prayers.contains(prayer.id) ?? false) {
      Haptics.notify(.error)
      return
    }
    let isKaza = state == .expired
    Haptics.notify(isKaza ? .warning : .success)

    // Bu dokunuş günü 5/5 tamamlıyorsa kutlamayı sunucu yanıtı gösterir (yeni seriyle).
    let completesDay = (store.stats?.today_prayers.count ?? 0) == 4
    if completesDay { awaitingStreak = true }
    defer { if completesDay { awaitingStreak = false } }

    guard let result = try? await store.trackPrayer(prayer.id, isKaza: isKaza) else { return }
    if result.streakIncremented, result.todayCount >= 5, result.currentStreak > 0 {
      Haptics.notify(.success)
      celebrate(result.currentStreak)
    }
  }

  /// Kutlama her namaz günü en fazla bir kez gösterilir.
  private func celebrate(_ streak: Int) {
    let key = "native.celebratedDay"
    let day = islamicDateString()
    guard streak > 0, UserDefaults.standard.string(forKey: key) != day else { return }
    UserDefaults.standard.set(day, forKey: key)
    onCelebrate(streak)
  }
}

/// 5/5 tamamlanınca kısa kutlama; 2,2 sn sonra ya da dokununca kapanır.
struct StreakCelebration: View {
  @Environment(\.tokens) private var tokens
  let streak: Int
  let onDismiss: () -> Void
  @State private var shown = false

  var body: some View {
    ZStack {
      Color.black.opacity(0.6).ignoresSafeArea()
      VStack(spacing: 0) {
        Ionicon("checkmark", size: 30, color: tokens.onAccent)
          .frame(width: 49, height: 49)
          .background(tokens.accent, in: .circle)
          .scaleEffect(shown ? 1 : 0.5)
          .padding(.bottom, 17.5)
        Text(t("celebration.title"))
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(tokens.textPrimary)
          .padding(.bottom, 3.5)
        Text(t("celebration.message"))
          .font(.system(size: 15))
          .foregroundStyle(tokens.textSecondary)
          .multilineTextAlignment(.center)
          .padding(.bottom, 21)
        Text("\(streak)")
          .font(.system(size: 42, weight: .semibold))
          .foregroundStyle(tokens.textPrimary)
          .tabularNumbers()
        Text(t("celebration.streakLabel"))
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(tokens.textSecondary)
          .padding(.top, 3.5)
      }
      .padding(.horizontal, 21)
      .padding(.vertical, 28)
      .frame(maxWidth: .infinity)
      .background(tokens.surface, in: .rect(cornerRadius: 21))
      .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
      .scaleEffect(shown ? 1 : 0.92)
      .padding(.horizontal, 28)
    }
    .opacity(shown ? 1 : 0)
    .onTapGesture(perform: onDismiss)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(t("celebration.a11y", ["count": streak]))
    .accessibilityAddTraits(.isButton)
    .task {
      withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { shown = true }
      try? await Task.sleep(for: .seconds(2.2))
      onDismiss()
    }
  }
}
