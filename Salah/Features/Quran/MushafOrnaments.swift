import CoreImage
import SwiftUI
import UIKit

// Basılı Mushaf görünümü: tezhip çerçevesi, sure kartuşu, kenar işaretleri, cilt ve kağıt.
// Desenler uygulamaya özgüdür (Medine Mushafı tezhibinin kopyası değildir); renkler Mushaf temasından gelir.
// Tasarım dilinin "gölge/geçiş yok" kuralına tek istisna bu sayfadır: cilt gölgesi ve kağıt dokusu (CLAUDE.md).

/// Sekiz köşeli yıldız (rub'ül-hizb): biri 45° döndürülmüş iki kare.
nonisolated struct RubElHizbShape: Shape {
  func path(in rect: CGRect) -> Path {
    let c = CGPoint(x: rect.midX, y: rect.midY)
    let r = min(rect.width, rect.height) / 2
    var path = Path()
    for offset in [0.0, 45.0] {
      for k in 0..<4 {
        let a = (offset + 45 + Double(k) * 90) * .pi / 180
        let p = CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
        if k == 0 { path.move(to: p) } else { path.addLine(to: p) }
      }
      path.closeSubpath()
    }
    return path
  }
}

/// Sure başlığı kartuşu: iki ucu sivri uzun levha.
nonisolated struct CartoucheShape: InsettableShape {
  var inset: CGFloat = 0

  func path(in rect: CGRect) -> Path {
    let r = rect.insetBy(dx: inset, dy: inset)
    let tip = r.height * 0.5
    var path = Path()
    path.move(to: CGPoint(x: r.minX + tip, y: r.minY))
    path.addLine(to: CGPoint(x: r.maxX - tip, y: r.minY))
    path.addLine(to: CGPoint(x: r.maxX, y: r.midY))
    path.addLine(to: CGPoint(x: r.maxX - tip, y: r.maxY))
    path.addLine(to: CGPoint(x: r.minX + tip, y: r.maxY))
    path.addLine(to: CGPoint(x: r.minX, y: r.midY))
    path.closeSubpath()
    return path
  }

  func inset(by amount: CGFloat) -> CartoucheShape { CartoucheShape(inset: inset + amount) }
}

/// Tezhip deseni çizimleri (çerçeve ve sure başlığı ortak kullanır).
enum Tezhip {
  static func star(_ c: CGPoint, _ r: CGFloat) -> Path { RubElHizbShape().path(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)) }

  static func lozenge(_ c: CGPoint, _ rx: CGFloat, _ ry: CGFloat) -> Path {
    var p = Path()
    p.move(to: CGPoint(x: c.x, y: c.y - ry))
    p.addLine(to: CGPoint(x: c.x + rx, y: c.y))
    p.addLine(to: CGPoint(x: c.x, y: c.y + ry))
    p.addLine(to: CGPoint(x: c.x - rx, y: c.y))
    p.closeSubpath()
    return p
  }

  /// Bir doğru boyunca yıldız ve baklava dizisi (yıldızlar altın, baklavalar soluk altın).
  static func chain(_ ctx: GraphicsContext, from a: CGPoint, to b: CGPoint, size: CGFloat, palette: MushafPalette) {
    let length = hypot(b.x - a.x, b.y - a.y)
    guard length > size * 2 else { return }
    let step = size * 1.55
    let count = Int(length / step)
    let offset = (length - CGFloat(count) * step) / 2 + step / 2
    let dx = (b.x - a.x) / length, dy = (b.y - a.y) / length
    for i in 0..<count {
      let d = offset + CGFloat(i) * step
      let c = CGPoint(x: a.x + dx * d, y: a.y + dy * d)
      if i % 2 == 0 {
        ctx.fill(star(c, size * 0.5), with: .color(palette.gold))
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - size * 0.13, y: c.y - size * 0.13, width: size * 0.26, height: size * 0.26)), with: .color(palette.header))
      } else {
        ctx.fill(lozenge(c, size * 0.3, size * 0.3), with: .color(palette.gold.opacity(0.55)))
      }
    }
  }

  /// Altın halkalı madalyon, ortasında yıldız.
  static func medallion(_ ctx: GraphicsContext, _ c: CGPoint, _ r: CGFloat, palette: MushafPalette) {
    let circle = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
    ctx.fill(circle, with: .color(palette.header))
    ctx.stroke(circle, with: .color(palette.gold), lineWidth: 1)
    ctx.fill(star(c, r * 0.72), with: .color(palette.gold))
    ctx.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.22, y: c.y - r * 0.22, width: r * 0.44, height: r * 0.44)), with: .color(palette.header))
  }
}

/// Sure başlığı: tam genişlikte levha; iki yanda desenli pano, ortada sivri uçlu madalyon içinde sure adı.
struct SurahCartouche: View {
  let name: String
  let font: Double
  let palette: MushafPalette

  var body: some View {
    let height = font * 1.9
    Text(name)
      .font(.custom(QuranFont.name, size: font * 0.95)).foregroundStyle(palette.ink)
      .lineLimit(1).minimumScaleFactor(0.6)
      .padding(.horizontal, height * 0.9)
      .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
      .background {
        Canvas { ctx, size in
          let rect = CGRect(origin: .zero, size: size)
          ctx.fill(Path(rect), with: .color(palette.header))
          ctx.stroke(Path(rect.insetBy(dx: 0.5, dy: 0.5)), with: .color(palette.gold), lineWidth: 1)
          ctx.stroke(Path(rect.insetBy(dx: 2.5, dy: 2.5)), with: .color(palette.gold.opacity(0.6)), lineWidth: 0.5)
          // Ortadaki madalyon sure adının genişliği kadar; iki yandaki panolarda desen.
          let medallion = CGRect(x: size.width * 0.24, y: 4.5, width: size.width * 0.52, height: size.height - 9)
          let unit = size.height * 0.42
          Tezhip.chain(ctx, from: CGPoint(x: 6, y: size.height / 2), to: CGPoint(x: medallion.minX - 2, y: size.height / 2), size: unit, palette: palette)
          Tezhip.chain(ctx, from: CGPoint(x: medallion.maxX + 2, y: size.height / 2), to: CGPoint(x: size.width - 6, y: size.height / 2), size: unit, palette: palette)
          ctx.fill(CartoucheShape().path(in: medallion), with: .color(palette.canvas))
          ctx.stroke(CartoucheShape().path(in: medallion), with: .color(palette.gold), lineWidth: 1.2)
          ctx.stroke(CartoucheShape().path(in: medallion.insetBy(dx: 2.5, dy: 2.5)), with: .color(palette.gold.opacity(0.6)), lineWidth: 0.5)
        }
      }
      .environment(\.layoutDirection, .leftToRight)
  }
}

/// Metin bloğunu saran tezhip: dışta ve içte altın çift çizgi, aradaki dolu bantta yıldız ve baklava dizisi,
/// köşelerde ve kenar ortalarında madalyon.
struct MushafFrame: View {
  let palette: MushafPalette
  /// Çerçevenin toplam kalınlığı.
  let band: CGFloat

  var body: some View {
    Canvas { ctx, size in
      let rect = CGRect(origin: .zero, size: size)
      let b = band
      var ring = Path(rect)
      ring.addRect(rect.insetBy(dx: b, dy: b))
      ctx.fill(ring, with: .color(palette.header), style: FillStyle(eoFill: true))
      ctx.stroke(Path(rect.insetBy(dx: 0.5, dy: 0.5)), with: .color(palette.gold), lineWidth: 1)
      ctx.stroke(Path(rect.insetBy(dx: 2.2, dy: 2.2)), with: .color(palette.gold.opacity(0.6)), lineWidth: 0.5)
      ctx.stroke(Path(rect.insetBy(dx: b - 2.2, dy: b - 2.2)), with: .color(palette.gold.opacity(0.6)), lineWidth: 0.5)
      ctx.stroke(Path(rect.insetBy(dx: b - 0.6, dy: b - 0.6)), with: .color(palette.gold), lineWidth: 1.2)
      let m = b / 2, unit = b - 4.4, r = b * 0.95
      let w = size.width, h = size.height
      // Kenar dizileri köşe ve orta madalyonlarına kadar.
      for (a, z) in [(CGPoint(x: r * 2, y: m), CGPoint(x: w / 2 - r * 1.3, y: m)), (CGPoint(x: w / 2 + r * 1.3, y: m), CGPoint(x: w - r * 2, y: m)),
                     (CGPoint(x: r * 2, y: h - m), CGPoint(x: w / 2 - r * 1.3, y: h - m)), (CGPoint(x: w / 2 + r * 1.3, y: h - m), CGPoint(x: w - r * 2, y: h - m)),
                     (CGPoint(x: m, y: r * 2), CGPoint(x: m, y: h / 2 - r * 1.3)), (CGPoint(x: m, y: h / 2 + r * 1.3), CGPoint(x: m, y: h - r * 2)),
                     (CGPoint(x: w - m, y: r * 2), CGPoint(x: w - m, y: h / 2 - r * 1.3)), (CGPoint(x: w - m, y: h / 2 + r * 1.3), CGPoint(x: w - m, y: h - r * 2))] {
        Tezhip.chain(ctx, from: a, to: z, size: unit, palette: palette)
      }
      for c in [CGPoint(x: m, y: m), CGPoint(x: w - m, y: m), CGPoint(x: m, y: h - m), CGPoint(x: w - m, y: h - m),
                CGPoint(x: w / 2, y: m), CGPoint(x: w / 2, y: h - m), CGPoint(x: m, y: h / 2), CGPoint(x: w - m, y: h / 2)] {
        Tezhip.medallion(ctx, c, r, palette: palette)
      }
    }
    .allowsHitTesting(false)
  }
}

/// Kenar notu: basılı Mushaf'taki gibi kenara dik yazılmış Arapça (۞ ربع الحزب ١٨, الجزء ٥, سجدة ۩).
struct MushafMarginMark: View {
  let kind: MushafMarks.Kind
  let palette: MushafPalette
  /// Sağ kenarda yukarıdan aşağı, sol kenarda aşağıdan yukarı okunur.
  let rightSide: Bool

  var body: some View {
    Text(verbatim: kind.printed)
      .font(.system(size: 8.5, weight: .semibold)).foregroundStyle(palette.gold)
      .environment(\.layoutDirection, .rightToLeft)
      .fixedSize()
      .rotationEffect(.degrees(rightSide ? 90 : -90))
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(kind.a11yLabel)
  }
}

/// Kitap düzeninde (Duo) sayfanın cilt ve dış kenarı: ciltte gölge, dışta okunan/kalan sayfa destesi.
struct BookPageEdges: View {
  let page: Int
  let palette: MushafPalette
  let insets: EdgeInsets

  var body: some View {
    // Tek sayfa sağda: cilt solunda, destesi sağında. Sağdaki deste okunan, soldaki kalan sayfalardır.
    let right = page % 2 == 1
    let fraction = right ? Double(page) / 604 : Double(604 - page) / 604
    let sheets = 1 + Int((fraction * 6).rounded())
    HStack(spacing: 0) {
      if right { spine(leading: true) } else { stack(sheets, leading: true) }
      Spacer(minLength: 0)
      if right { stack(sheets, leading: false) } else { spine(leading: false) }
    }
    .environment(\.layoutDirection, .leftToRight)
    .allowsHitTesting(false)
  }

  private func spine(leading: Bool) -> some View {
    LinearGradient(colors: [.black.opacity(palette.isDark ? 0.35 : 0.13), .clear],
      startPoint: leading ? .leading : .trailing, endPoint: leading ? .trailing : .leading)
      .frame(width: 26)
  }

  private func stack(_ sheets: Int, leading: Bool) -> some View {
    HStack(spacing: 1.5) {
      ForEach(0..<sheets, id: \.self) { _ in Rectangle().fill(palette.border.opacity(0.45)).frame(width: 0.6) }
    }
    .padding(.vertical, 6)
    .padding(.top, insets.top)
    .padding(.bottom, insets.bottom)
    .padding(leading ? .leading : .trailing, 2)
  }
}

/// Kağıt dokusu: bir kez üretilen gri gürültü, sayfada döşenir.
enum PaperTexture {
  static let image: UIImage? = {
    let context = CIContext()
    guard let noise = CIFilter(name: "CIRandomGenerator")?.outputImage,
      let mono = CIFilter(name: "CIColorControls", parameters: [kCIInputImageKey: noise, kCIInputSaturationKey: 0, kCIInputContrastKey: 0.6])?.outputImage,
      let cg = context.createCGImage(mono, from: CGRect(x: 0, y: 0, width: 192, height: 192))
    else { return nil }
    return UIImage(cgImage: cg, scale: 2, orientation: .up)
  }()
}

extension View {
  /// Sayfa zeminine hafif kağıt dokusu: yazının altında, zeminin üstünde (`.background(canvas)`'tan önce verilir).
  func paperTexture(_ palette: MushafPalette) -> some View {
    background {
      if let image = PaperTexture.image {
        Image(uiImage: image).resizable(resizingMode: .tile)
          .opacity(palette.isDark ? 0.035 : 0.06).blendMode(palette.isDark ? .screen : .multiply)
          .allowsHitTesting(false)
      }
    }
  }
}
