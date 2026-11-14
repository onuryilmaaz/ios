import FamilyControls
import SwiftUI

/// Ayarlar > Vakit kilidi: açma (Ekran Süresi izni), uygulama seçimi, süre ve vakitler.
struct PrayerLockView: View {
  @Environment(\.tokens) private var tokens
  @State private var picking = false
  @State private var draft = FamilyActivitySelection()

  var body: some View {
    let store = PrayerLockStore.shared
    VStack(spacing: 0) {
      StandardHeader(title: t("prayerLock.title"))
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          Text(t("prayerLock.intro")).font(.system(size: 15)).lineSpacing(3).foregroundStyle(tokens.textSecondary)
          toggleRow(store)
          if store.settings.enabled {
            appsRow(store)
            SectionLabel(t("prayerLock.duration"))
            HStack(spacing: 7) {
              ForEach(PrayerLockStore.minuteOptions, id: \.self) { m in
                chip(t("prayerLock.minutes", ["count": m]), selected: store.settings.minutes == m) { store.setMinutes(m) }
              }
            }
            SectionLabel(t("prayerLock.prayers"))
            FlowLayout(spacing: 7) {
              ForEach(PrayerLockStore.prayerIds, id: \.self) { id in
                chip(prayerLabel(id), selected: store.settings.prayers.contains(id)) { store.toggle(prayer: id) }
              }
            }
          }
          HStack(alignment: .top, spacing: 7) {
            Ionicon("information-circle", size: 16, color: Amber.s500).padding(.top, 2)
            Text(t("prayerLock.info")).font(.system(size: 12)).lineSpacing(6)
              .foregroundStyle(tokens.isDark ? Amber.s300 : Amber.s700).frame(maxWidth: .infinity, alignment: .leading)
          }
          .padding(14)
          .background(tokens.isDark ? Amber.s500.opacity(0.1) : Amber.s50, in: .rect(cornerRadius: 14))
        }
        .padding(16).padding(.bottom, 84)
      }
      .scrollIndicators(.hidden)
    }
    .background(tokens.canvas)
    .toolbar(.hidden, for: .navigationBar)
    .familyActivityPicker(isPresented: $picking, selection: $draft)
    .onChange(of: picking) { _, open in
      if !open { store.setSelection(draft) }
    }
    .onAppear { store.foreground() }
  }

  private func toggleRow(_ store: PrayerLockStore) -> some View {
    HStack(spacing: 10.5) {
      VStack(alignment: .leading, spacing: 1.75) {
        Text(t("prayerLock.enable")).font(.system(size: 15, weight: .medium)).foregroundStyle(tokens.textPrimary)
        Text(t(store.authorized ? "prayerLock.enableHint" : "prayerLock.permissionHint")).font(.system(size: 13)).foregroundStyle(tokens.textSecondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      Toggle("", isOn: Binding(get: { store.settings.enabled }, set: { on in
        Haptics.impact(.medium)
        Task {
          await store.setEnabled(on)
          if on, !store.authorized { AppAlert.error(t("prayerLock.title"), t("prayerLock.permissionDenied")) }
        }
      }))
      .labelsHidden().tint(tokens.accent)
    }
    .padding(14)
    .background(tokens.surface, in: .rect(cornerRadius: 21))
    .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
  }

  private func appsRow(_ store: PrayerLockStore) -> some View {
    let s = store.selection
    let count = s.applicationTokens.count + s.categoryTokens.count + s.webDomainTokens.count
    return Button {
      Haptics.impact(.light)
      draft = store.selection
      picking = true
    } label: {
      HStack(spacing: 10.5) {
        Ionicon("apps-outline", size: 18, color: tokens.accent).frame(width: 35, height: 35).background(tokens.accentSoft, in: .circle)
        VStack(alignment: .leading, spacing: 1.75) {
          Text(t("prayerLock.apps")).font(.system(size: 15, weight: .medium)).foregroundStyle(tokens.textPrimary)
          Text(count == 0 ? t("prayerLock.appsNone") : t("prayerLock.appsCount", ["count": count]))
            .font(.system(size: 13)).foregroundStyle(count == 0 ? tokens.danger : tokens.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        Ionicon(dirIcon("chevron-forward"), size: 16, color: tokens.inkSubtle)
      }
      .padding(14)
      .background(tokens.surface, in: .rect(cornerRadius: 21))
      .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
    }
    .buttonStyle(PressableStyle())
  }

  private func chip(_ text: String, selected: Bool, action: @escaping () -> Void) -> some View {
    Button { Haptics.impact(.light); action() } label: {
      Text(text).font(.system(size: 13, weight: .semibold))
        .foregroundStyle(selected ? tokens.accent : tokens.textSecondary)
        .padding(.horizontal, 12.25).padding(.vertical, 7)
        .background(selected ? tokens.accentSoft : tokens.surface, in: .capsule)
        .overlay(Capsule().stroke(selected ? tokens.accent : tokens.line, lineWidth: 1))
    }
    .buttonStyle(PressableStyle())
    .accessibilityAddTraits(selected ? .isSelected : [])
  }
}
