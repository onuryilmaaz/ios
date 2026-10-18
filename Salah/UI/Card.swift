import SwiftUI

/// RN `<Card>`: `rounded-3xl border border-slate-200 bg-white p-5` (21 / 17,5 pt;
/// NativeWind rem 14) `dark:border-slate-800 dark:bg-slate-900` (gölge yok).
struct Card<Content: View>: View {
  @Environment(\.tokens) private var tokens
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 0) { content }
      .padding(17.5)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(tokens.surface, in: .rect(cornerRadius: 21))
      .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
  }
}

extension View {
  /// `fontVariant: ['tabular-nums']`
  func tabularNumbers() -> some View { monospacedDigit() }
}

/// `TouchableOpacity activeOpacity` davranışı: basılıyken saydamlaşır.
struct PressableStyle: ButtonStyle {
  var pressedOpacity: Double = 0.7

  func makeBody(configuration: Configuration) -> some View {
    configuration.label.opacity(configuration.isPressed ? pressedOpacity : 1)
  }
}
