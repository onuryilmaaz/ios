import SwiftUI

/// Mushaftaki ayet duraklarına benzeyen sekiz köşeli yıldız madalyonu; ortada numara.
/// RN: components/quran/NumberMedallion.tsx (100×100 görünüm kutusu, aynı oranlar).
struct NumberMedallion: View {
  let label: String
  var color: Color = Accent.s600
  var accent2: Color?
  var size: CGFloat = 48
  var textColor: Color?

  var body: some View {
    let c2 = accent2 ?? color
    ZStack {
      Canvas { ctx, canvas in
        let s = canvas.width / 100
        let star = Self.star(radius: 46 * s, center: CGPoint(x: 50 * s, y: 50 * s))
        ctx.fill(star, with: .linearGradient(
          Gradient(colors: [color.opacity(0.16), c2.opacity(0.16)]),
          startPoint: .zero, endPoint: CGPoint(x: canvas.width, y: canvas.height)))
        let style = StrokeStyle(lineWidth: 2 * s, lineJoin: .round)
        ctx.stroke(star, with: .color(color.opacity(0.35)), style: style)
        let rotated = star.applying(
          CGAffineTransform(translationX: 50 * s, y: 50 * s).rotated(by: .pi / 4).translatedBy(x: -50 * s, y: -50 * s))
        ctx.stroke(rotated, with: .color(color.opacity(0.35)), style: style)
        ctx.stroke(Path(ellipseIn: CGRect(x: 24 * s, y: 24 * s, width: 52 * s, height: 52 * s)), with: .color(c2.opacity(0.3)), lineWidth: 1.5 * s)
      }
      Text(label)
        .font(.system(size: size * 0.32, weight: .black))
        .foregroundStyle(textColor ?? color)
        .monospacedDigit()
    }
    .frame(width: size, height: size)
    .environment(\.layoutDirection, .leftToRight)
    .accessibilityElement(children: .combine)
  }

  /// Sekiz köşeli yıldız (köşeleri tepeden başlayan sekizgen yıldız noktaları).
  private static func star(radius r: CGFloat, center c: CGPoint) -> Path {
    var path = Path()
    for i in 0..<8 {
      let angle = Double.pi / 4 * Double(i) - .pi / 2
      let p = CGPoint(x: c.x + r * cos(angle), y: c.y + r * sin(angle))
      if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
    }
    path.closeSubpath()
    return path
  }
}

/// Renkli başlıklara konan ince İslami geometrik filigran: Rub'el Hizb yıldızı +
/// eş merkezli halkalar. RN: components/ui/DecorPattern.tsx
struct DecorPattern: View {
  var color: Color = .white
  var opacity: Double = 0.12
  var size: CGFloat = 180

  var body: some View {
    Canvas { ctx, canvas in
      let s = canvas.width / 200
      func circle(_ r: CGFloat) -> Path { Path(ellipseIn: CGRect(x: (100 - r) * s, y: (100 - r) * s, width: 2 * r * s, height: 2 * r * s)) }
      func square(_ r: CGFloat, rotated: Bool) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: (100 - r) * s, y: 100 * s))
        p.addLine(to: CGPoint(x: 100 * s, y: (100 - r) * s))
        p.addLine(to: CGPoint(x: (100 + r) * s, y: 100 * s))
        p.addLine(to: CGPoint(x: 100 * s, y: (100 + r) * s))
        p.closeSubpath()
        guard rotated else { return p }
        return p.applying(CGAffineTransform(translationX: 100 * s, y: 100 * s).rotated(by: .pi / 4).translatedBy(x: -100 * s, y: -100 * s))
      }
      let shade = GraphicsContext.Shading.color(color)
      ctx.stroke(circle(92), with: shade, lineWidth: 2 * s)
      ctx.stroke(circle(74), with: shade, style: StrokeStyle(lineWidth: 1.5 * s, dash: [2 * s, 10 * s]))
      ctx.stroke(square(56, rotated: false), with: shade, lineWidth: 2 * s)
      ctx.stroke(square(56, rotated: true), with: shade, lineWidth: 2 * s)
      ctx.stroke(circle(20), with: shade, lineWidth: 2 * s)
    }
    .frame(width: size, height: size)
    .opacity(opacity)
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}
