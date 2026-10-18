import SwiftUI
import UIKit

/// Her şeyin (sheet ve tam ekran pencereler dahil) üstünde çizilen ayrı pencere.
/// RN'deki kök seviyede bağlı AlertDialog / Toast'un karşılığı.
final class OverlayWindow {
  private var window: UIWindow?
  private let level: UIWindow.Level
  private let content: () -> AnyView

  init<V: View>(level: UIWindow.Level, @ViewBuilder content: @escaping () -> V) {
    self.level = level
    self.content = { AnyView(content()) }
  }

  func show() {
    if window == nil {
      guard
        let scene = UIApplication.shared.connectedScenes
          .compactMap({ $0 as? UIWindowScene })
          .first(where: { $0.activationState == .foregroundActive }) ?? UIApplication.shared.connectedScenes.first as? UIWindowScene
      else { return }
      let host = UIHostingController(rootView: OverlayRoot(content: content))
      host.view.backgroundColor = .clear
      let w = UIWindow(windowScene: scene)
      w.windowLevel = level
      w.backgroundColor = .clear
      w.rootViewController = host
      window = w
    }
    window?.isHidden = false
  }

  func hide() {
    window?.isHidden = true
  }
}

/// Tema, dil ve yönü ana ağaçla aynı tutar.
private struct OverlayRoot: View {
  let content: () -> AnyView

  var body: some View {
    let theme = ThemeStore.shared
    let l10n = Localizer.shared
    content()
      .environment(\.tokens, theme.tokens)
      .environment(\.layoutDirection, l10n.layoutDirection)
      .environment(\.locale, l10n.locale)
      .preferredColorScheme(theme.isDark ? .dark : .light)
  }
}
