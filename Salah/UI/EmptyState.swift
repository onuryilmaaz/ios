import SwiftUI

/// Boş liste/veri alanı. RN: components/layout/EmptyState.tsx
struct EmptyState<Action: View>: View {
  @Environment(\.tokens) private var tokens
  var icon = "document-outline"
  let title: String
  var message: String?
  @ViewBuilder var action: Action

  var body: some View {
    VStack(spacing: 0) {
      Ionicon(icon, size: 26, color: tokens.inkMuted)
        .frame(width: 49, height: 49)
        .background(tokens.fill, in: .circle)
        .padding(.bottom, 14)
      Text(title)
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(tokens.textPrimary)
        .multilineTextAlignment(.center)
        .padding(.bottom, 3.5)
      if let message {
        Text(message)
          .font(.system(size: 12.25))
          .lineSpacing(3)
          .foregroundStyle(tokens.textSecondary)
          .multilineTextAlignment(.center)
          .frame(maxWidth: 280)
      }
      action.padding(.top, 17.5)
    }
    .padding(.horizontal, 21)
    .padding(.vertical, 42)
    .frame(maxWidth: .infinity)
  }
}

extension EmptyState where Action == EmptyView {
  init(icon: String = "document-outline", title: String, message: String? = nil) {
    self.init(icon: icon, title: title, message: message) { EmptyView() }
  }
}
