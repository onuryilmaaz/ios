import SwiftUI

enum QuranScripture {
  static let basmala = "بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ"
}

struct QuranArabicText: View {
  var text: String
  var segments: [TajweedSegment]? = nil
  var color: Color
  var accent: Color
  var size: Double
  var body: some View {
    Self.styled(text: text, segments: segments, color: color, accent: accent, size: size)
      .lineSpacing(size).multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading)
      .environment(\.layoutDirection, .rightToLeft)
  }
  static func styled(text: String, segments: [TajweedSegment]?, color: Color, accent: Color, size: Double) -> Text {
    guard let segments, !segments.isEmpty else { return Text(QuranFont.text(text)).font(.custom(QuranFont.name, size: size)).foregroundColor(color) }
    return segments.reduce(Text("")) { result, segment in
      let tint = segment.rule == "end" ? accent : segment.rule.flatMap { TajweedColors.values[$0] }.map { Color(hex: $0) } ?? color
      return result + Text(QuranFont.text(segment.text)).font(.custom(QuranFont.name, size: size)).foregroundColor(tint)
    }
  }
}

struct TajweedLegendView: View {
  @Environment(\.tokens) private var tokens
  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      Text(t("tajweed.legendTitle")).font(.system(size: 12, weight: .medium)).foregroundStyle(tokens.inkSubtle)
      FlowLayout {
        ForEach(TajweedColors.legend, id: \.0) { item in
          HStack(spacing: 5.25) {
            Circle().fill(Color(hex: item.1)).frame(width: 8.75, height: 8.75)
            Text(t("tajweed.\(item.0)")).font(.system(size: 12, weight: .semibold)).foregroundStyle(tokens.textSecondary)
          }
        }
      }
    }.padding(10.5).background(tokens.surface, in: .rect(cornerRadius: 21))
      .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1)).accessibilityLabel(t("tajweed.legendA11y"))
  }
}

/// RN MushafFrame: çift kenarlık ve köşe palmetleri. Renk okuma temasından gelir.
struct MushafDecorativeFrame: View {
  var color: Color
  var body: some View {
    GeometryReader { geometry in
      ZStack {
        RoundedRectangle(cornerRadius: 18).stroke(color, lineWidth: 2.4).padding(7)
        RoundedRectangle(cornerRadius: 10.5).stroke(color.opacity(0.45), lineWidth: 1).padding(13)
        ForEach(0..<4) { corner in
          SVGShape(d: "M0 0 C26 3 31 12 31 31 C12 31 3 26 0 0 Z")
            .fill(color.opacity(0.12)).frame(width: 32, height: 32)
            .overlay(SVGShape(d: "M2 2 C24 5 28 13 28 28 M8 8 C19 9 22 13 22 22").stroke(color.opacity(0.6), lineWidth: 1.4))
            .rotationEffect(.degrees(Double(corner) * 90))
            .position(x: corner == 0 || corner == 3 ? 31 : geometry.size.width - 31,
                      y: corner < 2 ? 31 : geometry.size.height - 31)
        }
        ForEach(0..<2) { side in
          SVGShape(d: "M0 0 C-9 6 -9 16 0 20 C9 16 9 6 0 0 Z")
            .fill(color.opacity(0.25)).frame(width: 20, height: 20)
            .rotationEffect(.degrees(side == 0 ? 0 : 180))
            .position(x: geometry.size.width / 2, y: side == 0 ? 23 : geometry.size.height - 23)
        }
      }
    }.allowsHitTesting(false).accessibilityHidden(true)
  }
}
