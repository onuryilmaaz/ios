import SwiftUI

/// SVG `d` dizesinden SwiftUI `Path` (RN'deki react-native-svg ikonlarını birebir
/// taşımak için). Desteklenen komutlar: M L H V C S Q A Z (büyük/küçük harf).
nonisolated enum SVGPath {
  static func parse(_ d: String) -> Path {
    var path = Path()
    var tokens = tokenize(d)[...]
    var current = CGPoint.zero
    var start = CGPoint.zero
    var lastControl: CGPoint?
    var command: Character = "M"

    func number() -> CGFloat? {
      guard case .number(let n)? = tokens.first else { return nil }
      tokens.removeFirst()
      return n
    }

    while let token = tokens.first {
      if case .command(let c) = token {
        command = c
        tokens.removeFirst()
      }
      let relative = command.isLowercase
      let base = relative ? current : .zero
      switch command.uppercased() {
      case "M":
        guard let x = number(), let y = number() else { return path }
        current = CGPoint(x: base.x + x, y: base.y + y)
        start = current
        path.move(to: current)
        // Ardışık koordinatlar çizgi sayılır.
        command = relative ? "l" : "L"
        lastControl = nil
      case "L":
        guard let x = number(), let y = number() else { return path }
        current = CGPoint(x: base.x + x, y: base.y + y)
        path.addLine(to: current)
        lastControl = nil
      case "H":
        guard let x = number() else { return path }
        current = CGPoint(x: (relative ? current.x : 0) + x, y: current.y)
        path.addLine(to: current)
        lastControl = nil
      case "V":
        guard let y = number() else { return path }
        current = CGPoint(x: current.x, y: (relative ? current.y : 0) + y)
        path.addLine(to: current)
        lastControl = nil
      case "C":
        guard let x1 = number(), let y1 = number(), let x2 = number(), let y2 = number(), let x = number(), let y = number()
        else { return path }
        let c1 = CGPoint(x: base.x + x1, y: base.y + y1)
        let c2 = CGPoint(x: base.x + x2, y: base.y + y2)
        current = CGPoint(x: base.x + x, y: base.y + y)
        path.addCurve(to: current, control1: c1, control2: c2)
        lastControl = c2
      case "S":
        guard let x2 = number(), let y2 = number(), let x = number(), let y = number() else { return path }
        let c1 = lastControl.map { CGPoint(x: 2 * current.x - $0.x, y: 2 * current.y - $0.y) } ?? current
        let c2 = CGPoint(x: base.x + x2, y: base.y + y2)
        current = CGPoint(x: base.x + x, y: base.y + y)
        path.addCurve(to: current, control1: c1, control2: c2)
        lastControl = c2
      case "Q":
        guard let x1 = number(), let y1 = number(), let x = number(), let y = number() else { return path }
        let c = CGPoint(x: base.x + x1, y: base.y + y1)
        current = CGPoint(x: base.x + x, y: base.y + y)
        path.addQuadCurve(to: current, control: c)
        lastControl = nil
      case "A":
        guard let rx = number(), let ry = number(), let rotation = number(), let large = number(), let sweep = number(),
          let x = number(), let y = number()
        else { return path }
        let end = CGPoint(x: base.x + x, y: base.y + y)
        addArc(&path, from: current, to: end, rx: rx, ry: ry, rotation: rotation, largeArc: large != 0, sweep: sweep != 0)
        current = end
        lastControl = nil
      case "Z":
        path.closeSubpath()
        current = start
        lastControl = nil
        if case .number? = tokens.first { tokens.removeFirst() }
      default:
        tokens.removeFirst()
      }
    }
    return path
  }

  /// SVG uç nokta yayı → merkez parametreleri → kübik Bézier parçaları (SVG 1.1 F.6.5).
  private static func addArc(
    _ path: inout Path, from p0: CGPoint, to p1: CGPoint, rx rxIn: CGFloat, ry ryIn: CGFloat, rotation: CGFloat, largeArc: Bool, sweep: Bool
  ) {
    var rx = abs(rxIn), ry = abs(ryIn)
    guard rx > 0, ry > 0, p0 != p1 else {
      path.addLine(to: p1)
      return
    }
    let phi = rotation * .pi / 180
    let cosP = cos(phi), sinP = sin(phi)
    let dx = (p0.x - p1.x) / 2, dy = (p0.y - p1.y) / 2
    let x1 = cosP * dx + sinP * dy, y1 = -sinP * dx + cosP * dy
    let lambda = (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry)
    if lambda > 1 { rx *= sqrt(lambda); ry *= sqrt(lambda) }
    let num = rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1
    let den = rx * rx * y1 * y1 + ry * ry * x1 * x1
    var coef = sqrt(max(0, num / den))
    if largeArc == sweep { coef = -coef }
    let cx1 = coef * rx * y1 / ry, cy1 = -coef * ry * x1 / rx
    let cx = cosP * cx1 - sinP * cy1 + (p0.x + p1.x) / 2
    let cy = sinP * cx1 + cosP * cy1 + (p0.y + p1.y) / 2
    func angle(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
      let a = atan2(ux * vy - uy * vx, ux * vx + uy * vy)
      return a
    }
    let theta1 = angle(1, 0, (x1 - cx1) / rx, (y1 - cy1) / ry)
    var delta = angle((x1 - cx1) / rx, (y1 - cy1) / ry, (-x1 - cx1) / rx, (-y1 - cy1) / ry)
    if !sweep && delta > 0 { delta -= 2 * .pi }
    if sweep && delta < 0 { delta += 2 * .pi }

    let segments = max(1, Int(ceil(abs(delta) / (.pi / 2))))
    let step = delta / CGFloat(segments)
    let k = 4 / 3 * tan(step / 4)
    func point(_ t: CGFloat) -> CGPoint {
      let x = rx * cos(t), y = ry * sin(t)
      return CGPoint(x: cosP * x - sinP * y + cx, y: sinP * x + cosP * y + cy)
    }
    func derivative(_ t: CGFloat) -> CGPoint {
      let x = -rx * sin(t), y = ry * cos(t)
      return CGPoint(x: cosP * x - sinP * y, y: sinP * x + cosP * y)
    }
    var t = theta1
    for _ in 0..<segments {
      let t2 = t + step
      let a = point(t), b = point(t2), da = derivative(t), db = derivative(t2)
      path.addCurve(
        to: b, control1: CGPoint(x: a.x + k * da.x, y: a.y + k * da.y), control2: CGPoint(x: b.x - k * db.x, y: b.y - k * db.y))
      t = t2
    }
  }

  private enum Token {
    case command(Character)
    case number(CGFloat)
  }

  /// "c3.54 0 6.71-1.22.38-4.55" gibi sıkışık yazımı da ayırır.
  private static func tokenize(_ d: String) -> [Token] {
    var out: [Token] = []
    var buffer = ""
    var hasDot = false
    func flush() {
      if let n = Double(buffer) { out.append(.number(CGFloat(n))) }
      buffer = ""
      hasDot = false
    }
    for ch in d {
      if ch.isLetter && ch != "e" && ch != "E" {
        flush()
        out.append(.command(ch))
      } else if ch == "-" {
        if buffer.last == "e" || buffer.last == "E" {
          buffer.append(ch)
        } else {
          flush()
          buffer = "-"
        }
      } else if ch == "." {
        if hasDot { flush() }
        buffer.append(ch)
        hasDot = true
      } else if ch.isNumber || ch == "e" || ch == "E" {
        buffer.append(ch)
      } else {
        flush()
      }
    }
    flush()
    return out
  }
}

/// 48×48 görünüm kutusundaki SVG yolunu verilen boyuta ölçekleyen şekil.
struct SVGShape: Shape {
  let d: String
  var viewBox: CGFloat = 48

  func path(in rect: CGRect) -> Path {
    let scale = min(rect.width, rect.height) / viewBox
    return SVGPath.parse(d).applying(CGAffineTransform(scaleX: scale, y: scale))
  }
}
