import AVFoundation
import SwiftUI

/// Alarmlar (iOS 26+ AlarmKit). RN: screens/user/AlarmsScreen.tsx
struct AlarmsView: View {
  @Environment(\.tokens) private var tokens
  @Environment(\.scenePhase) private var scenePhase
  @State private var checked = false
  @State private var draft: AlarmDraft?
  /// Vakit alarmı değiştiyse çıkışta bildirim planı yenilenir (tam vakit bildirimi alarmla çakışmasın).
  @State private var prayerAlarmsChanged = false

  private static let prayerOffsets = [-45, -30, -15, -10, -5, 0, 5, 10, 15, 30, 45]
  private static let tahajjudOffsets = [0, 15, 30, 60]
  private static let sahurMinutes = [30, 45, 60, 90]
  private static let snoozeMinutes = [5, 10, 15]
  private static let soundOptions = ["adhan"] + AlarmPlan.tones + ["default"]

  var body: some View {
    let store = AlarmStore.shared
    VStack(spacing: 0) {
      StandardHeader(title: t("alarm.screen.title"))
      if !checked {
        Spacer()
      } else if !store.supported {
        EmptyState(icon: "alarm-outline", title: t("alarm.unsupported.title"), message: t("alarm.unsupported.message"))
        Spacer()
      } else {
        content(store)
      }
    }
    .background(tokens.canvas)
    .toolbar(.hidden, for: .navigationBar)
    .task {
      await store.sync()
      checked = true
    }
    // İlk özel alarm olunca bir kez: dokun düzenle, basılı tut sil.
    .task(id: AlarmTourTrigger(nonce: TourStore.shared.replayNonce, hasCustom: !store.settings.custom.isEmpty)) {
      guard !store.settings.custom.isEmpty else { return }
      await TourStore.shared.startIfNeeded(.alarms) {
        draft == nil && TourStore.shared.anchors["alarms.custom"] != nil
      }
    }
    // Ayarlar'dan izin verip dönünce durumu tazele.
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { Task { await store.sync() } }
    }
    .onDisappear {
      AlarmSoundPreview.stop()
      if prayerAlarmsChanged {
        prayerAlarmsChanged = false
        Task { await NotificationStore.shared.reschedule(force: true) }
      }
    }
    .sheet(item: $draft) { d in
      CustomAlarmForm(initial: d) { saved in
        draft = nil
        Task { await save(saved) }
      } onDelete: { id in
        confirmDelete(id)
      }
      .presentationDetents([.fraction(0.75), .fraction(0.9)])
      .presentationDragIndicator(.visible)
      .presentationBackground(tokens.surface)
      .presentationCornerRadius(24)
      .environment(\.tokens, tokens)
    }
  }

  private struct AlarmTourTrigger: Equatable {
    let nonce: Int
    let hasCustom: Bool
  }

  private func content(_ store: AlarmStore) -> some View {
    let s = store.settings
    let dark = tokens.isDark
    return ScrollViewReader { proxy in
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        if store.auth == .authorized {
          HStack(spacing: 14) {
            Ionicon("alarm", size: 22, color: Gold.s300)
              .frame(width: 42, height: 42)
              .background(.white.opacity(0.1), in: .circle)
            VStack(alignment: .leading, spacing: 1.75) {
              Text(t("alarm.screen.next")).font(.system(size: 13)).foregroundStyle(.white.opacity(0.7))
              Text(store.next?.title ?? t("alarm.screen.noNext")).font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
              if let next = store.next {
                Text(AlarmText.nextAlarm(next.fireAt)).font(.system(size: 15)).foregroundStyle(Gold.s300).tabularNumbers()
              }
            }
            Spacer(minLength: 0)
          }
          .padding(17.5)
          .background(dark ? Accent.s900 : Accent.s800, in: .rect(cornerRadius: 21))
        } else {
          Card {
            HStack(spacing: 10.5) {
              Ionicon("alarm-outline", size: 20, color: tokens.accent)
                .frame(width: 35, height: 35)
                .background(dark ? Accent.s900 : Accent.s50, in: .circle)
              Text(t("alarm.permission.title")).font(.system(size: 17, weight: .semibold)).foregroundStyle(tokens.textPrimary)
            }
            Text(t(store.auth == .denied ? "alarm.permission.denied" : "alarm.permission.message"))
              .font(.system(size: 15)).foregroundStyle(tokens.textSecondary).padding(.vertical, 12)
            AppButton(title: t(store.auth == .denied ? "alarm.permission.openSettings" : "alarm.permission.allow")) {
              Haptics.impact(.medium)
              if store.auth == .denied {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
              } else {
                Task { _ = await store.ensureAuthorized() }
              }
            }
          }
        }

        section(t("alarm.section.prayers")) {
          ForEach(Array(AlarmPlan.prayerKeys.enumerated()), id: \.element) { i, key in
            let p = s.prayers[key] ?? .init(enabled: false, offset: 0)
            ToggleRow(icon: prayerIcon(key), label: prayerLabel(key), sublabel: p.enabled ? AlarmText.offset(p.offset) : nil, value: p.enabled, last: i == AlarmPlan.prayerKeys.count - 1) { enabled in
              Task { if await store.setPrayer(key, enabled: enabled, rescheduleNotifications: false) { prayerAlarmsChanged = true } }
            } content: {
              OffsetPicker(presets: Self.prayerOffsets, value: p.offset, mode: .both, label: AlarmText.offset) { offset in
                Task { if await store.setPrayer(key, offset: offset, rescheduleNotifications: false) { prayerAlarmsChanged = true } }
              }
            }
          }
        }

        section(t("alarm.section.night")) {
          ToggleRow(icon: "moon-outline", label: t("alarm.tahajjud.label"), sublabel: t("alarm.tahajjud.sub"), value: s.tahajjud.enabled) { enabled in
            Task {
              if enabled, !(await store.ensureAuthorized()) { return }
              await store.update { $0.tahajjud.enabled = enabled }
            }
          } content: {
            OffsetPicker(presets: Self.tahajjudOffsets, value: s.tahajjud.offset, mode: .after, label: { $0 == 0 ? t("alarm.tahajjud.start") : AlarmText.offset($0) }) { offset in
              Task { await store.update { $0.tahajjud.offset = offset } }
            }
          }
          ToggleRow(icon: "restaurant-outline", label: t("alarm.sahur.label"), sublabel: t("alarm.sahur.sub", ["min": s.sahur.minutesBefore]), value: s.sahur.enabled, last: true) { enabled in
            Task {
              if enabled, !(await store.ensureAuthorized()) { return }
              await store.update { $0.sahur.enabled = enabled }
            }
          } content: {
            OffsetPicker(presets: Self.sahurMinutes, value: s.sahur.minutesBefore, mode: .before, label: { AlarmText.offset(-$0) }) { minutes in
              Task { await store.update { $0.sahur.minutesBefore = minutes } }
            }
            HStack {
              VStack(alignment: .leading, spacing: 2) {
                Text(t("alarm.sahur.onlyRamadan")).font(.system(size: 15)).foregroundStyle(tokens.textPrimary)
                Text(t("alarm.sahur.onlyRamadanSub")).font(.system(size: 13)).foregroundStyle(tokens.textSecondary)
              }
              Spacer()
              Toggle("", isOn: Binding(get: { s.sahur.onlyRamadan }, set: { v in
                Haptics.impact(.medium)
                Task { await store.update { $0.sahur.onlyRamadan = v } }
              }))
              .labelsHidden().tint(tokens.accent)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10.5)
            .overlay(alignment: .top) { RowDivider(leading: 0) }
          }
        }

        VStack(alignment: .leading, spacing: 0) {
          SectionLabel(t("alarm.section.custom"))
          if s.custom.isEmpty {
            GroupedCard {
              EmptyState(icon: "alarm-outline", title: t("alarm.custom.emptyTitle"), message: t("alarm.custom.emptyMessage")) {
                AppButton(title: t("alarm.custom.add")) { Task { await openDraft(nil) } }.fixedSize()
              }
            }
          } else {
            VStack(spacing: 12) {
              GroupedCard {
                ForEach(Array(s.custom.enumerated()), id: \.element.id) { i, c in
                  customRow(c, store: store)
                    .tourAnchor(i == 0 ? "alarms.custom" : nil)
                  if i < s.custom.count - 1 { RowDivider() }
                }
              }
              AppButton(title: t("alarm.custom.add"), variant: .secondary) { Task { await openDraft(nil) } }
            }
          }
        }

        options(store)

        VStack(alignment: .leading, spacing: 8) {
          if store.limitReached {
            Text(t("alarm.limit")).font(.system(size: 13)).foregroundStyle(tokens.textSecondary)
          }
          Text(t("alarm.footer")).font(.system(size: 13)).foregroundStyle(tokens.textSecondary)
        }
        .padding(.horizontal, 4)
      }
      .padding(16)
      .padding(.bottom, 24)
    }
    .scrollIndicators(.hidden)
    .tourScroll(proxy, top: nil)
    }
  }

  private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      SectionLabel(title)
      GroupedCard { content() }
    }
  }

  private func customRow(_ c: AlarmSettings.Custom, store: AlarmStore) -> some View {
    let active = c.enabled && (!c.days.isEmpty || (c.onceAtDate ?? .distantPast) > Date())
    return HStack {
      VStack(alignment: .leading, spacing: 1.75) {
        Text(String(format: "%02d:%02d", c.hour, c.minute))
          .font(.system(size: 28, weight: .semibold))
          .foregroundStyle(c.enabled ? tokens.textPrimary : (tokens.isDark ? Forest.s500 : Forest.s400))
          .tabularNumbers()
        Text([c.label, AlarmText.repeatText(c.days)].filter { !$0.isEmpty }.joined(separator: " · "))
          .font(.system(size: 13)).foregroundStyle(tokens.textSecondary)
      }
      Spacer()
      Toggle("", isOn: Binding(get: { active }, set: { v in
        Haptics.impact(.medium)
        Task { await toggleCustom(c, enabled: v) }
      }))
      .labelsHidden().tint(tokens.accent)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12.25)
    .contentShape(.rect)
    .onTapGesture { Task { await openDraft(c) } }
    .onLongPressGesture { confirmDelete(c.id) }
  }

  private func options(_ store: AlarmStore) -> some View {
    let s = store.settings
    return VStack(alignment: .leading, spacing: 0) {
      SectionLabel(t("alarm.section.options"))
      VStack(alignment: .leading, spacing: 14) {
        VStack(alignment: .leading, spacing: 7) {
          FieldLabel(t("alarm.options.sound"))
          FlowLayout(spacing: 7) {
            ForEach(Self.soundOptions, id: \.self) { sound in
              AlarmChip(label: AlarmText.sound(sound), selected: s.sound == sound) {
                AlarmSoundPreview.play(sound)
                Task { await store.update { $0.sound = sound } }
              }
            }
          }
          Text(t("alarm.options.soundInfo")).font(.system(size: 13)).foregroundStyle(tokens.textSecondary)
        }
        VStack(alignment: .leading, spacing: 7) {
          FieldLabel(t("alarm.options.secondary"))
          HStack(spacing: 7) {
            AlarmChip(label: t("alarm.button.mark"), selected: s.secondary == "mark") { Task { await store.update { $0.secondary = "mark" } } }
            AlarmChip(label: t("alarm.button.snooze"), selected: s.secondary == "snooze") { Task { await store.update { $0.secondary = "snooze" } } }
          }
          if s.secondary == "mark" {
            Text(t("alarm.options.markInfo")).font(.system(size: 13)).foregroundStyle(tokens.textSecondary)
          }
        }
        VStack(alignment: .leading, spacing: 7) {
          FieldLabel(t("alarm.options.snoozeMinutes"))
          HStack(spacing: 7) {
            ForEach(Self.snoozeMinutes, id: \.self) { min in
              AlarmChip(label: t("alarm.options.minutes", ["min": min]), selected: s.snoozeMinutes == min) {
                Task { await store.update { $0.snoozeMinutes = min } }
              }
            }
          }
        }
      }
      .padding(14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(tokens.surface, in: .rect(cornerRadius: 21))
      .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
    }
  }

  // MARK: - Serbest alarm

  private func openDraft(_ alarm: AlarmSettings.Custom?) async {
    Haptics.impact(.light)
    if alarm == nil, !(await AlarmStore.shared.ensureAuthorized()) { return }
    draft = alarm.map { AlarmDraft(id: $0.id, hour: $0.hour, minute: $0.minute, days: $0.days, label: $0.label) }
      ?? AlarmDraft(id: nil, hour: 6, minute: 0, days: [], label: "")
  }

  private func save(_ d: AlarmDraft) async {
    Haptics.impact(.medium)
    let alarm = AlarmSettings.Custom(
      id: d.id ?? (String(Int(Date().timeIntervalSince1970 * 1000), radix: 36) + String(UUID().uuidString.prefix(4)).lowercased()),
      hour: d.hour, minute: d.minute, days: d.days.sorted(),
      onceAt: d.days.isEmpty ? AlarmPlan.nextOccurrence(hour: d.hour, minute: d.minute, now: Date()).timeIntervalSince1970 * 1000 : nil,
      label: d.label.trimmingCharacters(in: .whitespaces), enabled: true)
    await AlarmStore.shared.update { s in
      if d.id != nil {
        s.custom = s.custom.map { $0.id == d.id ? alarm : $0 }
      } else {
        s.custom = (s.custom + [alarm]).sorted { $0.hour * 60 + $0.minute < $1.hour * 60 + $1.minute }
      }
    }
  }

  private func toggleCustom(_ c: AlarmSettings.Custom, enabled: Bool) async {
    if enabled, !(await AlarmStore.shared.ensureAuthorized()) { return }
    await AlarmStore.shared.update { s in
      s.custom = s.custom.map { item in
        guard item.id == c.id else { return item }
        var copy = item
        copy.enabled = enabled
        // Tek seferlik alarm yeniden açılınca bir sonraki o saate kurulur.
        if enabled && item.days.isEmpty {
          copy.onceAt = AlarmPlan.nextOccurrence(hour: item.hour, minute: item.minute, now: Date()).timeIntervalSince1970 * 1000
        }
        return copy
      }
    }
  }

  private func confirmDelete(_ id: String) {
    Haptics.impact(.heavy)
    AppAlert.confirm(t("alarm.custom.deleteTitle"), t("alarm.custom.deleteMessage"), confirmText: t("common.delete"), cancelText: t("common.cancel"), destructive: true) {
      draft = nil
      await AlarmStore.shared.update { s in s.custom.removeAll { $0.id == id } }
    }
  }
}

/// Düzenlenen serbest alarm (`id` nil = yeni).
struct AlarmDraft: Identifiable, Equatable {
  var id: String?
  var hour: Int
  var minute: Int
  var days: [Int]
  var label: String
}

/// Alarm metinleri. RN: AlarmsScreen + alarm.actions yardımcıları.
enum AlarmText {
  /// Pazartesiden başlayan gösterim sırası (0 = Pazar).
  static let weekOrder = [1, 2, 3, 4, 5, 6, 0]

  static func offset(_ min: Int) -> String {
    if min == 0 { return t("alarm.offset.atTime") }
    return min < 0 ? t("alarm.offset.before", ["min": -min]) : t("alarm.offset.after", ["min": min])
  }

  static func sound(_ s: String) -> String {
    switch s {
    case "adhan": t("alarm.options.adhan")
    case "default": t("alarm.options.system")
    default: t("alarm.options.tone.\(s)")
    }
  }

  static func shortWeekday(_ jsDay: Int) -> String {
    let names = Localizer.shared.list("common.weekdaysShort")
    let i = (jsDay + 6) % 7
    return names.indices.contains(i) ? names[i] : ""
  }

  static func repeatText(_ days: [Int]) -> String {
    let set = Set(days)
    if set.isEmpty { return t("alarm.custom.once") }
    if set.count == 7 { return t("alarm.custom.everyDay") }
    if set == [1, 2, 3, 4, 5] { return t("alarm.custom.weekdays") }
    if set == [0, 6] { return t("alarm.custom.weekend") }
    return weekOrder.filter(set.contains).map(shortWeekday).joined(separator: ", ")
  }

  static func time(_ date: Date) -> String {
    date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).locale(Localizer.shared.locale))
  }

  /// "Bugün 05:30" / "Yarın 05:30" / "Pazartesi 3 Kasım 05:30".
  static func nextAlarm(_ date: Date, longDate: Bool = true) -> String {
    let cal = Calendar.current
    let diff = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: date)).day ?? 0
    let time = time(date)
    if diff == 0 { return t("alarm.screen.today", ["time": time]) }
    if diff == 1 { return t("alarm.screen.tomorrow", ["time": time]) }
    let style: Date.FormatStyle =
      longDate
      ? .dateTime.weekday(.wide).day().month(.wide).locale(Localizer.shared.locale)
      : .dateTime.weekday(.wide).locale(Localizer.shared.locale)
    return "\(date.formatted(style)) \(time)"
  }
}

/// Seçim çipi (kenarlıklı). RN: AlarmsScreen `Chip`.
struct AlarmChip: View {
  @Environment(\.tokens) private var tokens
  let label: String
  let selected: Bool
  let action: () -> Void

  var body: some View {
    let dark = tokens.isDark
    Button {
      Haptics.impact(.light)
      action()
    } label: {
      Text(label)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(selected ? (dark ? Accent.s300 : Accent.s700) : tokens.textSecondary)
        .padding(.horizontal, 12.25)
        .padding(.vertical, 7)
        .background(selected ? (dark ? Accent.s900 : Accent.s50) : (dark ? Forest.s950 : Forest.s50), in: .capsule)
        .overlay(Capsule().stroke(selected ? tokens.accent : tokens.line, lineWidth: 1))
    }
    .buttonStyle(PressableStyle())
    .accessibilityAddTraits(selected ? .isSelected : [])
  }
}

/// Anahtarlı satır; açıkken altında ayrıntı. RN: AlarmsScreen `ToggleRow`.
private struct ToggleRow<Content: View>: View {
  @Environment(\.tokens) private var tokens
  let icon: String
  let label: String
  var sublabel: String?
  let value: Bool
  var last = false
  let onChange: (Bool) -> Void
  @ViewBuilder var content: Content

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 0) {
        Ionicon(icon, size: 17, color: tokens.accent)
          .frame(width: 31.5, height: 31.5)
          .background(tokens.isDark ? Accent.s900 : Accent.s50, in: .circle)
          .padding(.trailing, 10.5)
        VStack(alignment: .leading, spacing: 1.75) {
          Text(label).font(.system(size: 16)).foregroundStyle(tokens.textPrimary)
          if let sublabel { Text(sublabel).font(.system(size: 13)).foregroundStyle(tokens.textSecondary) }
        }
        Spacer()
        Toggle("", isOn: Binding(get: { value }, set: { v in
          Haptics.impact(.medium)
          onChange(v)
        }))
        .labelsHidden().tint(tokens.accent)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 12.25)
      if value { content }
    }
    .overlay(alignment: .bottom) { if !last { RowDivider(leading: 0) } }
  }
}

/// Hazır dakika çipleri + "Özel" (listede olmayan değeri elle girme). RN: `OffsetPicker`.
private struct OffsetPicker: View {
  enum Mode { case both, after, before }
  let presets: [Int]
  let value: Int
  let mode: Mode
  let label: (Int) -> String
  let onChange: (Int) -> Void
  @State private var editing = false

  var body: some View {
    let isCustom = !presets.contains(value)
    VStack(alignment: .leading, spacing: 0) {
      ScrollView(.horizontal) {
        HStack(spacing: 7) {
          ForEach(presets, id: \.self) { min in
            AlarmChip(label: label(min), selected: !editing && value == min) {
              editing = false
              onChange(min)
            }
          }
          if isCustom {
            AlarmChip(label: label(value), selected: !editing) { editing = false }
          }
          AlarmChip(label: t("alarm.customOffset.chip"), selected: editing) { editing.toggle() }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
      }
      .scrollIndicators(.hidden)
      if editing {
        CustomOffsetEditor(mode: mode, initial: isCustom ? value : nil) { v in
          editing = false
          onChange(v)
        }
      }
    }
  }
}

private struct CustomOffsetEditor: View {
  let mode: OffsetPicker.Mode
  let initial: Int?
  let onApply: (Int) -> Void
  @State private var before: Bool
  @State private var text: String
  @State private var error: String?

  init(mode: OffsetPicker.Mode, initial: Int?, onApply: @escaping (Int) -> Void) {
    self.mode = mode
    self.initial = initial
    self.onApply = onApply
    _before = State(initialValue: mode == .before || (initial ?? 0) < 0)
    _text = State(initialValue: initial.map { String(abs($0)) } ?? "")
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10.5) {
      if mode == .both {
        HStack(spacing: 7) {
          AlarmChip(label: t("alarm.customOffset.before"), selected: before) { before = true }
          AlarmChip(label: t("alarm.customOffset.after"), selected: !before) { before = false }
        }
      }
      HStack(alignment: .top, spacing: 10.5) {
        InputField(placeholder: t("alarm.customOffset.minutes"), text: $text, keyboard: .numberPad, error: error, maxLength: 3)
          .onChange(of: text) { _, v in
            let digits = String(v.filter(\.isNumber).prefix(3))
            if digits != v { text = digits }
            error = nil
          }
        AppButton(title: t("alarm.customOffset.apply")) { apply() }.fixedSize()
      }
    }
    .padding(.horizontal, 14)
    .padding(.bottom, 14)
  }

  private func apply() {
    guard let n = Int(text), n >= 0, n <= AlarmPlan.maxOffsetMinutes else {
      Haptics.notify(.error)
      error = t("alarm.customOffset.invalid", ["max": AlarmPlan.maxOffsetMinutes])
      return
    }
    Haptics.impact(.medium)
    onApply(mode == .both && before ? -n : n)
  }
}

/// Serbest alarm formu (alttan açılan pencere). RN: `CustomAlarmForm`.
private struct CustomAlarmForm: View {
  @Environment(\.tokens) private var tokens
  @State private var draft: AlarmDraft
  let onSave: (AlarmDraft) -> Void
  let onDelete: (String) -> Void

  init(initial: AlarmDraft, onSave: @escaping (AlarmDraft) -> Void, onDelete: @escaping (String) -> Void) {
    _draft = State(initialValue: initial)
    self.onSave = onSave
    self.onDelete = onDelete
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        Text(t(draft.id == nil ? "alarm.custom.newTitle" : "alarm.custom.editTitle"))
          .font(.system(size: 17, weight: .semibold)).foregroundStyle(tokens.textPrimary)

        HStack(spacing: 14) {
          TimeStepper(value: $draft.hour, max: 24, step: 1, up: t("alarm.custom.hourUp"), down: t("alarm.custom.hourDown"))
          Text(verbatim: ":").font(.system(size: 48, weight: .bold)).foregroundStyle(tokens.isDark ? Forest.s500 : Forest.s400)
          TimeStepper(value: $draft.minute, max: 60, step: 5, up: t("alarm.custom.minuteUp"), down: t("alarm.custom.minuteDown"))
        }
        .frame(maxWidth: .infinity)
        .environment(\.layoutDirection, .leftToRight)

        VStack(alignment: .leading, spacing: 7) {
          FieldLabel(t("alarm.custom.repeat"))
          FlowLayout(spacing: 7) {
            ForEach(AlarmText.weekOrder, id: \.self) { d in
              AlarmChip(label: AlarmText.shortWeekday(d), selected: draft.days.contains(d)) {
                if draft.days.contains(d) { draft.days.removeAll { $0 == d } } else { draft.days.append(d) }
              }
            }
          }
          Text(AlarmText.repeatText(draft.days)).font(.system(size: 13)).foregroundStyle(tokens.textSecondary)
        }

        VStack(alignment: .leading, spacing: 0) {
          FieldLabel(t("alarm.custom.label"))
          InputField(placeholder: t("alarm.custom.labelPlaceholder"), text: $draft.label, maxLength: 40)
        }

        VStack(spacing: 10.5) {
          AppButton(title: t("common.save")) { onSave(draft) }
          if let id = draft.id {
            AppButton(title: t("common.delete"), variant: .danger) { onDelete(id) }
          }
        }
      }
      .padding(.horizontal, 17.5)
      .padding(.top, 24)
      .padding(.bottom, 32)
    }
    .scrollDismissesKeyboard(.interactively)
  }
}

private struct TimeStepper: View {
  @Environment(\.tokens) private var tokens
  @Binding var value: Int
  let max: Int
  let step: Int
  let up: String
  let down: String

  var body: some View {
    VStack(spacing: 7) {
      button("chevron-up", up) { value = (value + step + max) % max }
      Text(String(format: "%02d", value)).font(.system(size: 48, weight: .bold)).foregroundStyle(tokens.textPrimary).tabularNumbers()
      button("chevron-down", down) { value = (value - step + max) % max }
    }
  }

  private func button(_ icon: String, _ label: String, action: @escaping () -> Void) -> some View {
    Button {
      Haptics.impact(.light)
      action()
    } label: {
      Ionicon(icon, size: 20, color: tokens.inkMuted).frame(width: 38.5, height: 38.5).background(tokens.fill, in: .circle)
    }
    .buttonStyle(PressableStyle())
    .accessibilityLabel(label)
  }
}

/// Seçilen sesin 4 saniyelik önizlemesi.
@MainActor
enum AlarmSoundPreview {
  private static var player: AVAudioPlayer?
  private static var stopTask: Task<Void, Never>?

  static func play(_ sound: String) {
    stop()
    let file = sound == "adhan" ? "notif_ezan" : AlarmPlan.toneSounds[sound].map { String($0.dropLast(4)) }
    guard let file, let url = Bundle.main.url(forResource: file, withExtension: "caf") else { return }
    try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
    player = try? AVAudioPlayer(contentsOf: url)
    player?.play()
    stopTask = Task {
      try? await Task.sleep(for: .seconds(4))
      stop()
    }
  }

  static func stop() {
    stopTask?.cancel()
    stopTask = nil
    player?.stop()
    player = nil
  }
}

/// Ana sayfadaki vakit kutusuna dokununca açılan hızlı alarm menüsü. RN: alarm.actions `openPrayerAlarmMenu`.
enum AlarmQuickMenu {
  static func open(_ key: String, openAlarms: @escaping () -> Void) {
    Haptics.impact(.light)
    let store = AlarmStore.shared
    let setting = store.settings.prayers[key] ?? .init(enabled: false, offset: 0)
    let on = setting.enabled && store.authorized
    let prayer = prayerLabel(key)
    // Üç düğme alt alta: asıl eylem üstte, vazgeç en altta.
    let primary: AppAlert.Button =
      on
      ? .init(text: t("alarm.quick.turnOff"), style: .destructive) {
        await store.setPrayer(key, enabled: false)
        Haptics.impact(.medium)
      }
      : .init(text: t("alarm.quick.turnOn", ["when": AlarmText.offset(setting.offset)])) {
        if await store.setPrayer(key, enabled: true) { Haptics.notify(.success) }
      }
    AppAlert.show(
      .confirm, t("alarm.quick.title", ["prayer": prayer]),
      on ? t("alarm.quick.activeMessage", ["when": AlarmText.offset(setting.offset)]) : t("alarm.quick.message"),
      buttons: [primary, .init(text: t("alarm.quick.more")) { openAlarms() }, .init(text: t("common.cancel"), style: .cancel)])
  }
}

/// Ana sayfa alarm kısayolu: sıradaki alarm ve açık vakitler; yoksa tek dokunuşla sabah alarmı.
/// RN: components/home/AlarmsCard.tsx
struct AlarmsCard: View {
  @Environment(\.tokens) private var tokens
  let onOpen: () -> Void

  var body: some View {
    let store = AlarmStore.shared
    let s = store.settings
    let dark = tokens.isDark
    let next = store.authorized ? store.next : nil
    let chips: [String] = {
      var out = AlarmPlan.prayerKeys.filter { s.prayers[$0]?.enabled == true }.map { prayerLabel($0) }
      if s.tahajjud.enabled { out.append(t("alarm.tahajjud.label")) }
      if s.sahur.enabled { out.append(t("alarm.sahur.label")) }
      let custom = s.custom.filter(\.enabled).count
      if custom > 0 { out.append(t("alarmCard.custom", ["count": custom])) }
      return out
    }()

    if store.supported {
      Card {
        Button {
          Haptics.impact(.light)
          onOpen()
        } label: {
          HStack(spacing: 10.5) {
            Ionicon(next == nil ? "alarm-outline" : "alarm", size: 20, color: tokens.gold)
              .frame(width: 38.5, height: 38.5)
              .background(dark ? Gold.s700.opacity(0.2) : Gold.s50, in: .circle)
            VStack(alignment: .leading, spacing: 1.75) {
              if let next {
                Text(t("alarm.screen.next")).font(.system(size: 13)).foregroundStyle(tokens.textSecondary)
                Text(AlarmText.nextAlarm(next.fireAt, longDate: false)).font(.system(size: 17, weight: .semibold)).foregroundStyle(tokens.textPrimary).tabularNumbers()
                Text(next.title).font(.system(size: 13)).foregroundStyle(tokens.textSecondary).lineLimit(1)
              } else {
                Text(t("alarm.screen.title")).font(.system(size: 17, weight: .semibold)).foregroundStyle(tokens.textPrimary)
                Text(t("alarmCard.empty")).font(.system(size: 13)).foregroundStyle(tokens.textSecondary)
              }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Ionicon(dirIcon("chevron-forward"), size: 18, color: tokens.inkSubtle)
          }
          .contentShape(.rect)
        }
        .buttonStyle(PressableStyle())

        if next != nil, !chips.isEmpty {
          FlowLayout(spacing: 7) {
            ForEach(chips, id: \.self) { c in
              Text(c)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(dark ? Accent.s200 : Accent.s700)
                .padding(.horizontal, 10.5)
                .padding(.vertical, 5.25)
                .background(dark ? Accent.s900 : Accent.s50, in: .capsule)
            }
          }
          .padding(.top, 14)
        } else if next == nil {
          if s.prayers["imsak"]?.enabled == true {
            AppButton(title: t("alarmCard.manage"), variant: .secondary, action: onOpen).padding(.top, 14)
          } else {
            AppButton(title: t("alarmCard.setFajr")) {
              Haptics.impact(.medium)
              Task {
                if await store.setPrayer("imsak", enabled: true) {
                  Haptics.notify(.success)
                  Toast.success(t("alarmCard.setDone"), t("alarmCard.setDoneMessage", ["when": AlarmText.offset(store.settings.prayers["imsak"]?.offset ?? 0)]))
                }
              }
            }
            .padding(.top, 14)
          }
        }
      }
      .padding(.horizontal, 14)
      .padding(.bottom, 10.5)
    }
  }
}
