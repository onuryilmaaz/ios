import SwiftUI

/// Tek ince kartta dört kısayol. RN: components/home/QuickActionsGrid.tsx
struct QuickActionsCard: View {
  @Environment(\.tokens) private var tokens
  let onSelect: (HomeRoute) -> Void

  private static let actions: [(key: String, icon: String, route: HomeRoute)] = [
    ("dua", "hand-left-outline", .dua),
    ("calendar", "moon-outline", .calendar),
    ("esma", "sparkles-outline", .esma),
    ("history", "calendar-outline", .history),
  ]

  var body: some View {
    HStack(alignment: .top, spacing: 0) {
      ForEach(Self.actions, id: \.key) { action in
        Button {
          Haptics.impact(.light)
          onSelect(action.route)
        } label: {
          VStack(spacing: 7) {
            Ionicon(action.icon, size: 22, color: tokens.accent)
              .frame(width: 42, height: 42)
              .background(tokens.isDark ? Accent.s900 : Accent.s50, in: .circle)
            Text(t("home.quick.short.\(action.key)"))
              .font(.system(size: 13, weight: .medium))
              .foregroundStyle(tokens.isDark ? Forest.s300 : Forest.s700)
              .multilineTextAlignment(.center)
              .lineLimit(2)
              .padding(.horizontal, 3.5)
          }
          .frame(maxWidth: .infinity)
        }
        .buttonStyle(PressableStyle(pressedOpacity: 0.6))
        .accessibilityLabel(t("home.quick.\(action.key)"))
      }
    }
    .padding(.horizontal, 7)
    .padding(.vertical, 14)
    .background(tokens.surface, in: .rect(cornerRadius: 21))
    .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
    .padding(.horizontal, 14)
    .padding(.bottom, 10.5)
  }
}
