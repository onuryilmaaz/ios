import SwiftUI

/// Uygulama rengi seçimi. Ramazan'da renk saate göre kendiliğinden değişir; seçim yine kaydedilir.
struct AppColorPicker: View {
  @Environment(\.tokens) private var tokens

  var body: some View {
    let store = AppColorStore.shared
    VStack(alignment: .leading, spacing: 0) {
      SectionLabel(t("appColor.title")).padding(.leading, 10.5)
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          ForEach(Array(AppColor.allCases.enumerated()), id: \.element) { i, color in
            if i > 0 { Spacer(minLength: 0) }
            swatch(color, selected: color == store.choice)
          }
        }
        Text(t("appColor.ramadanHint"))
          .font(.system(size: 13))
          .foregroundStyle(tokens.textSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(14)
      .background(tokens.surface, in: .rect(cornerRadius: 21))
      .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
      .padding(.bottom, 21)
    }
  }

  private func swatch(_ color: AppColor, selected: Bool) -> some View {
    let scale = color.scales.accent
    return Button {
      guard !selected else { return }
      Haptics.impact(.light)
      AppColorStore.shared.set(color)
    } label: {
      VStack(spacing: 7) {
        ZStack {
          Circle().fill(Color(hex: scale[9]))
          Circle().fill(Color(hex: scale[4])).frame(width: 18, height: 18).opacity(selected ? 0 : 1)
          if selected { Ionicon("checkmark", size: 20, color: Gold.s300) }
        }
        .frame(width: 45, height: 45)
        .padding(3)
        .overlay(Circle().stroke(selected ? Gold.s400 : .clear, lineWidth: 2))
        Text(t("appColor.\(color.rawValue)"))
          .font(.system(size: 12, weight: selected ? .semibold : .regular))
          .foregroundStyle(selected ? tokens.textPrimary : tokens.textSecondary)
      }
    }
    .buttonStyle(PressableStyle())
    .accessibilityLabel(t("appColor.\(color.rawValue)"))
    .accessibilityAddTraits(selected ? .isSelected : [])
  }
}
