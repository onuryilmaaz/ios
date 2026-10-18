import SwiftUI

/// RN `<Badge>`: yuvarlak etiket. RN: components/ui/Badge.tsx
struct Badge: View {
  enum Variant { case primary, success, warning, danger, info, neutral }
  enum Size { case sm, md, lg }

  @Environment(\.tokens) private var tokens
  let text: String
  var variant = Variant.primary
  var size = Size.md

  init(_ text: String, variant: Variant = .primary, size: Size = .md) {
    self.text = text
    self.variant = variant
    self.size = size
  }

  var body: some View {
    let dark = tokens.isDark
    let (bg, fg): (Color, Color) =
      switch variant {
      case .primary, .success: (dark ? Accent.s900 : Accent.s50, dark ? Accent.s300 : Accent.s700)
      case .warning: (dark ? Amber.s500.opacity(0.15) : Amber.s50, dark ? Amber.s300 : Amber.s700)
      case .danger: (dark ? Color(hex: 0xef4444).opacity(0.15) : Color(hex: 0xfef2f2), dark ? Color(hex: 0xfca5a5) : Color(hex: 0xb91c1c))
      case .info, .neutral: (dark ? Forest.s800 : Forest.s100, dark ? Forest.s300 : Forest.s700)
      }
    let (h, v, font): (CGFloat, CGFloat, CGFloat) =
      switch size {
      // NativeWind rem 14: px-2 py-0.5 / px-2.5 py-1 text-xs / px-3 py-1.5 text-sm
      case .sm: (7, 1.75, 12)
      case .md: (8.75, 3.5, 10.5)
      case .lg: (10.5, 5.25, 12.25)
      }
    Text(text)
      .font(.system(size: font, weight: .medium))
      .foregroundStyle(fg)
      .padding(.horizontal, h)
      .padding(.vertical, v)
      .background(bg, in: .capsule)
  }
}
