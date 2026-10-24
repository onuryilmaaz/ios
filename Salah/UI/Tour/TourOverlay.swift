import SwiftUI

/// Tur katmanı: ekranı karartır, sıradaki öğeyi açıkta bırakıp altın çerçeveyle çizer ve yanında
/// koyu zümrüt ipucu balonunu (öğeye bakan okla) gösterir. Sekme çubuğu dahil her şeyin üstünde (RootView).
struct TourOverlay: View {
  @Environment(\.tokens) private var tokens
  @Environment(\.layoutDirection) private var direction
  @State private var visible = false
  @State private var breathe = false

  private static let gap: CGFloat = 16
  private static let caret: CGFloat = 9
  private static let maxCardWidth: CGFloat = 420

  var body: some View {
    let store = TourStore.shared
    if let tour = store.tour, let step = store.current, let rect = store.anchors[step.anchor] {
      GeometryReader { proxy in
        let bounds = CGRect(origin: .zero, size: proxy.size)
        // Kaydırılan adımda öğe ekrana gelene kadar yalnız karartma.
        let onScreen = !step.scroll || bounds.contains(rect)
        // Kenara dayanan öğelerde (sekme çubuğu) çerçeve ekrandan taşmasın.
        let hole = onScreen ? rect.insetBy(dx: -6, dy: -6).intersection(bounds.insetBy(dx: 3, dy: 3)) : .zero
        let radius = min(hole.height / 2, 27)
        // Balon, öğenin hangi yanında daha çok yer varsa oraya.
        let safe = TourStore.safeInsets()
        let below = bounds.maxY - safe.bottom - hole.maxY >= hole.minY - safe.top
        let cardWidth = min(bounds.width - 32, Self.maxCardWidth)
        let cardMinX = (bounds.width - cardWidth) / 2
        // Ok balonun köşelerine taşmadan öğenin ortasına bakar.
        let caretX = min(max(hole.midX, cardMinX + 28), cardMinX + cardWidth - 28)

        ZStack {
          // Öğenin yeri pencere koordinatında: karartma, çerçeve ve ok yön çevrilmeden çizilir.
          Path { path in
            path.addRect(bounds)
            path.addRoundedRect(in: hole, cornerSize: CGSize(width: radius, height: radius))
          }
          .fill(.black.opacity(tokens.isDark ? 0.74 : 0.64), style: FillStyle(eoFill: true))
          .contentShape(Rectangle())
          .onTapGesture { store.next() }

          if onScreen {
          // Nefes alan dış halka (yalnız çizgi, parıltı yok).
          RoundedRectangle(cornerRadius: radius + 5)
            .stroke(Gold.s300.opacity(breathe ? 0 : 0.5), lineWidth: 1.5)
            .frame(width: hole.width + 10, height: hole.height + 10)
            .scaleEffect(breathe ? 1.05 : 1)
            .position(x: hole.midX, y: hole.midY)
            .allowsHitTesting(false)
          RoundedRectangle(cornerRadius: radius)
            .stroke(Gold.s300, lineWidth: 2)
            .frame(width: hole.width, height: hole.height)
            .position(x: hole.midX, y: hole.midY)
            .allowsHitTesting(false)

          Path { path in
            let edge = below ? hole.maxY + Self.gap + 1 : hole.minY - Self.gap - 1
            let tip = below ? edge - Self.caret - 1 : edge + Self.caret + 1
            path.move(to: CGPoint(x: caretX - Self.caret, y: edge))
            path.addLine(to: CGPoint(x: caretX, y: tip))
            path.addLine(to: CGPoint(x: caretX + Self.caret, y: edge))
            path.closeSubpath()
          }
          .fill(tokens.hero)
          .allowsHitTesting(false)

          card(tour: tour, step: step)
            .environment(\.layoutDirection, direction)
            .frame(width: cardWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: below ? .top : .bottom)
            .padding(.top, below ? hole.maxY + Self.gap : 0)
            .padding(.bottom, below ? 0 : bounds.height - hole.minY + Self.gap)
          }
        }
        .animation(.spring(duration: 0.4, bounce: 0.15), value: store.index)
      }
      .environment(\.layoutDirection, .leftToRight)
      .ignoresSafeArea()
      .opacity(visible ? 1 : 0)
      .onAppear {
        withAnimation(.easeOut(duration: 0.25)) { visible = true }
        withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) { breathe = true }
      }
      .accessibilityAddTraits(.isModal)
    }
  }

  private func card(tour: Tour, step: Tour.Step) -> some View {
    let store = TourStore.shared
    let isLast = store.index == store.steps.count - 1
    return VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .center, spacing: 12) {
        Ionicon(step.icon, size: 20, color: Gold.s300)
          .frame(width: 40, height: 40)
          .background(.white.opacity(0.1), in: .circle)
        Text(t("tour.\(step.text).title"))
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(.white)
          .frame(maxWidth: .infinity, alignment: .leading)
        Text(t("tour.progress", ["current": store.index + 1, "total": store.steps.count]))
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(.white.opacity(0.55))
          .tabularNumbers()
      }
      Text(t("tour.\(step.text).body"))
        .font(.system(size: 15))
        .foregroundStyle(.white.opacity(0.78))
        .lineSpacing(2)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 12)

      HStack(spacing: 4) {
        ForEach(store.steps.indices, id: \.self) { i in
          Capsule()
            .fill(i <= store.index ? Gold.s300 : .white.opacity(0.16))
            .frame(height: 4)
        }
      }
      .padding(.top, 18)
      .accessibilityHidden(true)

      HStack {
        if !isLast {
          Button(t("tour.skip")) { store.skip() }
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.white.opacity(0.6))
            .buttonStyle(PressableStyle(pressedOpacity: 0.6))
        }
        Spacer(minLength: 12)
        Button {
          store.next()
        } label: {
          HStack(spacing: 6) {
            Text(t(isLast ? "tour.done" : "tour.next"))
              .font(.system(size: 15, weight: .semibold))
            Ionicon(isLast ? "checkmark" : dirIcon("arrow-forward"), size: 16, color: Accent.s950)
          }
          .foregroundStyle(Accent.s950)
          .padding(.leading, 20)
          .padding(.trailing, 16)
          .padding(.vertical, 11)
          .background(Gold.s300, in: .capsule)
        }
        .buttonStyle(PressableStyle())
      }
      .padding(.top, 16)
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(tokens.hero, in: .rect(cornerRadius: 24))
    .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.08), lineWidth: 1))
    .accessibilityElement(children: .contain)
    .accessibilityLabel(t("tour.a11y"))
    .id(store.index)
    .transition(.opacity.combined(with: .scale(scale: 0.97)))
  }
}
