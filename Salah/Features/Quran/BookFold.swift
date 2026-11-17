import SwiftUI

/// Duo katlanınca/açılınca Mushaf açılımının ciltten kapanıp açılması: iki yarım sayfa, ortadaki cilt
/// çevresinde içe doğru döner. Açılışta katlı halden düzleşir, kapanışta (kapak ekranında) katlanıp kaybolur.
struct BookFold: View {
  struct Fold: Equatable {
    /// true: cihaz açıldı (kitap açılır), false: cihaz katlandı (kitap kapanır).
    let opening: Bool
    /// Açılımın sağdaki (tek) sayfası.
    let right: Int
    /// Yalnız Debug ekran görüntüsü: animasyon bu açıda durur.
    var frozenAngle: Double?
  }

  let fold: Fold
  let size: CGSize
  let page: (Int, CGSize) -> AnyView
  let done: () -> Void
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  /// 0: düz açık kitap, 65: neredeyse kapalı (daha büyük açıda dış kenar kameranın arkasına geçer).
  @State private var angle: Double = 0

  private static let closedAngle: Double = 65

  var body: some View {
    let half = CGSize(width: size.width / 2, height: size.height)
    HStack(spacing: 0) {
      // Sol (çift) sayfa sağ kenarı, sağ (tek) sayfa sol kenarı (cilt) çevresinde döner; dış kenarlar okura doğru kapanır.
      page(fold.right + 1, half)
        .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), anchor: .trailing, perspective: 0.45)
      page(fold.right, half)
        .rotation3DEffect(.degrees(-angle), axis: (x: 0, y: 1, z: 0), anchor: .leading, perspective: 0.45)
    }
    .environment(\.layoutDirection, .leftToRight)
    .frame(width: size.width, height: size.height)
    .background(Forest.s950)
    .allowsHitTesting(false)
    .onAppear {
      if let frozen = fold.frozenAngle {
        angle = frozen
        return
      }
      guard !reduceMotion else { return done() }
      angle = fold.opening ? Self.closedAngle : 0
      withAnimation(.easeInOut(duration: 0.75)) {
        angle = fold.opening ? 0 : Self.closedAngle
      } completion: {
        done()
      }
    }
  }
}
