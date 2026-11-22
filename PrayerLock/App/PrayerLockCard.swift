import SwiftUI

/// Ana sayfa kartı: vakit kilidinin durumu (kapalı, uygulama seçilmedi, şu an kilitli, plan) ve ekrana giriş.
struct PrayerLockCard: View {
  @Environment(\.tokens) private var tokens
  let onOpen: () -> Void

  var body: some View {
    let store = PrayerLockStore.shared
    let s = store.settings
    let dark = tokens.isDark
    let active = s.enabled && store.authorized
    let locked = active ? store.current : nil

    Card {
      Button {
        Haptics.impact(.light)
        onOpen()
      } label: {
        HStack(spacing: 10.5) {
          Ionicon(locked == nil ? "lock-closed-outline" : "lock-closed", size: 20, color: tokens.gold)
            .frame(width: 38.5, height: 38.5)
            .background(dark ? Gold.s700.opacity(0.2) : Gold.s50, in: .circle)
          VStack(alignment: .leading, spacing: 1.75) {
            if let locked {
              Text(t("prayerLockCard.lockedNow", ["prayer": prayerLabel(locked)]))
                .font(.system(size: 17, weight: .semibold)).foregroundStyle(tokens.textPrimary)
              Text(t("prayerLockCard.lockedHint")).font(.system(size: 13)).foregroundStyle(tokens.textSecondary)
            } else {
              Text(t("prayerLock.title")).font(.system(size: 17, weight: .semibold)).foregroundStyle(tokens.textPrimary)
              Text(subtitle(store, active: active))
                .font(.system(size: 13))
                .foregroundStyle(active && !store.hasSelection ? tokens.danger : tokens.textSecondary)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          Ionicon(dirIcon("chevron-forward"), size: 18, color: tokens.inkSubtle)
        }
        .contentShape(.rect)
      }
      .buttonStyle(PressableStyle())

      if active, store.hasSelection, locked == nil, !s.prayers.isEmpty {
        FlowLayout(spacing: 7) {
          ForEach(PrayerLockStore.prayerIds.filter(s.prayers.contains), id: \.self) { id in
            Text(prayerLabel(id))
              .font(.system(size: 13, weight: .medium))
              .foregroundStyle(dark ? Accent.s200 : Accent.s700)
              .padding(.horizontal, 10.5)
              .padding(.vertical, 5.25)
              .background(dark ? Accent.s900 : Accent.s50, in: .capsule)
          }
        }
        .padding(.top, 14)
      } else if !active {
        AppButton(title: t("prayerLockCard.setup"), variant: .secondary, action: onOpen).padding(.top, 14)
      }
    }
    // Ana sayfa kartları boşluğu kendisi verir (AlarmsCard ile aynı).
    .padding(.horizontal, 14)
    .padding(.bottom, 10.5)
  }

  private func subtitle(_ store: PrayerLockStore, active: Bool) -> String {
    guard active else { return t("prayerLockCard.empty") }
    guard store.hasSelection else { return t("prayerLockCard.noApps") }
    let s = store.settings
    switch s.mode {
    case .start: return s.untilEnd ? t("prayerLockCard.untilEnd") : t("prayerLockCard.start", ["count": s.minutes])
    case .end: return t("prayerLockCard.end", ["count": s.beforeMinutes])
    }
  }
}
