import SwiftUI

/// Marka işareti: hilal + cami kubbesi (logodaki motifin tek renk silueti).
/// RN: components/ui/CrescentMoon.tsx (48×48 görünüm kutusu, aynı ölçüler).
struct CrescentMoon: View {
  var size: CGFloat = 48
  var color: Color = Color(hex: 0xd9b36b)

  var body: some View {
    Canvas { ctx, canvas in
      let s = canvas.width / 48
      func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: (cx - r) * s, y: (cy - r) * s, width: 2 * r * s, height: 2 * r * s))
      }
      func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> Path {
        Path(roundedRect: CGRect(x: x * s, y: y * s, width: w * s, height: h * s), cornerRadius: r * s)
      }

      // Hilal: büyük daireden küçük daire ve kubbe tabanı bandı çıkarılır.
      ctx.drawLayer { layer in
        layer.fill(circle(20.5, 25.5, 15), with: .color(color))
        layer.blendMode = .destinationOut
        layer.fill(circle(27.3, 20.7, 12.6), with: .color(.black))
        layer.fill(rect(21.5, 29.4, 17, 4.2, 2.1), with: .color(.black))
      }
      // Kubbe
      ctx.fill(
        SVGPath.parse("M 23.8 29.8 C 23.2 24.4, 27.2 21.6, 30 18.2 C 32.8 21.6, 36.8 24.4, 36.2 29.8 Z")
          .applying(CGAffineTransform(scaleX: s, y: s)),
        with: .color(color))
      // Alem
      ctx.fill(rect(29.45, 13.6, 1.1, 5.2, 0.55), with: .color(color))
      ctx.drawLayer { layer in
        layer.fill(circle(30, 11.6, 2.5), with: .color(color))
        layer.blendMode = .destinationOut
        layer.fill(circle(31.4, 11, 2.1), with: .color(.black))
      }
      // Taban
      ctx.fill(rect(23.5, 30.4, 13, 1.8, 0.9), with: .color(color))
    }
    .frame(width: size, height: size)
    .environment(\.layoutDirection, .leftToRight)
    .accessibilityHidden(true)
  }
}

/// Google "G" logosu. RN: components/auth/GoogleIcon.tsx (aynı yollar).
struct GoogleIcon: View {
  var size: CGFloat = 18

  var body: some View {
    ZStack {
      SVGShape(d: "M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z")
        .fill(Color(hex: 0xEA4335))
      SVGShape(d: "M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z")
        .fill(Color(hex: 0x4285F4))
      SVGShape(d: "M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z")
        .fill(Color(hex: 0xFBBC05))
      SVGShape(d: "M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z")
        .fill(Color(hex: 0x34A853))
    }
    .frame(width: size, height: size)
    .environment(\.layoutDirection, .leftToRight)
    .accessibilityHidden(true)
  }
}

/// Auth ekranlarının hero markası: zümrüt degrade rozet içinde hilal, arkasında hafif ışıma.
/// RN: components/auth/AuthBrandMark.tsx
struct AuthBrandMark: View {
  var size: CGFloat = 84

  var body: some View {
    let s = size / 84
    ZStack {
      Circle()
        .fill(RadialGradient(colors: [Accent.s500.opacity(0.35), Accent.s500.opacity(0)], center: .center, startRadius: 0, endRadius: 42 * s))
      RoundedRectangle(cornerRadius: 20 * s)
        .fill(LinearGradient(colors: [Accent.s400, Accent.s600], startPoint: .topLeading, endPoint: .bottomTrailing))
        .overlay(RoundedRectangle(cornerRadius: 20 * s).stroke(.white.opacity(0.25), lineWidth: 1))
        .frame(width: 60 * s, height: 60 * s)
      CrescentMoon(size: size * 0.55, color: .white)
    }
    .frame(width: size, height: size)
  }
}

/// Kırmızı hata şeridi (auth formları).
struct ErrorBanner: View {
  @Environment(\.tokens) private var tokens
  let message: String

  var body: some View {
    HStack(spacing: 7) {
      Ionicon("alert-circle", size: 18, color: Color(hex: 0xef4444))
      Text(message)
        .font(.system(size: 12.25, weight: .medium))
        .foregroundStyle(tokens.isDark ? Color(hex: 0xf87171) : Color(hex: 0xdc2626))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(10.5)
    .background(tokens.isDark ? Color(hex: 0xef4444).opacity(0.1) : Color(hex: 0xfef2f2), in: .rect(cornerRadius: 14))
  }
}

/// Yeşil bilgi şeridi (ör. "Kod gönderildi").
struct SuccessBanner: View {
  @Environment(\.tokens) private var tokens
  let message: String

  var body: some View {
    HStack(spacing: 7) {
      Ionicon("checkmark-circle", size: 18, color: Accent.s600)
      Text(message)
        .font(.system(size: 12.25, weight: .medium))
        .foregroundStyle(tokens.isDark ? Accent.s400 : Accent.s600)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(10.5)
    .background(tokens.isDark ? Accent.s500.opacity(0.1) : Accent.s50, in: .rect(cornerRadius: 14))
  }
}
