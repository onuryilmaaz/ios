import SwiftUI

@main
struct SalahApp: App {
  @UIApplicationDelegateAdaptor(SalahApplicationDelegate.self) private var appDelegate
  @Environment(\.scenePhase) private var scenePhase

  init() {
    // Her store'dan ÖNCE: RN sürümünün verisi (ilçe, tema, dil, cache, kuyruk)
    // ilk açılışta yerel depoya kopyalanır.
    LegacyMigration.runIfNeeded()
    #if DEBUG
    if DebugLaunch.sample { StorePreview.install() }
    #endif
  }

  var body: some Scene {
    WindowGroup {
      AppRoot()
        .task {
          guard !DebugLaunch.isIsolated else { return }
          _ = NetworkMonitor.shared
          OfflineQueue.shared.onFlushed = { _ in
            Task { await GamificationStore.shared.fetchStats(force: true) }
          }
          await AuthStore.shared.hydrate()
          await DebugSession.run()
          Task { await WidgetSync.activate() }
          await OfflineQueue.shared.flush()
          await AdhanPlayer.shared.activate()
          // Önce alarmlar: tam vaktinde alarm olan vakitte bildirim atlanır.
          await AlarmStore.shared.sync()
          await NotificationStore.shared.reschedule()
        }
        .onChange(of: scenePhase) { _, phase in
          if phase == .active, !DebugLaunch.isIsolated {
            Task { await OfflineQueue.shared.flush() }
            Task { await AdhanPlayer.shared.activate() }
            Task { await WidgetSync.activate() }
            Task { await LocationWatch.check() }
            Task {
              await AlarmStore.shared.sync()
              await NotificationStore.shared.reschedule()
            }
          } else if phase != .active {
            AdhanPlayer.shared.deactivate()
          }
        }
        .onChange(of: AuthStore.shared.isAuthenticated) { _, authenticated in
          guard authenticated, !DebugLaunch.isIsolated else { return }
          Task { await OfflineQueue.shared.flush() }
          Task { await WidgetSync.activate() }
        }
        .onChange(of: LocationChanges.shared.nonce) {
          guard !DebugLaunch.isIsolated else { return }
          Task { await NotificationStore.shared.reschedule(force: true) }
          Task { await AdhanPlayer.shared.activate() }
          Task { await AlarmStore.shared.sync(force: true) }
        }
        .onChange(of: Localizer.shared.language) {
          Task { await WidgetSync.languageChanged() }
          Task { await NotificationStore.shared.reschedule(force: true) }
          // Alarm başlıkları ve düğme metinleri yeni dilde kurulsun.
          Task { await AlarmStore.shared.sync(force: true) }
        }
        .onChange(of: NotificationStore.shared.preferences.muteUntil) {
          if NotificationStore.shared.preferences.isMuted() { AdhanPlayer.shared.stop() }
        }
    }
  }
}

/// Tema, dil ve yön tüm ağaca buradan verilir; değişince her şey yeniden çizilir.
private struct AppRoot: View {
  /// Animasyonlu açılış yalnız soğuk açılışta bir kez (testlerde ve izole önizlemede yok).
  @State private var splash = !DebugLaunch.isIsolated || DebugLaunch.splashPreview

  var body: some View {
    let theme = ThemeStore.shared
    let l10n = Localizer.shared
    ZStack {
      Group {
        if OnboardingStore.shared.done {
          RootView().transition(.opacity)
        } else {
          OnboardingView().transition(.opacity)
        }
      }
      .allowsHitTesting(!splash)
      .accessibilityHidden(splash)
      if splash {
        SplashView { splash = false }
          .zIndex(1)
      }
    }
      .environment(\.tokens, theme.tokens)
      .environment(\.layoutDirection, l10n.layoutDirection)
      .environment(\.locale, l10n.locale)
      .preferredColorScheme(theme.isDark ? .dark : .light)
      .onAppear { StatusBarStyle.apply() }
      .onChange(of: theme.isDark) { StatusBarStyle.apply() }
  }
}
