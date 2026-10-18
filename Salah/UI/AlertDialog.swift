import SwiftUI

/// Uygulamanın uyarı ve onay pencereleri. iOS'un standart `.alert`'i yerine
/// HER ZAMAN bu kullanılır (CLAUDE.md kural 1'in Swift karşılığı).
/// RN: store/alert.store.ts + components/feedback/AlertDialog.tsx
///
///     AppAlert.error(t("common.error"), t("tracker.errors.saveFailed"))
///     AppAlert.confirm(t("tracker.delete.title"), t("tracker.delete.message"),
///                      confirmText: t("tracker.delete.confirm"), destructive: true) { … }
enum AppAlert {
  enum Kind { case success, error, warning, info, confirm }

  struct Button {
    enum Style { case `default`, cancel, destructive }
    var text: String
    var style: Style = .default
    var action: (() async -> Void)?
  }

  static func success(_ title: String, _ message: String? = nil) { simple(.success, title, message) }
  static func error(_ title: String, _ message: String? = nil) { simple(.error, title, message) }
  static func warning(_ title: String, _ message: String? = nil) { simple(.warning, title, message) }
  static func info(_ title: String, _ message: String? = nil) { simple(.info, title, message) }

  static func confirm(
    _ title: String,
    _ message: String,
    confirmText: String = t("common.yes"),
    cancelText: String = t("common.cancel"),
    destructive: Bool = false,
    onConfirm: @escaping () async -> Void
  ) {
    show(.confirm, title, message, buttons: [
      Button(text: cancelText, style: .cancel),
      Button(text: confirmText, style: destructive ? .destructive : .default, action: onConfirm),
    ])
  }

  static func show(_ kind: Kind, _ title: String, _ message: String?, buttons: [Button]) {
    AlertCenter.shared.present(.init(kind: kind, title: title, message: message, buttons: buttons))
  }

  private static func simple(_ kind: Kind, _ title: String, _ message: String?) {
    show(kind, title, message, buttons: [Button(text: t("common.ok"))])
  }
}

@Observable
final class AlertCenter {
  static let shared = AlertCenter()

  struct Item: Identifiable {
    let id = UUID()
    let kind: AppAlert.Kind
    let title: String
    let message: String?
    let buttons: [AppAlert.Button]
  }

  private(set) var current: Item?
  @ObservationIgnored private lazy var window = OverlayWindow(level: .alert) { AlertDialogHost() }

  func present(_ item: Item) {
    current = item
    window.show()
  }

  /// `id` verilirse yalnız o pencere hâlâ görünüyorsa kapatır: bir düğme işlemi
  /// içinden açılan yeni pencere (ör. ikinci onay) kapanmaz.
  func dismiss(_ id: UUID? = nil) {
    if let id, current?.id != id { return }
    current = nil
    window.hide()
  }
}

private struct AlertDialogHost: View {
  var body: some View {
    if let item = AlertCenter.shared.current {
      AlertDialogView(item: item).id(item.id)
    }
  }
}

private struct AlertDialogView: View {
  @Environment(\.tokens) private var tokens
  let item: AlertCenter.Item
  @State private var shown = false

  var body: some View {
    ZStack {
      Color.black.opacity(0.5).ignoresSafeArea()
        .onTapGesture { AlertCenter.shared.dismiss() }
        .accessibilityLabel(t("common.close"))

      VStack(spacing: 0) {
        Ionicon(icon.name, size: 24, color: icon.color)
          .frame(width: 42, height: 42)
          .background(icon.circle, in: .circle)
          .padding(.bottom, 14)

        Text(item.title)
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(tokens.textPrimary)
          .multilineTextAlignment(.center)
          .padding(.bottom, 5.25)
          .accessibilityAddTraits(.isHeader)

        if let message = item.message, !message.isEmpty {
          Text(message)
            .font(.system(size: 15))
            .lineSpacing(4)
            .foregroundStyle(tokens.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.bottom, 21)
        } else {
          Spacer().frame(height: 17.5)
        }

        let layout = item.buttons.count > 2 ? AnyLayout(VStackLayout(spacing: 10.5)) : AnyLayout(HStackLayout(spacing: 10.5))
        layout {
          ForEach(Array(item.buttons.enumerated()), id: \.offset) { _, button in
            buttonView(button)
          }
        }
      }
      .padding(21)
      .frame(maxWidth: 340)
      .background(tokens.surface, in: .rect(cornerRadius: 21))
      .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
      .padding(.horizontal, 28)
      .scaleEffect(shown ? 1 : 0.94)
      .opacity(shown ? 1 : 0)
      .accessibilityAddTraits(.isModal)
    }
    .onAppear {
      withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { shown = true }
    }
  }

  private func buttonView(_ button: AppAlert.Button) -> some View {
    let (bg, fg): (Color, Color) =
      switch button.style {
      case .cancel: (tokens.fill, tokens.textPrimary)
      case .destructive: (tokens.isDark ? Color(hex: 0xef4444) : Color(hex: 0xdc2626), .white)
      case .default: (tokens.accent, tokens.onAccent)
      }
    return SwiftUI.Button {
      Task {
        await button.action?()
        AlertCenter.shared.dismiss(item.id)
      }
    } label: {
      Text(button.text)
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(fg)
        .lineLimit(1)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 42)
        .background(bg, in: .capsule)
    }
    .buttonStyle(PressableStyle())
  }

  private var icon: (name: String, circle: Color, color: Color) {
    switch item.kind {
    case .success: ("checkmark", tokens.isDark ? Accent.s900 : Accent.s50, tokens.accent)
    case .error: ("close", tokens.isDark ? Color(hex: 0xef4444).opacity(0.15) : Color(hex: 0xfef2f2), tokens.danger)
    case .warning: ("alert", tokens.isDark ? Amber.s500.opacity(0.15) : Color(hex: 0xfffbeb), tokens.isDark ? Amber.s400 : Amber.s600)
    case .confirm: ("help", tokens.fill, tokens.inkMuted)
    case .info: ("information", tokens.fill, tokens.inkMuted)
    }
  }
}
