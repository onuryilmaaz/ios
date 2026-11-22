import FamilyControls
import SwiftUI

/// Ayarlar > Vakit kilidi: açma (Ekran Süresi izni), uygulama seçimi, kip (vakit girince / çıkmadan önce), süre ve vakitler.
struct PrayerLockView: View {
  @Environment(\.tokens) private var tokens
  @State private var picking = false
  @State private var draft = FamilyActivitySelection()
  /// "Özel" seçildi: dakika alanı açık (hazır seçeneklerden biri seçili olsa da).
  @State private var customOpen = false
  @State private var customText = ""
  @FocusState private var customFocused: Bool

  var body: some View {
    let store = PrayerLockStore.shared
    VStack(spacing: 0) {
      StandardHeader(title: t("prayerLock.title"))
      ScrollViewReader { proxy in
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          VStack(spacing: 8) {
            SceneAnimation(scene: "prayerLock").frame(width: 170, height: 170)
            Text(t("prayerLock.intro")).font(.system(size: 15)).lineSpacing(3).foregroundStyle(tokens.textSecondary)
              .multilineTextAlignment(.center)
          }
          .frame(maxWidth: .infinity)
          .tourAnchor("prayerLock.intro")
          toggleRow(store).tourAnchor("prayerLock.enable")
          if store.settings.enabled {
            appsRow(store).tourAnchor("prayerLock.apps")
            VStack(alignment: .leading, spacing: 16) {
            SectionLabel(t("prayerLock.when"))
            FlowLayout(spacing: 7) {
              chip(t("prayerLock.modeStart"), selected: store.settings.mode == .start) { store.setMode(.start); customOpen = false }
              chip(t("prayerLock.modeEnd"), selected: store.settings.mode == .end) { store.setMode(.end); customOpen = false }
            }
            Text(t(store.settings.mode == .start ? "prayerLock.modeStartHint" : "prayerLock.modeEndHint"))
              .font(.system(size: 13)).foregroundStyle(tokens.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
            .tourAnchor("prayerLock.mode")
            VStack(alignment: .leading, spacing: 16) { durationSection(store) }.tourAnchor("prayerLock.duration")
            VStack(alignment: .leading, spacing: 16) {
            SectionLabel(t("prayerLock.prayers"))
            FlowLayout(spacing: 7) {
              ForEach(PrayerLockStore.prayerIds, id: \.self) { id in
                chip(prayerLabel(id), selected: store.settings.prayers.contains(id)) { store.toggle(prayer: id) }
              }
            }
            }
            .tourAnchor("prayerLock.prayers")
          }
          HStack(alignment: .top, spacing: 7) {
            Ionicon("information-circle", size: 16, color: Amber.s500).padding(.top, 2)
            Text(t("prayerLock.info")).font(.system(size: 12)).lineSpacing(6)
              .foregroundStyle(tokens.isDark ? Amber.s300 : Amber.s700).frame(maxWidth: .infinity, alignment: .leading)
          }
          .padding(14)
          .background(tokens.isDark ? Amber.s500.opacity(0.1) : Amber.s50, in: .rect(cornerRadius: 14))
          .tourAnchor("prayerLock.info")
        }
        .padding(16).padding(.bottom, 84)
      }
      .scrollIndicators(.hidden)
      .tourScroll(proxy, top: "prayerLock.intro")
      }
    }
    .background(tokens.canvas)
    .toolbar(.hidden, for: .navigationBar)
    .familyActivityPicker(isPresented: $picking, selection: $draft)
    .onChange(of: picking) { _, open in
      if !open { store.setSelection(draft) }
    }
    .onAppear { store.foreground() }
    // İlk girişte: ne yapar ve nasıl açılır. Açılınca (ilk kez): uygulama seçimi, kip, süre, vakitler.
    .task { await TourStore.shared.startIfNeeded(.prayerLock) { TourStore.shared.anchors["prayerLock.enable"] != nil } }
    .task(id: store.settings.enabled && TourStore.shared.tour == nil) {
      guard store.settings.enabled, TourStore.shared.isDone(Tour.prayerLock.id) else { return }
      await TourStore.shared.startIfNeeded(.prayerLockSetup) { TourStore.shared.anchors["prayerLock.apps"] != nil && !picking }
    }
    .onChange(of: store.settings.mode) { _, _ in customText = String(currentMinutes(store)) }
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

  /// Kipin dakikası: `start` kilit süresi, `end` vaktin çıkmasına kalan.
  private func currentMinutes(_ store: PrayerLockStore) -> Int {
    store.settings.mode == .start ? store.settings.minutes : store.settings.beforeMinutes
  }

  private func setCurrentMinutes(_ store: PrayerLockStore, _ value: Int) {
    if store.settings.mode == .start { store.setMinutes(value) } else { store.setBeforeMinutes(value) }
  }

  @ViewBuilder
  private func durationSection(_ store: PrayerLockStore) -> some View {
    let start = store.settings.mode == .start
    let untilEnd = start && store.settings.untilEnd
    let value = currentMinutes(store)
    let isCustom = !untilEnd && (customOpen || !PrayerLockStore.minuteOptions.contains(value))
    SectionLabel(t(start ? "prayerLock.duration" : "prayerLock.before"))
    FlowLayout(spacing: 7) {
      ForEach(PrayerLockStore.minuteOptions, id: \.self) { m in
        chip(t("prayerLock.minutes", ["count": m]), selected: !untilEnd && !isCustom && value == m) {
          customOpen = false
          customFocused = false
          setCurrentMinutes(store, m)
        }
      }
      if start {
        chip(t("prayerLock.untilEnd"), selected: untilEnd) {
          customOpen = false
          customFocused = false
          store.setUntilEnd()
        }
      }
      chip(isCustom ? t("prayerLock.minutes", ["count": value]) : t("prayerLock.custom"), selected: isCustom) {
        customOpen = true
        customText = String(value)
        if untilEnd { setCurrentMinutes(store, value) }
        customFocused = true
      }
    }
    if isCustom { customRow(store) }
  }

  private func customRow(_ store: PrayerLockStore) -> some View {
    let range = PrayerLockShared.minuteRange
    return VStack(alignment: .leading, spacing: 7) {
      HStack(spacing: 10.5) {
        Text(t("prayerLock.customLabel")).font(.system(size: 15, weight: .medium)).foregroundStyle(tokens.textPrimary)
          .frame(maxWidth: .infinity, alignment: .leading)
        TextField("", text: $customText)
          .keyboardType(.numberPad)
          .focused($customFocused)
          .multilineTextAlignment(.trailing)
          .font(.system(size: 17, weight: .semibold).monospacedDigit())
          .foregroundStyle(tokens.textPrimary)
          .frame(width: 64)
          .onChange(of: customText) { _, text in
            let digits = String(text.filter(\.isNumber).prefix(3))
            if digits != text { customText = digits; return }
            if let v = Int(digits), range.contains(v), v != currentMinutes(store) { setCurrentMinutes(store, v) }
          }
        Text(t("prayerLock.minuteUnit")).font(.system(size: 15)).foregroundStyle(tokens.textSecondary)
      }
      .padding(.horizontal, 14).padding(.vertical, 10.5)
      .background(tokens.surface, in: .rect(cornerRadius: 21))
      .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
      Text(t("prayerLock.customRange", ["min": range.lowerBound, "max": range.upperBound]))
        .font(.system(size: 13)).foregroundStyle(invalidCustom ? tokens.danger : tokens.textSecondary)
        .padding(.leading, 10.5)
    }
    .onAppear { if customText.isEmpty { customText = String(currentMinutes(store)) } }
  }

  private var invalidCustom: Bool {
    guard let v = Int(customText) else { return true }
    return !PrayerLockShared.minuteRange.contains(v)
  }

  private func appsRow(_ store: PrayerLockStore) -> some View {
    let s = store.selection
    let count = store.previewAppCount ?? (s.applicationTokens.count + s.categoryTokens.count + s.webDomainTokens.count)
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
