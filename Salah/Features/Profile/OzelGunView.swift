import SwiftUI

/// RN OzelGunScreen; dönem bellektedir, sunucuya yalnız onaydan sonra yazılır.
struct OzelGunView: View {
  @Environment(\.tokens) private var tokens
  @Environment(\.scenePhase) private var scenePhase
  private var store: OzelGunStore { .shared }

  var body: some View {
    VStack(spacing: 0) {
      StandardHeader(title: t("ozelGun.screen.title"))
      if store.userID == nil {
        message(icon: "lock-closed-outline", title: "authWall.defaultTitle", hint: "authWall.defaultDescription") {
          AppButton(title: t("auth.signIn")) { Haptics.impact(.light); AuthFlow.shared.present(.login) }
        }
      } else if !store.loaded { skeleton }
      else if store.loadFailed {
        message(icon: "cloud-offline-outline", title: "ozelGun.screen.loadFailed", hint: nil) {
          AppButton(title: t("common.retry"), loading: store.isLoading) { Task { await store.fetch() } }
        }
      } else if store.gender != "kadin" && !store.isActive {
        message(icon: "information-circle-outline", title: "ozelGun.screen.womenOnly", hint: "ozelGun.screen.womenOnlyHint") { EmptyView() }
      } else {
        TimelineView(.everyMinute) { context in
          ScrollView {
            VStack(spacing: 14) {
              status(now: context.date)
              protection
              action
              Text(t("ozelGun.screen.private")).font(.system(size: 12)).foregroundStyle(Forest.s400)
                .multilineTextAlignment(.center).padding(.horizontal, 7).padding(.top, 3.5)
            }.padding(16).padding(.bottom, 24)
          }.scrollIndicators(.hidden).refreshable { await store.fetch() }
        }
      }
    }
    .background(tokens.canvas).toolbar(.hidden, for: .navigationBar)
    .task(id: AuthStore.shared.user) { if DebugLaunch.ozelGun == nil { await store.fetch() } }
    .task(id: scenePhase) { if scenePhase == .active && DebugLaunch.ozelGun == nil { await store.fetch() } }
    .task {
      guard let preview = DebugLaunch.ozelGun, ["confirmStart", "confirmEnd"].contains(preview) else { return }
      try? await Task.sleep(for: .milliseconds(300))
      if !Task.isCancelled { OzelGunActions.confirm(starting: preview == "confirmStart", screen: true) }
    }
  }

  private func status(now: Date) -> some View {
    let active = store.isActive
    let color = active ? Gold.s500 : tokens.isDark ? Accent.s500 : Accent.s600
    return HStack(spacing: 10.5) {
      Ionicon(active ? "pause-circle" : "checkmark-circle", size: 28, color: color)
        .frame(width: 49, height: 49).background(color.opacity(0.145), in: .rect(cornerRadius: 14))
      VStack(alignment: .leading, spacing: 1.75) {
        Text(t(active ? "ozelGun.screen.active" : "ozelGun.screen.inactive"))
          .font(.system(size: 12, weight: .medium)).foregroundStyle(color)
        Text(active ? t("ozelGun.screen.day", ["day": store.period.flatMap { OzelGunDates.daysSince($0.start_date, now: now) } ?? 1]) : t("ozelGun.screen.prayerTime"))
          .font(.system(size: 15.75, weight: .semibold)).foregroundStyle(tokens.textPrimary)
        if active, let start = store.period.flatMap({ OzelGunDates.date($0.start_date) }) {
          Text("\(t("ozelGun.screen.startDate")) \(HijriCalendarText.gregorian(start, template: "dMMMMyyyy", calendar: HijriMath.gregorianCalendar))")
            .font(.system(size: 10.5)).foregroundStyle(tokens.textSecondary)
        }
      }.frame(maxWidth: .infinity, alignment: .leading)
    }.padding(21)
      .background(active ? tokens.isDark ? Gold.s400.opacity(0.1) : Gold.s50 : tokens.isDark ? Accent.s500.opacity(0.1) : Accent.s50)
      .overlay(alignment: .topTrailing) { Circle().fill(color.opacity(0.08)).frame(width: 112, height: 112).offset(x: 28, y: -28).allowsHitTesting(false) }
      .clipShape(.rect(cornerRadius: 14))
      .overlay(RoundedRectangle(cornerRadius: 14).stroke(active ? tokens.isDark ? Gold.s700 : Gold.s200 : tokens.isDark ? Accent.s800 : Accent.s200, lineWidth: 1))
  }

  private var protection: some View {
    VStack(alignment: .leading, spacing: 7) {
      HStack(spacing: 7) {
        Ionicon("shield-checkmark-outline", size: 18, color: tokens.isDark ? Accent.s500 : Accent.s600)
        Text(t("ozelGun.screen.protection")).font(.system(size: 12.25, weight: .semibold)).foregroundStyle(tokens.textPrimary)
      }
      Text(t("ozelGun.screen.protectionText")).font(.system(size: 10.5)).lineSpacing(6).foregroundStyle(tokens.textSecondary)
    }.frame(maxWidth: .infinity, alignment: .leading).padding(17.5)
      .background(tokens.surface, in: .rect(cornerRadius: 21))
      .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
  }

  private var action: some View {
    Button { OzelGunActions.confirm(starting: !store.isActive, screen: true) } label: {
      HStack(spacing: 7) {
        if store.isLoading { ProgressView().tint(.white) }
        else {
          Ionicon(store.isActive ? "stop-circle-outline" : "play-circle-outline", size: 18, color: .white)
          Text(t(store.isActive ? "ozelGun.screen.endToday" : "ozelGun.screen.startNew")).font(.system(size: 12.25, weight: .semibold)).foregroundStyle(.white)
        }
      }.frame(maxWidth: .infinity).padding(.horizontal, 17.5).padding(.vertical, 14)
        .background(store.isActive ? tokens.isDark ? Gold.s600 : Gold.s400 : tokens.isDark ? Accent.s500 : Accent.s600, in: .rect(cornerRadius: 14))
    }.buttonStyle(PressableStyle()).disabled(store.isLoading || !store.canManage)
  }

  private func message<Action: View>(icon: String, title: String, hint: String?, @ViewBuilder action: () -> Action) -> some View {
    VStack(spacing: 0) {
      Ionicon(icon, size: 36, color: tokens.textSecondary).frame(width: 70, height: 70).background(tokens.fill, in: .rect(cornerRadius: 14))
      Text(t(title)).font(.system(size: 15.75, weight: .semibold)).foregroundStyle(tokens.textPrimary).padding(.top, 17.5)
      if let hint { Text(t(hint)).font(.system(size: 12.25)).foregroundStyle(tokens.textSecondary).padding(.top, 7) }
      action().padding(.top, 20).frame(maxWidth: 240)
    }.multilineTextAlignment(.center).padding(.horizontal, 28).frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var skeleton: some View {
    ScrollView {
      VStack(spacing: 14) {
        HStack(spacing: 10.5) {
          placeholder(width: 56, height: 56, radius: 20)
          VStack(alignment: .leading, spacing: 7) {
            placeholder(width: 85, height: 10)
            placeholder(width: 130, height: 22)
            placeholder(width: 110, height: 10)
          }.frame(maxWidth: .infinity, alignment: .leading)
        }.padding(21).background(tokens.surface, in: .rect(cornerRadius: 21))
          .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
        VStack(alignment: .leading, spacing: 10.5) {
          placeholder(width: 140, height: 14)
          placeholder(height: 10)
          placeholder(width: 270, height: 10)
          placeholder(width: 180, height: 10)
        }.padding(17.5).background(tokens.surface, in: .rect(cornerRadius: 21))
          .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
        placeholder(height: 56, radius: 16)
      }.padding(16)
    }.scrollIndicators(.hidden).accessibilityElement(children: .ignore).accessibilityLabel(t("common.loading"))
  }
  private func placeholder(width: CGFloat? = nil, height: CGFloat, radius: CGFloat = 4) -> some View {
    RoundedRectangle(cornerRadius: radius).fill(tokens.fill).frame(width: width, height: height)
  }
}

enum OzelGunActions {
  static func confirm(starting: Bool, screen: Bool = false) {
    let store = OzelGunStore.shared
    guard store.canManage, !store.isLoading, let userID = store.userID else { return }
    Haptics.impact(.medium)
    let prefix = screen ? "ozelGun.screen" : "ozelGun"
    AppAlert.confirm(t("\(prefix).\(starting ? "startTitle" : "endTitle")"), t("\(prefix).\(starting ? "startMessage" : "endMessage")"),
      confirmText: t(starting ? "ozelGun.start" : screen ? "ozelGun.end" : "home.tracker.ozelGunEnd"),
      cancelText: t(screen ? "common.cancelAlt" : "common.cancel"), destructive: screen && !starting) {
      guard store.userID == userID, store.canManage, !store.isLoading, store.isActive != starting else { return }
      do {
        if starting { try await store.start() } else { try await store.end() }
        if screen, store.userID == userID {
          Toast.success(t(starting ? "ozelGun.screen.started" : "ozelGun.screen.ended"), t(starting ? "ozelGun.screen.startedMessage" : "ozelGun.screen.endedMessage"))
        }
      } catch OzelGunFailure.superseded { }
      catch {
        if store.userID == userID { AppAlert.error(t("common.error"), t(starting ? "ozelGun.screen.startFailed" : "ozelGun.screen.endFailed")) }
      }
    }
  }
}
