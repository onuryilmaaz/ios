import SwiftUI

/// Onboarding hero illüstrasyonları: her slayt için ayrı sahne (cami, vakit kemeri, pusula,
/// mushaf, grafik, kupa, pin, çan). Ortak zemin (halka + parıltı + yıldızlar), slaydın
/// renklerine göre boyanır. RN: components/onboarding/OnboardingArt.tsx (aynı 264'lük koordinatlar).
struct OnboardingArt: View {
  let scene: String
  let accent: Color
  let accent2: Color
  let isDark: Bool
  var size: CGFloat = 264

  var body: some View {
    Canvas { ctx, canvasSize in
      ctx.scaleBy(x: canvasSize.width / 264, y: canvasSize.height / 264)
      background(&ctx)
      draw(&ctx)
    }
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }

  // MARK: - Boyama yardımcıları (SVG objectBoundingBox gradyanları)

  private func path(_ d: String) -> Path { SVGPath.parse(d) }

  private func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> Path {
    Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
  }

  private func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> Path {
    Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r)
  }

  private func line(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) -> Path {
    var p = Path()
    p.move(to: CGPoint(x: x1, y: y1))
    p.addLine(to: CGPoint(x: x2, y: y2))
    return p
  }

  private func polygon(_ pts: [(CGFloat, CGFloat)]) -> Path {
    var p = Path()
    p.addLines(pts.map { CGPoint(x: $0.0, y: $0.1) })
    p.closeSubpath()
    return p
  }

  /// Dikey accent → accent2 dolgu (%90 opak).
  private func fillGradient(_ ctx: inout GraphicsContext, _ p: Path, opacity: Double = 1) {
    let b = p.boundingRect
    ctx.fill(
      p,
      with: .linearGradient(
        Gradient(colors: [accent.opacity(0.9 * opacity), accent2.opacity(0.9 * opacity)]),
        startPoint: CGPoint(x: b.minX, y: b.minY), endPoint: CGPoint(x: b.minX, y: b.maxY)))
  }

  /// Çapraz accent → accent2 çizgi.
  private func strokeGradient(_ ctx: inout GraphicsContext, _ p: Path, width: CGFloat, round: Bool = false) {
    let b = p.boundingRect
    let style = StrokeStyle(lineWidth: width, lineCap: round ? .round : .butt, lineJoin: round ? .round : .miter)
    let end = CGPoint(x: b.width > 0 ? b.maxX : b.minX + 1, y: b.height > 0 ? b.maxY : b.minY)
    ctx.stroke(
      p, with: .linearGradient(Gradient(colors: [accent, accent2]), startPoint: CGPoint(x: b.minX, y: b.minY), endPoint: end),
      style: style)
  }

  private func stroke(_ ctx: inout GraphicsContext, _ p: Path, _ color: Color, width: CGFloat, round: Bool = true, dash: [CGFloat] = []) {
    ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: round ? .round : .butt, lineJoin: .round, dash: dash))
  }

  // MARK: - Ortak zemin

  private func background(_ ctx: inout GraphicsContext) {
    ctx.fill(
      circle(132, 132, 132),
      with: .radialGradient(
        Gradient(colors: [accent.opacity(isDark ? 0.26 : 0.18), accent.opacity(0)]),
        center: CGPoint(x: 132, y: 264 * 0.48), startRadius: 0, endRadius: 264 * 0.55))
    stroke(&ctx, circle(132, 132, 126), accent.opacity(0.1), width: 1.5, round: false)
    stroke(&ctx, circle(132, 132, 110), accent.opacity(0.28), width: 1.5, round: false, dash: [1.5, 12])
    let sparkles: [(CGFloat, CGFloat, CGFloat, Double)] = [
      (40, 64, 3, 0.9), (224, 80, 2.5, 0.7), (52, 214, 2, 0.6), (222, 208, 3, 0.8), (244, 150, 2, 0.5), (20, 146, 2.5, 0.6),
    ]
    for (x, y, r, o) in sparkles { ctx.fill(circle(x, y, r), with: .color(accent.opacity(o))) }
  }

  // MARK: - Sahneler

  private func draw(_ ctx: inout GraphicsContext) {
    switch scene {
    case "1":  // Cami silüeti + hilal
      fillGradient(&ctx, rect(66, 182, 132, 6, 3), opacity: 0.85)
      fillGradient(&ctx, rect(80, 120, 9, 62, 4))
      fillGradient(&ctx, path("M84.5 120 l4.5 -13 l4.5 13 z"))
      fillGradient(&ctx, rect(175, 120, 9, 62, 4))
      fillGradient(&ctx, path("M179.5 120 l4.5 -13 l4.5 13 z"))
      fillGradient(&ctx, rect(100, 150, 64, 32, 6))
      fillGradient(&ctx, path("M100 150 Q100 110 132 110 Q164 110 164 150 Z"))
      fillGradient(&ctx, rect(130, 92, 4, 18, 2))
      ctx.fill(path("M132 78 a9 9 0 1 0 5 16 a7 7 0 1 1 -5 -16 z"), with: .color(accent))
      ctx.fill(path("M124 182 v-16 a8 8 0 0 1 16 0 v16 z"), with: .color(accent2.opacity(0.55)))

    case "2":  // Gün kemeri + güneş + vakit noktaları
      strokeGradient(&ctx, path("M78 168 A54 54 0 0 1 186 168"), width: 2.5)
      strokeGradient(&ctx, line(70, 168, 194, 168), width: 2.5, round: true)
      fillGradient(&ctx, circle(132, 122, 20))
      for deg in stride(from: 0.0, to: 360, by: 45) {
        let a = deg * .pi / 180
        stroke(&ctx, line(132 + 26 * cos(a), 122 + 26 * sin(a), 132 + 33 * cos(a), 122 + 33 * sin(a)), accent, width: 2.5)
      }
      for deg in [200.0, 226, 270, 314, 340] {
        let a = deg * .pi / 180
        ctx.fill(circle(132 + 54 * cos(a), 168 + 54 * sin(a), 3.5), with: .color(accent))
      }

    case "3":  // Pusula
      strokeGradient(&ctx, circle(132, 132, 58), width: 2.5)
      for i in 0..<12 {
        let a = Double(i) * 30 * .pi / 180
        let major = i % 3 == 0
        let r1: Double = major ? 44 : 49
        stroke(
          &ctx, line(132 + r1 * cos(a), 132 + r1 * sin(a), 132 + 54 * cos(a), 132 + 54 * sin(a)),
          accent.opacity(major ? 0.9 : 0.45), width: major ? 2.5 : 1.5)
      }
      ctx.fill(polygon([(132, 84), (122, 132), (142, 132)]), with: .color(accent))
      ctx.fill(polygon([(132, 180), (122, 132), (142, 132)]), with: .color(accent2.opacity(0.5)))
      fillGradient(&ctx, circle(132, 132, 6))
      fillGradient(&ctx, rect(125, 72, 14, 14, 2))

    case "4":  // Açık mushaf
      for d in [
        "M132 112 C112 103 92 105 80 113 L80 170 C92 162 112 160 132 168 Z",
        "M132 112 C152 103 172 105 184 113 L184 170 C172 162 152 160 132 168 Z",
      ] {
        fillGradient(&ctx, path(d))
        strokeGradient(&ctx, path(d), width: 2)
      }
      stroke(&ctx, line(132, 114, 132, 166), accent2, width: 2, round: false)
      for y: CGFloat in [124, 134, 144] {
        stroke(&ctx, line(92, y, 120, y - 1), .white.opacity(0.6), width: 2)
        stroke(&ctx, line(144, y - 1, 172, y), .white.opacity(0.6), width: 2)
      }
      ctx.fill(path("M132 86 a8 8 0 1 0 4.5 14.5 a6 6 0 1 1 -4.5 -14.5 z"), with: .color(accent))

    case "5":  // Çubuk grafik + trend
      stroke(&ctx, line(84, 178, 182, 178), accent.opacity(0.5), width: 2)
      for (x, h) in [(90.0, 30.0), (114, 48), (138, 38), (162, 62)] {
        fillGradient(&ctx, rect(x, 176 - h, 16, h, 5))
      }
      strokeGradient(&ctx, path("M98 140 L122 122 L146 132 L170 100"), width: 3, round: true)
      for (x, y) in [(98.0, 140.0), (122, 122), (146, 132), (170, 100)] {
        ctx.fill(circle(x, y, 4), with: .color(accent))
      }

    case "8":  // Kupa
      strokeGradient(&ctx, path("M108 116 C92 116 92 142 110 144"), width: 4, round: true)
      strokeGradient(&ctx, path("M156 116 C172 116 172 142 154 144"), width: 4, round: true)
      fillGradient(&ctx, path("M104 108 H160 V120 A28 28 0 0 1 104 120 Z"))
      fillGradient(&ctx, rect(127, 150, 10, 16, 2))
      fillGradient(&ctx, rect(110, 166, 44, 9, 3))
      ctx.fill(
        polygon([(132, 116), (136, 128), (148, 128), (138, 135), (142, 147), (132, 140), (122, 147), (126, 135), (116, 128), (128, 128)]),
        with: .color(.white.opacity(0.9)))

    case "9":  // Harita pini
      stroke(&ctx, path("M74 176 C104 160 160 160 190 176"), accent.opacity(0.4), width: 2, round: false, dash: [3, 7])
      fillGradient(&ctx, path("M132 92 C113 92 100 106 100 124 C100 150 132 178 132 178 C132 178 164 150 164 124 C164 106 151 92 132 92 Z"))
      ctx.fill(circle(132, 123, 12), with: .color(.white.opacity(0.9)))
      ctx.fill(circle(132, 123, 5), with: .color(accent2))
      ctx.fill(circle(132, 186, 6), with: .color(accent.opacity(0.4)))

    case "10":  // Çan + ses dalgaları
      fillGradient(&ctx, path("M132 96 C115 96 108 112 108 132 L104 158 H160 L156 132 C156 112 149 96 132 96 Z"))
      fillGradient(&ctx, circle(132, 94, 6))
      ctx.fill(path("M120 158 a12 12 0 0 0 24 0 z"), with: .color(accent2))
      stroke(&ctx, path("M168 116 a22 22 0 0 1 0 32"), accent.opacity(0.8), width: 2.5)
      stroke(&ctx, path("M178 106 a36 36 0 0 1 0 52"), accent.opacity(0.4), width: 2.5)
      stroke(&ctx, path("M96 116 a22 22 0 0 0 0 32"), accent.opacity(0.8), width: 2.5)
      stroke(&ctx, path("M86 106 a36 36 0 0 0 0 52"), accent.opacity(0.4), width: 2.5)

    default:
      strokeGradient(&ctx, circle(132, 132, 70), width: 3)
    }
  }
}
