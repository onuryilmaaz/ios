import SwiftUI
import UIKit

/// Geniş ekran (iPhone Duo açıkken 669/951 pt) düzeni. Telefonlarda (≤ 440 pt) hiçbir şey değişmez.
/// Saf ölçüler ana aktöre bağlı değildir (geometri dönüşümlerinde de kullanılır).
nonisolated enum ReadableLayout {
  /// İçerik sütununun en fazla genişliği; yanlar zemin rengiyle dolar.
  static let columnWidth: CGFloat = 620
  /// Ana sayfa bu genişlikten itibaren yatayda ikiye bölünür (solda vakit paneli, sağda kartlar).
  static let splitMinWidth: CGFloat = 800
  /// Sol vakit panelinin genişliği.
  static let splitPanelWidth: CGFloat = 400
  /// Kısa kenarı bundan büyük pencere (Duo iç ekranı) yatay da döner; kapak ekranı (466 pt) ve telefonlar dikey kalır.
  static let rotatableMinSide: CGFloat = 600

  /// Telefon yatayı (yükseklik ~400 pt) sayılmaz; yalnız Duo iç ekranı yatayken.
  static func isSplit(_ size: CGSize) -> Bool { size.width >= splitMinWidth && size.height >= 500 && size.width > size.height }

  /// Uygulama temsilcisinin yön maskesi: Mushaf kendi maskesini koyar, yoksa iç ekranda yatay da serbest.
  @MainActor static func orientations(for window: UIWindow?) -> UIInterfaceOrientationMask {
    if ReadingOrientation.mask != .portrait { return ReadingOrientation.mask }
    guard let bounds = window?.windowScene?.screen.bounds else { return .portrait }
    return min(bounds.width, bounds.height) >= rotatableMinSide ? .allButUpsideDown : .portrait
  }
}

extension View {
  /// İçeriği okunur genişlikte ortalar (zemin çizmez).
  func readableColumn() -> some View {
    frame(maxWidth: ReadableLayout.columnWidth).frame(maxWidth: .infinity)
  }

  /// Bütün ekranı okunur sütuna alır; yanlarda uygulama zemini görünür.
  func readableScreen() -> some View { modifier(ReadableScreen()) }
}

private struct ReadableScreen: ViewModifier {
  @Environment(\.tokens) private var tokens

  func body(content: Content) -> some View {
    content.readableColumn().background(tokens.canvas.ignoresSafeArea())
  }
}
