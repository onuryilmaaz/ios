import SwiftUI

/// Zikirmatik: namaz sonrası tesbihat (33/33/33 ve tehlil) ya da seçilen zikir ve hedef. Büyük daireye dokundukça sayar;
/// ekran açıkken kilitlenmez.
struct DhikrView: View {
  @Environment(\.tokens) private var tokens

  var body: some View {
    let store = DhikrStore.shared
    VStack(spacing: 0) {
      StandardHeader(title: t("dhikr.title"))
      ScrollView {
        VStack(spacing: 16) {
          modePicker(store)
          if store.mode == .free { freeOptions(store) }
          textCard(store.current.item)
          if store.mode == .tesbihat { steps(store) }
          if store.mode == .tesbihat && store.tesbihat.done {
            finished(store)
          } else {
            DhikrCounter(count: store.current.count, target: store.current.target)
          }
          controls(store)
        }
        .padding(16).padding(.bottom, 84)
      }
      .scrollIndicators(.hidden)
    }
    .background(tokens.canvas)
    .toolbar(.hidden, for: .navigationBar)
    .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
    .onDisappear {
      UIApplication.shared.isIdleTimerDisabled = false
      DhikrStore.shared.syncWidget()
    }
    .onAppear { DhikrStore.shared.reload() }
  }

  private func modePicker(_ store: DhikrStore) -> some View {
    HStack(spacing: 4) {
      ForEach([DhikrStore.Mode.tesbihat, .free], id: \.self) { mode in
        let selected = store.mode == mode
        Button {
          guard !selected else { return }
          Haptics.impact(.light)
          store.setMode(mode)
        } label: {
          Text(t("dhikr.mode.\(mode.rawValue)"))
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(selected ? .white : tokens.textSecondary)
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(selected ? (tokens.isDark ? Accent.s500 : Accent.s600) : .clear, in: .capsule)
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
      }
    }
    .padding(4)
    .background(tokens.surface, in: .capsule)
    .overlay(Capsule().stroke(tokens.line, lineWidth: 1))
  }

  private func freeOptions(_ store: DhikrStore) -> some View {
    VStack(alignment: .leading, spacing: 10.5) {
      ScrollView(.horizontal) {
        HStack(spacing: 7) {
          ForEach(DhikrItem.all) { item in
            chip(t("dhikr.items.\(item.id).name"), selected: store.item.id == item.id) { store.select(item.id) }
          }
        }
      }.scrollIndicators(.hidden)
      ScrollView(.horizontal) {
        HStack(spacing: 7) {
          Text(t("dhikr.target")).font(.system(size: 13, weight: .medium)).foregroundStyle(tokens.textSecondary)
          ForEach(DhikrPlan.targets, id: \.self) { value in
            chip(value == 0 ? t("dhikr.noTarget") : "\(value)", selected: store.target == value) { store.setTarget(value) }
          }
        }
      }.scrollIndicators(.hidden)
    }
  }

  private func chip(_ text: String, selected: Bool, action: @escaping () -> Void) -> some View {
    Button { Haptics.impact(.light); action() } label: {
      Text(text).font(.system(size: 13, weight: .semibold)).tabularNumbers()
        .foregroundStyle(selected ? tokens.accent : tokens.textSecondary)
        .padding(.horizontal, 12.25).padding(.vertical, 7)
        .background(selected ? tokens.accentSoft : tokens.surface, in: .capsule)
        .overlay(Capsule().stroke(selected ? tokens.accent : tokens.line, lineWidth: 1))
    }
    .buttonStyle(PressableStyle())
    .accessibilityAddTraits(selected ? .isSelected : [])
  }

  private func textCard(_ item: DhikrItem) -> some View {
    VStack(spacing: 10.5) {
      Text(QuranFont.text(item.arabic))
        .font(.custom(QuranFont.name, size: item.arabic.count > 40 ? 24 : 32))
        .foregroundStyle(tokens.textPrimary)
        .multilineTextAlignment(.center)
        .lineSpacing(10)
        .environment(\.layoutDirection, .rightToLeft)
      // Arapça arayüzde okunuş gösterilmez (metnin kendisi).
      let reading = t("dhikr.items.\(item.id).reading")
      if !reading.isEmpty {
        Text(reading).font(.system(size: 15, weight: .semibold)).foregroundStyle(tokens.accent).multilineTextAlignment(.center)
      }
      Text(t("dhikr.items.\(item.id).meaning"))
        .font(.system(size: 13)).foregroundStyle(tokens.textSecondary).multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(17.5)
    .background(tokens.surface, in: .rect(cornerRadius: 21))
    .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
  }

  /// Tesbihat adımları: her adımın doluluğu.
  private func steps(_ store: DhikrStore) -> some View {
    let s = store.tesbihat
    return HStack(spacing: 7) {
      ForEach(Array(DhikrPlan.tesbihat.enumerated()), id: \.offset) { i, step in
        let fill = s.done || i < s.step ? 1 : i == s.step ? Double(s.count) / Double(step.target) : 0
        VStack(spacing: 5.25) {
          GeometryReader { g in
            ZStack(alignment: .leading) {
              Capsule().fill(tokens.fill)
              Capsule().fill(tokens.accent).frame(width: g.size.width * fill)
            }
          }.frame(height: 5.25).environment(\.layoutDirection, .leftToRight)
          Text(t("dhikr.items.\(step.id).short"))
            .font(.system(size: 11, weight: i == s.step && !s.done ? .semibold : .regular))
            .foregroundStyle(i == s.step && !s.done ? tokens.textPrimary : tokens.textSecondary)
            .lineLimit(1).minimumScaleFactor(0.8)
        }
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(t("dhikr.stepA11y", ["step": min(s.step + 1, DhikrPlan.tesbihat.count), "total": DhikrPlan.tesbihat.count]))
  }

  private func finished(_ store: DhikrStore) -> some View {
    VStack(spacing: 12) {
      Ionicon("checkmark-circle", size: 44, color: Gold.s300)
      Text(t("dhikr.finished")).font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
      Text(t("dhikr.finishedHint")).font(.system(size: 14)).foregroundStyle(.white.opacity(0.85)).multilineTextAlignment(.center)
      Button {
        Haptics.impact(.medium)
        store.reset()
      } label: {
        Text(t("dhikr.again")).font(.system(size: 15, weight: .semibold)).foregroundStyle(Accent.s900)
          .padding(.horizontal, 24).padding(.vertical, 12).background(.white, in: .capsule)
      }.buttonStyle(PressableStyle())
    }
    .frame(maxWidth: .infinity).padding(24)
    .background(Accent.s800, in: .rect(cornerRadius: 24))
  }

  private func controls(_ store: DhikrStore) -> some View {
    HStack(spacing: 12) {
      circleButton("arrow-undo", label: t("dhikr.undo"), enabled: store.current.count > 0 && !(store.mode == .tesbihat && store.tesbihat.done)) {
        Haptics.impact(.light)
        store.undo()
      }
      VStack(spacing: 1.75) {
        Text("\(store.today)").font(.system(size: 17, weight: .semibold)).foregroundStyle(tokens.textPrimary).tabularNumbers()
        Text(t("dhikr.today")).font(.system(size: 12)).foregroundStyle(tokens.textSecondary)
      }
      .frame(maxWidth: .infinity)
      .accessibilityElement(children: .combine)
      circleButton("refresh", label: t("dhikr.reset"), enabled: store.current.count > 0 || (store.mode == .tesbihat && store.tesbihat.step > 0)) {
        Haptics.impact(.light)
        AppAlert.confirm(t("dhikr.resetTitle"), t("dhikr.resetMessage"), confirmText: t("dhikr.reset"), destructive: true) { store.reset() }
      }
    }
  }

  private func circleButton(_ icon: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Ionicon(icon, size: 20, color: tokens.inkMuted)
        .frame(width: 48, height: 48)
        .background(tokens.surface, in: .circle)
        .overlay(Circle().stroke(tokens.line, lineWidth: 1))
    }
    .buttonStyle(PressableStyle())
    .disabled(!enabled).opacity(enabled ? 1 : 0.4)
    .accessibilityLabel(label)
  }
}

/// Büyük sayaç dairesi: halka hedefe göre dolar, dokunuş sayar. Hedefte bildirim titreşimi.
private struct DhikrCounter: View {
  @Environment(\.tokens) private var tokens
  let count: Int
  let target: Int
  @State private var pulse = false

  var body: some View {
    let progress = target > 0 ? Double(count % target == 0 && count > 0 ? target : count % target) / Double(target) : 0
    Button {
      let event = DhikrStore.shared.tap()
      switch event {
      case .counted: Haptics.impact(.light)
      case .stepDone: Haptics.notify(.success)
      case .finished: Haptics.notify(.success)
      }
      pulse.toggle()
    } label: {
      ZStack {
        Circle().fill(tokens.isDark ? Accent.s900 : Accent.s50)
        Circle().stroke(tokens.fill, lineWidth: 10).padding(5)
        Circle().trim(from: 0, to: progress)
          .stroke(tokens.isDark ? Accent.s400 : Accent.s600, style: StrokeStyle(lineWidth: 10, lineCap: .round))
          .rotationEffect(.degrees(-90)).padding(5)
          .animation(.easeOut(duration: 0.15), value: progress)
        VStack(spacing: 3.5) {
          Text("\(count)")
            .font(.system(size: 64, weight: .bold)).foregroundStyle(tokens.textPrimary).tabularNumbers()
            .contentTransition(.numericText())
            .animation(.snappy(duration: 0.15), value: count)
          Text(target > 0 ? "/ \(target)" : t("dhikr.tapToCount"))
            .font(.system(size: 15, weight: .medium)).foregroundStyle(tokens.textSecondary).tabularNumbers()
        }
      }
      .frame(width: 260, height: 260)
      .scaleEffect(pulse ? 0.985 : 1)
      .animation(.easeOut(duration: 0.08), value: pulse)
      .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .frame(maxWidth: .infinity)
    .accessibilityLabel(t("dhikr.counterA11y", ["count": count, "target": target > 0 ? "\(target)" : "-"]))
    .accessibilityHint(t("dhikr.tapToCount"))
  }
}

/// Ana sayfa kartı: bugünkü zikir ve zikirmatiğe geçiş.
struct DhikrCard: View {
  @Environment(\.tokens) private var tokens
  let onOpen: () -> Void

  var body: some View {
    let store = DhikrStore.shared
    Button { Haptics.impact(.light); onOpen() } label: {
      HStack(spacing: 10.5) {
        Ionicon("finger-print-outline", size: 22, color: tokens.accent)
          .frame(width: 42, height: 42)
          .background(tokens.accentSoft, in: .circle)
        VStack(alignment: .leading, spacing: 1.75) {
          Text(t("dhikr.title")).font(.system(size: 13)).foregroundStyle(tokens.textSecondary)
          Text(store.today > 0 ? t("dhikr.cardToday", ["count": store.today]) : t("dhikr.cardStart"))
            .font(.system(size: 16, weight: .semibold)).foregroundStyle(tokens.textPrimary).tabularNumbers()
        }.frame(maxWidth: .infinity, alignment: .leading)
        Ionicon(dirIcon("chevron-forward"), size: 18, color: tokens.inkSubtle)
      }
      .padding(17.5)
      .background(tokens.surface, in: .rect(cornerRadius: 21))
      .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
    }
    .buttonStyle(PressableStyle())
    .padding(.horizontal, 14).padding(.bottom, 10.5)
  }
}
