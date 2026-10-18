import SwiftUI
import UIKit

/// Durum çubuğu yazı rengi. Varsayılan temaya göre (koyu temada açık yazı);
/// koyu zümrüt başlıklı ekranlar (Ana Sayfa, Giriş) temadan bağımsız açık yazı ister.
/// RN'deki `StatusBar.pushStackEntry` gibi: görünür ekranlar bir yığına kaydolur,
/// en son görünenin isteği geçerlidir.
///
/// Info.plist `UIViewControllerBasedStatusBarAppearance = NO` (RN sürümüyle aynı).
@MainActor
enum StatusBarStyle {
  enum Request: Equatable { case light, dark, auto }

  private static var stack: [(id: UUID, request: Request, priority: Int)] = []

  static func push(_ id: UUID, _ request: Request, priority: Int = 0) {
    stack.removeAll { $0.id == id }
    stack.append((id, request, priority))
    apply()
  }

  static func pop(_ id: UUID) {
    stack.removeAll { $0.id == id }
    apply()
  }

  /// Tema değişince de çağrılır.
  static func apply() {
    // Splash alttaki ekranla aynı anda yerleşir; onAppear sırası stilini bozmamalı.
    let priority = stack.map(\.priority).max() ?? 0
    let request = stack.last(where: { $0.priority == priority })?.request ?? .auto
    let light = request == .light || (request == .auto && ThemeStore.shared.isDark)
    setter.setStatusBarStyle(light ? .lightContent : .darkContent, animated: true)
  }

  // `UIApplication.setStatusBarStyle` (VC tabanlı görünüm kapalıyken genel stil)
  // iOS 9'dan beri "deprecated" işaretli ama çalışır ve RN de bunu kullanır;
  // uyarı üretmesin diye Obj-C protokolü üzerinden çağrılır.
  @objc private protocol Setter {
    func setStatusBarStyle(_ style: UIStatusBarStyle, animated: Bool)
  }

  private static var setter: Setter { unsafeBitCast(UIApplication.shared, to: Setter.self) }
}

private struct StatusBarModifier: ViewModifier {
  let request: StatusBarStyle.Request
  let priority: Int
  @State private var id = UUID()

  func body(content: Content) -> some View {
    content
      .onAppear { StatusBarStyle.push(id, request, priority: priority) }
      .onChange(of: request) { StatusBarStyle.push(id, request, priority: priority) }
      .onDisappear { StatusBarStyle.pop(id) }
  }
}

extension View {
  /// Bu ekran görünürken durum çubuğu stili.
  func statusBar(_ request: StatusBarStyle.Request, priority: Int = 0) -> some View {
    modifier(StatusBarModifier(request: request, priority: priority))
  }
}
