import SwiftUI

/// Ana sayfa kartlarının sırası ve görünürlüğü. RN: screens/user/HomeLayoutScreen.tsx
struct HomeLayoutView: View {
  @Environment(\.tokens) private var tokens

  var body: some View {
    let store = HomeLayoutStore.shared
    VStack(spacing: 0) {
      StandardHeader(title: t("homeLayout.title")) {
        CircleIconButton(icon: "refresh", accessibilityLabel: t("homeLayout.resetA11y")) {
          AppAlert.confirm(
            t("homeLayout.resetTitle"), t("homeLayout.resetMessage"),
            confirmText: t("homeLayout.reset"), cancelText: t("common.cancel")
          ) {
            Haptics.impact(.medium)
            withAnimation { HomeLayoutStore.shared.reset() }
          }
        }
      }
      ScrollView {
        VStack(spacing: 12) {
          HStack(alignment: .top, spacing: 7) {
            Ionicon("information-circle-outline", size: 18, color: tokens.accent)
            Text(t("homeLayout.info"))
              .font(.system(size: 10.5))
              .lineSpacing(4)
              .foregroundStyle(tokens.isDark ? Forest.s300 : Forest.s600)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          .padding(10.5)
          .background(tokens.isDark ? Accent.s500.opacity(0.1) : Accent.s50, in: .rect(cornerRadius: 14))
          .padding(.bottom, 3.5)

          ForEach(Array(store.sections.enumerated()), id: \.element.key) { index, section in
            row(section, isFirst: index == 0, isLast: index == store.sections.count - 1)
          }
        }
        .padding(16)
        .padding(.bottom, 24)
      }
      .scrollIndicators(.hidden)
    }
    .background(tokens.canvas)
    .toolbar(.hidden, for: .navigationBar)
  }

  private func row(_ section: HomeLayoutStore.Section, isFirst: Bool, isLast: Bool) -> some View {
    let store = HomeLayoutStore.shared
    let label = t(section.key.labelKey)
    let muted = tokens.isDark ? Forest.s600 : Forest.s400
    let arrowColor = tokens.isDark ? Forest.s300 : Forest.s600

    return HStack(spacing: 10.5) {
      Ionicon(section.key.icon, size: 20, color: section.visible ? tokens.accent : muted)
        .frame(width: 38.5, height: 38.5)
        .background(section.visible ? tokens.accent.opacity(0.1) : .clear, in: .rect(cornerRadius: 14))

      VStack(alignment: .leading, spacing: 0) {
        Text(label)
          .font(.system(size: 12.25, weight: .semibold))
          .foregroundStyle(tokens.isDark ? .white : Forest.s900)
        Text(t(section.key.descriptionKey))
          .font(.system(size: 10.5))
          .foregroundStyle(tokens.textSecondary)
          .lineLimit(1)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      HStack(spacing: 3.5) {
        arrow("chevron-up", color: arrowColor, disabled: isFirst, a11y: t("homeLayout.moveUp", ["label": label])) {
          withAnimation { store.move(section.key, by: -1) }
        }
        arrow("chevron-down", color: arrowColor, disabled: isLast, a11y: t("homeLayout.moveDown", ["label": label])) {
          withAnimation { store.move(section.key, by: 1) }
        }
      }

      Toggle(
        "",
        isOn: Binding(
          get: { section.visible },
          set: { _ in
            Haptics.impact(.light)
            store.toggle(section.key)
          })
      )
      .labelsHidden()
      .tint(tokens.accent)
      .accessibilityLabel(t("homeLayout.toggleA11y", ["label": label]))
    }
    .padding(12.25)
    .background(tokens.surface, in: .rect(cornerRadius: 21))
    .overlay(
      RoundedRectangle(cornerRadius: 21)
        .stroke(tokens.line, style: StrokeStyle(lineWidth: 1, dash: section.visible ? [] : [4, 3]))
    )
    .opacity(section.visible ? 1 : 0.6)
  }

  private func arrow(_ icon: String, color: Color, disabled: Bool, a11y: String, action: @escaping () -> Void) -> some View {
    Button {
      Haptics.impact(.light)
      action()
    } label: {
      Ionicon(icon, size: 18, color: color)
        .frame(width: 31.5, height: 31.5)
        .background(tokens.fill, in: .rect(cornerRadius: 10.5))
    }
    .buttonStyle(PressableStyle())
    .disabled(disabled)
    .opacity(disabled ? 0.35 : 1)
    .accessibilityLabel(a11y)
  }
}
