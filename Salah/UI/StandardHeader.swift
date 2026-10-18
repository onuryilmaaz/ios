import SwiftUI

/// RN `<StandardHeader>`. Geri düğmeli (ortalı 17 pt başlık) ya da sekme kökü
/// (`showBackButton: false`, sola hizalı 28 pt başlık) düzeni.
struct StandardHeader<Right: View>: View {
  @Environment(\.tokens) private var tokens
  @Environment(\.dismiss) private var dismiss

  let title: String
  var showBackButton = true
  @ViewBuilder var right: Right

  var body: some View {
    Group {
      if showBackButton {
        HStack {
          Button {
            Haptics.impact(.light)
            dismiss()
          } label: {
            Ionicon(dirIcon("chevron-back"), size: 20, color: tokens.ink)
              .frame(width: 35, height: 35)
              .background(tokens.surface, in: .circle)
              .overlay(Circle().stroke(tokens.line, lineWidth: 1))
          }
          .buttonStyle(PressableStyle())
          .accessibilityLabel(t("common.back"))
          .frame(width: 84, alignment: .leading)

          Text(title)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(tokens.textPrimary)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .accessibilityAddTraits(.isHeader)

          // EmptyView, frame verilse de HStack'ten çıkar. Açık bir yer tutucu
          // iki yanda eşit alan bırakır; başlık düğme yokken de merkezde kalır.
          Color.clear.frame(width: 84)
            .overlay(alignment: .trailing) { right }
        }
      } else {
        HStack {
          Text(title)
            .font(.system(size: 28, weight: .bold))
            .tracking(-0.5)
            .foregroundStyle(tokens.textPrimary)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
          right
        }
      }
    }
    .padding(.horizontal, 16)
    .frame(height: 56)
    .background(tokens.canvas)
  }
}

extension StandardHeader where Right == EmptyView {
  init(title: String, showBackButton: Bool = true) {
    self.init(title: title, showBackButton: showBackButton) { EmptyView() }
  }
}

/// Yuvarlak, kenarlıklı ikon düğmesi (başlığın sağ tarafı vb.).
struct CircleIconButton: View {
  @Environment(\.tokens) private var tokens
  let icon: String
  var size: CGFloat = 38.5
  var iconSize: CGFloat = 18
  var color: Color?
  let accessibilityLabel: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Ionicon(icon, size: iconSize, color: color ?? tokens.accent)
        .frame(width: size, height: size)
        .background(tokens.surface, in: .circle)
        .overlay(Circle().stroke(tokens.line, lineWidth: 1))
    }
    .buttonStyle(PressableStyle())
    .accessibilityLabel(accessibilityLabel)
  }
}
