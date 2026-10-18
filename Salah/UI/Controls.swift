import SwiftUI

/// RN `<Button>`: tam yuvarlak (pill), `h-12` = 42 pt (NativeWind'de rem 14: 1 birim 3,5 pt).
/// RN: components/ui/Button.tsx
struct AppButton: View {
  enum Variant { case primary, secondary, danger, outline }

  @Environment(\.tokens) private var tokens
  let title: String
  var variant: Variant = .primary
  var loading = false
  var disabled = false
  var prominent = false
  let action: () -> Void

  var body: some View {
    let isDisabled = loading || disabled
    Button(action: action) {
      Group {
        if loading {
          ProgressView().tint(loaderColor)
        } else {
          Text(title)
            .font(.system(size: prominent ? 17 : 15, weight: .semibold))
            .foregroundStyle(textColor)
            .lineLimit(1)
        }
      }
      .padding(.horizontal, 21)
      .frame(maxWidth: .infinity, minHeight: prominent ? 52 : 42)
      .background(background, in: .capsule)
      .overlay {
        if variant == .outline {
          Capsule().stroke(tokens.isDark ? Forest.s700 : Forest.s300, lineWidth: 1)
        }
      }
      .opacity(isDisabled ? 0.5 : 1)
    }
    .buttonStyle(PressableStyle(pressedOpacity: 0.8))
    .disabled(isDisabled)
  }

  private var background: Color {
    switch variant {
    case .primary: tokens.accent
    case .secondary: tokens.fill
    case .danger: tokens.isDark ? Color(hex: 0xef4444) : Color(hex: 0xdc2626)
    case .outline: .clear
    }
  }

  private var textColor: Color {
    switch variant {
    case .primary: tokens.isDark ? Forest.s950 : .white
    case .secondary, .outline: tokens.isDark ? Forest.s100 : Forest.s900
    case .danger: .white
    }
  }

  private var loaderColor: Color {
    switch variant {
    case .primary: tokens.onAccent
    case .danger: .white
    default: tokens.inkMuted
    }
  }
}

/// RN `<Input>`: etiket, `h-12` (42 pt) alan, odakta vurgu kenarlığı, hata metni; altta `mb-4` (14 pt).
/// `isPassword` göz düğmesiyle gizle/göster ekler. RN: components/ui/Input.tsx
struct InputField: View {
  @Environment(\.tokens) private var tokens
  var label: String?
  var placeholder = ""
  @Binding var text: String
  var keyboard: UIKeyboardType = .default
  var error: String?
  var maxLength: Int?
  var leftIcon: String?
  var isPassword = false
  var contentType: UITextContentType?
  var prominent = false
  @FocusState private var focused: Bool
  @State private var revealed = false

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if let label {
        FieldLabel(label)
      }
      HStack(spacing: 8.75) {
        if let leftIcon {
          Ionicon(leftIcon, size: 18, color: tokens.inkSubtle)
        }
        Group {
          if isPassword && !revealed {
            SecureField("", text: $text, prompt: prompt)
          } else {
            TextField("", text: $text, prompt: prompt)
          }
        }
        .font(.system(size: prominent ? 16 : 14))
        .foregroundStyle(tokens.textPrimary)
        .tint(tokens.accent)
        .keyboardType(keyboard)
        .textContentType(contentType)
        .textInputAutocapitalization(keyboard == .emailAddress || isPassword ? .never : .sentences)
        .autocorrectionDisabled(keyboard == .emailAddress || isPassword)
        .focused($focused)
        if isPassword {
          Button {
            revealed.toggle()
          } label: {
            Ionicon(revealed ? "eye-outline" : "eye-off-outline", size: 20, color: tokens.inkSubtle)
          }
          .buttonStyle(PressableStyle())
          .accessibilityLabel(t(revealed ? "input.hidePassword" : "input.showPassword"))
        }
      }
      .padding(.horizontal, prominent ? 16 : 14)
      .frame(height: prominent ? 54 : 42)
      .background(tokens.isDark ? Forest.s900 : .white, in: .rect(cornerRadius: prominent ? 14 : 10.5))
      .overlay(RoundedRectangle(cornerRadius: prominent ? 14 : 10.5).stroke(borderColor, lineWidth: 1))
      .contentShape(.rect)
      .onTapGesture { focused = true }
      .onChange(of: text) { _, value in
        if let maxLength, value.count > maxLength { text = String(value.prefix(maxLength)) }
      }
      if let error {
        Text(error)
          .font(.system(size: 13))
          .foregroundStyle(tokens.isDark ? Color(hex: 0xf87171) : Color(hex: 0xdc2626))
          .padding(.top, 5.25)
      }
    }
    .padding(.bottom, 14)
  }

  private var prompt: Text { Text(placeholder).foregroundStyle(tokens.inkSubtle) }

  private var borderColor: Color {
    if error != nil { return tokens.isDark ? Color(hex: 0xf87171) : Color(hex: 0xef4444) }
    if focused { return tokens.accent }
    return tokens.isDark ? Forest.s700 : Forest.s200
  }
}

/// Form alanı etiketi: 13 pt, orta kalınlık.
struct FieldLabel: View {
  @Environment(\.tokens) private var tokens
  let text: String
  init(_ text: String) { self.text = text }

  var body: some View {
    Text(text)
      .font(.system(size: 13, weight: .medium))
      .foregroundStyle(tokens.isDark ? Forest.s300 : Forest.s600)
      .padding(.bottom, 5.25)
  }
}

/// Seçim çipi (nafile/oruç türü vb.).
struct Chip: View {
  @Environment(\.tokens) private var tokens
  let title: String
  let selected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(selected ? (tokens.isDark ? Forest.s950 : .white) : (tokens.isDark ? Forest.s300 : Forest.s700))
        .padding(.horizontal, 12.25)
        .padding(.vertical, 7)
        .background(selected ? tokens.accent : tokens.fill, in: .capsule)
    }
    .buttonStyle(PressableStyle())
    .accessibilityAddTraits(selected ? .isSelected : [])
  }
}

/// Bölüm etiketi: büyük harf/eyebrow yok, 13 pt.
struct SectionLabel: View {
  @Environment(\.tokens) private var tokens
  let text: String
  init(_ text: String) { self.text = text }

  var body: some View {
    Text(text)
      .font(.system(size: 13, weight: .medium))
      .foregroundStyle(tokens.textSecondary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.leading, 3.5)
      .padding(.bottom, 7)
  }
}

/// Satırları ince çizgiyle ayrılmış kart (liste grupları).
struct GroupedCard<Content: View>: View {
  @Environment(\.tokens) private var tokens
  @ViewBuilder var content: Content

  var body: some View {
    VStack(spacing: 0) { content }
      .background(tokens.surface, in: .rect(cornerRadius: 21))
      .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
  }
}

/// Liste satırları arasındaki 1 pt çizgi (`ml-4 h-px bg-slate-100 dark:bg-slate-800`).
struct RowDivider: View {
  @Environment(\.tokens) private var tokens
  var leading: CGFloat = 14

  var body: some View {
    Rectangle()
      .fill(tokens.isDark ? Forest.s800 : Forest.s100)
      .frame(height: 1)
      .padding(.leading, leading)
  }
}

/// Basit akış (sarma) yerleşimi: çipler satır sığmazsa alta geçer.
struct FlowLayout: Layout {
  var spacing: CGFloat = 8

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let width = proposal.width ?? .infinity
    var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
    for view in subviews {
      let size = view.sizeThatFits(.unspecified)
      if x > 0 && x + size.width > width {
        x = 0
        y += rowHeight + spacing
        rowHeight = 0
      }
      x += size.width + spacing
      maxX = max(maxX, x - spacing)
      rowHeight = max(rowHeight, size.height)
    }
    // Ölçüm ve yerleştirme aynı genişliği kullanmalı; daralan bounds ek satır
    // oluşturup alttaki etiketin üstüne taşabiliyordu. RTL'yi SwiftUI aynalar.
    return CGSize(width: width.isFinite ? width : maxX, height: y + rowHeight)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
    for view in subviews {
      let size = view.sizeThatFits(.unspecified)
      if x > bounds.minX && x + size.width > bounds.maxX {
        x = bounds.minX
        y += rowHeight + spacing
        rowHeight = 0
      }
      view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
      x += size.width + spacing
      rowHeight = max(rowHeight, size.height)
    }
  }
}
