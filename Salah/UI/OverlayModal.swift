import SwiftUI

extension View {
  /// Sekme çubuğunun da üstünde, solarak açılan saydam pencere.
  func overlayModal<Content: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
    fullScreenCover(isPresented: isPresented) {
      content().presentationBackground(.clear)
    }
    .transaction { if isPresented.wrappedValue { $0.disablesAnimations = true } }
  }
}
