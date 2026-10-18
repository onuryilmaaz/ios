import SwiftUI

/// Soğuk açılışta ~1,4 sn'lik marka animasyonu. Statik açılış ekranıyla aynı zümrüt zeminden
/// başlar (LaunchScreen.storyboard), bitince hafifçe büyüyerek kaybolur ve alttaki uygulama görünür.
/// "Derin Orman" dili: gradyan/parlama yok; altın çizgi, hilal ve Bungee logo.
struct SplashView: View {
  var onFinish: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var starTrim: CGFloat = 0
  @State private var starAngle: Double = -40
  @State private var moonScale: CGFloat = 0.55
  @State private var moonOpacity: Double = 0
  @State private var lettersShown = 0
  @State private var ringScale: CGFloat = 0.9
  @State private var ringOpacity: Double = 0
  @State private var leaving = false
  @State private var finished = false

  private static let word = Array("SALAH")
  private var motionReduced: Bool { reduceMotion || DebugLaunch.splashReduceMotion }

  var body: some View {
    ZStack {
      Accent.s900.ignoresSafeArea()

      VStack(spacing: 28) {
        ZStack {
          Circle()
            .stroke(Gold.s300, lineWidth: 1)
            .frame(width: 168, height: 168)
            .scaleEffect(ringScale)
            .opacity(ringOpacity)
          EightPointStar()
            .trim(from: 0, to: starTrim)
            .stroke(Gold.s300.opacity(0.85), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
            .frame(width: 148, height: 148)
            .rotationEffect(.degrees(starAngle))
          Circle()
            .stroke(Gold.s300.opacity(0.35), lineWidth: 1)
            .frame(width: 104, height: 104)
            .opacity(starTrim)
          CrescentMoon(size: 78, color: Gold.s300)
            .scaleEffect(moonScale)
            .opacity(moonOpacity)
        }
        .frame(width: 180, height: 180)

        HStack(spacing: 0) {
          ForEach(Array(Self.word.enumerated()), id: \.offset) { i, letter in
            Text(String(letter))
              .font(.custom("Bungee-Regular", fixedSize: 34))
              .foregroundStyle(Amber.s500)
              .opacity(i < lettersShown ? 1 : 0)
              .offset(y: i < lettersShown ? 0 : 12)
          }
        }
        .tracking(4)
        .environment(\.layoutDirection, .leftToRight)
      }
      .offset(y: -20)
    }
    .scaleEffect(leaving && !motionReduced ? 1.08 : 1)
    .opacity(leaving ? 0 : 1)
    .statusBar(.light, priority: 1)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(verbatim: "Salah"))
    .task { await run() }
  }

  private func run() async {
    // Sabit kareler yalnız Debug'da, canlı API kapalı görsel kontrol içindir.
    if let frame = DebugLaunch.splashFrame {
      if frame == "brand" { showBrand() }
      return
    }
    do {
      try await SplashSequence.run(reduceMotion: motionReduced) { event in
        switch event {
        case .drawMark:
          withAnimation(.easeInOut(duration: 0.6)) { starTrim = 1 }
          withAnimation(.easeOut(duration: 0.9)) { starAngle = 0 }
        case .revealMoon:
          withAnimation(.spring(response: 0.5, dampingFraction: 0.62)) {
            moonScale = 1
            moonOpacity = 1
          }
        case .revealLetter(let count):
          withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { lettersShown = count }
        case .pulse:
          ringOpacity = 0.7
          withAnimation(.easeOut(duration: 0.7)) {
            ringScale = 1.75
            ringOpacity = 0
          }
        case .showBrand: showBrand()
        case .fade:
          withAnimation(.easeOut(duration: motionReduced ? 0.25 : 0.3)) { leaving = true }
        case .finish:
          guard !finished else { return }
          finished = true
          onFinish()
        }
      }
    } catch {
      // SwiftUI .task iptali: kaybolan görünüm yeni ekranın durumunu değiştirmemeli.
    }
  }

  private func showBrand() {
    starTrim = 1
    starAngle = 0
    moonScale = 1
    moonOpacity = 1
    lettersShown = Self.word.count
  }
}

/// Sekiz köşeli yıldız (rub'ül-hizb): biri 45° döndürülmüş iki kare. Önce biri, sonra
/// diğeri çizilir; `trim` ile çizgi çizilerek belirir.
private struct EightPointStar: Shape {
  func path(in rect: CGRect) -> Path {
    let c = CGPoint(x: rect.midX, y: rect.midY)
    let r = min(rect.width, rect.height) / 2
    var path = Path()
    for offset in [0.0, 45.0] {
      for k in 0...4 {
        let a = (offset + 45 + Double(k) * 90) * .pi / 180
        let p = CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
        if k == 0 { path.move(to: p) } else { path.addLine(to: p) }
      }
    }
    return path
  }
}
