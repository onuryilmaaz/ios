import SwiftUI
import Testing
import UIKit
@testable import Salah

/// Paylaşılan kart görselinde köşe ve alt kenar saydam kalmamalı (paylaşılan uygulamalarda beyaz görünür).
@MainActor
struct ShareImageTests {
  /// Yuvarlak köşeli, yüksekliği tam piksele denk gelmeyen kart (ImageRenderer'ın verdiği gibi).
  private func card() -> UIImage {
    let content = RoundedRectangle(cornerRadius: 21).fill(Accent.s900).frame(width: 300, height: 400.3)
    let renderer = ImageRenderer(content: content)
    renderer.scale = 3
    return renderer.uiImage!
  }

  private func alpha(_ image: UIImage, x: Int, y: Int) -> UInt8 {
    let cg = image.cgImage!
    var pixel = [UInt8](repeating: 0, count: 4)
    let ctx = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.draw(cg, in: CGRect(x: -x, y: y - cg.height + 1, width: cg.width, height: cg.height))
    return pixel[3]
  }

  @Test func cornersAndBottomRowAreOpaque() {
    let raw = card()
    let cg = raw.cgImage!
    #expect(alpha(raw, x: 0, y: 0) < 255)  // ham görselde köşe saydam
    let fixed = ShareImage.opaque(raw)
    let out = fixed.cgImage!
    #expect(out.height <= cg.height)
    for (x, y) in [(0, 0), (out.width - 1, 0), (0, out.height - 1), (out.width - 1, out.height - 1), (out.width / 2, out.height - 1)] {
      #expect(alpha(fixed, x: x, y: y) == 255)
    }
  }
}
