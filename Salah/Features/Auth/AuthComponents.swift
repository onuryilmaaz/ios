import SwiftUI

/// 6 haneli kod girişi. Tek gizli alan; kutular yalnız gösterim (yapıştırma ve
/// SMS/e-posta kodu otomatik doldurma da çalışır). RN: components/ui/OtpInput.tsx
struct OtpInput: View {
  @Environment(\.tokens) private var tokens
  var length = 6
  @Binding var value: String
  var onComplete: (String) -> Void = { _ in }
  @FocusState private var focused: Bool

  var body: some View {
    ZStack {
      TextField("", text: $value)
        .keyboardType(.numberPad)
        .textContentType(.oneTimeCode)
        .focused($focused)
        .opacity(0.02)
        .onChange(of: value) { _, new in
          let digits = String(new.filter(\.isNumber).prefix(length))
          if digits != new { value = digits }
          if digits.count == length { onComplete(digits) }
        }

      HStack(spacing: 7) {
        ForEach(0..<length, id: \.self) { i in
          let chars = Array(value)
          let has = i < chars.count
          let isFocused = focused && i == min(chars.count, length - 1)
          Text(has ? String(chars[i]) : "")
            .font(.system(size: 21, weight: .bold))
            .foregroundStyle(tokens.isDark ? .white : Forest.s900)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(tokens.isDark ? Forest.s900.opacity(0.7) : .white, in: .rect(cornerRadius: 10.5))
            .overlay(
              RoundedRectangle(cornerRadius: 10.5).stroke(
                isFocused ? Accent.s500 : has ? (tokens.isDark ? Accent.s600 : Accent.s300) : tokens.line,
                lineWidth: 2))
        }
      }
      .allowsHitTesting(false)
    }
    .environment(\.layoutDirection, .leftToRight)
    .contentShape(.rect)
    .onTapGesture { focused = true }
    .onAppear { focused = true }
  }
}

/// Auth ekranlarının ortak tuvali: geri düğmesi, marka/ikon rozeti, başlık ve
/// ortalanmış içerik. RN: components/auth/AuthLayout.tsx
struct AuthLayout<Content: View>: View {
  @Environment(\.tokens) private var tokens
  @Environment(\.dismiss) private var dismiss
  let title: String
  var subtitle: String?
  var icon: String?
  var showBack = false
  var onBack: (() -> Void)?
  @ViewBuilder var content: Content

  var body: some View {
    GeometryReader { geo in
      ScrollView {
        VStack(spacing: 0) {
          VStack(spacing: 0) {
            if let icon {
              Ionicon(icon, size: 34, color: Gold.s300)
                .frame(width: 76, height: 76)
                .background(tokens.isDark ? Accent.s900 : Accent.s800, in: .circle)
            } else {
              AuthBrandMark()
            }
            Text(title)
              .font(.system(size: 28, weight: .semibold))
              .tracking(-0.5)
              .foregroundStyle(tokens.isDark ? .white : Forest.s900)
              .multilineTextAlignment(.center)
              .padding(.top, 17.5)
            if let subtitle, !subtitle.isEmpty {
              Text(subtitle)
                .font(.system(size: 15))
                .lineSpacing(5)
                .foregroundStyle(tokens.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
                .padding(.top, 7)
            }
          }
          .padding(.bottom, 24.5)

          content
        }
        .padding(.horizontal, 20)
        .padding(.top, 56)
        .padding(.bottom, 28)
        .frame(minHeight: geo.size.height)
      }
      .scrollDismissesKeyboard(.interactively)
      .scrollBounceBehavior(.basedOnSize)
    }
    .background(tokens.canvas)
    .overlay(alignment: .topLeading) {
      if showBack {
        Button {
          Haptics.impact(.light)
          if let onBack { onBack() } else { dismiss() }
        } label: {
          Ionicon(dirIcon("chevron-back"), size: 20, color: tokens.isDark ? Forest.s200 : Forest.s900)
            .frame(width: 35, height: 35)
            .background(tokens.surface, in: .circle)
            .overlay(Circle().stroke(tokens.line, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(t("common.back"))
        .padding(.leading, 18)
        .padding(.top, 10)
      }
    }
    .toolbar(.hidden, for: .navigationBar)
    .statusBar(.auto)
  }
}

/// E-posta ile giriş ve kayıt için karşılama ekranıyla aynı görsel düzen.
/// Sosyal giriş kontrolleri ve diğer auth adımları kendi düzenlerini korur.
struct EmailAuthLayout<Content: View>: View {
  @Environment(\.tokens) private var tokens
  @Environment(\.dismiss) private var dismiss
  let title: String
  let subtitle: String
  var compact = false
  @ViewBuilder var content: Content

  var body: some View {
    GeometryReader { geo in
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          CircleIconButton(
            icon: dirIcon("chevron-back"), size: 44, iconSize: 20,
            color: tokens.ink, accessibilityLabel: t("common.back")
          ) {
            Haptics.impact(.light)
            dismiss()
          }
          .accessibilityIdentifier("auth.back")

          CrescentMoon(size: 46)
            .frame(height: 54, alignment: .leading)
            .padding(.top, compact ? 20 : 32)

          Text(title)
            .font(.system(size: 36, weight: .semibold))
            .tracking(-0.6)
            .foregroundStyle(tokens.ink)
            .accessibilityAddTraits(.isHeader)
            .padding(.top, compact ? 16 : 24)

          Text(subtitle)
            .font(.system(size: 16))
            .lineSpacing(5)
            .foregroundStyle(tokens.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 10)
            .padding(.bottom, compact ? 24 : 34)

          content
        }
        .frame(maxWidth: 520, minHeight: geo.size.height, alignment: .topLeading)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 30)
      }
      .scrollDismissesKeyboard(.interactively)
      .scrollBounceBehavior(.basedOnSize)
    }
    .background(tokens.canvas)
    .toolbar(.hidden, for: .navigationBar)
    .statusBar(.auto)
  }
}

/// Beyaz/koyu yüzeyli form kartı (RN `<Card className="w-full border-slate-100 dark:border-white/10">`).
struct AuthCard<Content: View>: View {
  @Environment(\.tokens) private var tokens
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 0) { content }
      .padding(17.5)
      .frame(maxWidth: .infinity)
      .background(tokens.surface, in: .rect(cornerRadius: 21))
      .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.isDark ? Color.white.opacity(0.1) : Forest.s100, lineWidth: 1))
  }
}

/// "veya" ayırıcısı.
struct OrDivider: View {
  @Environment(\.tokens) private var tokens
  var muted = false

  var body: some View {
    HStack(spacing: 10.5) {
      line
      Text(t("auth.or"))
        .font(.system(size: 12.25, weight: .medium))
        .foregroundStyle(muted ? (tokens.isDark ? Forest.s500 : Forest.s400) : tokens.textSecondary)
      line
    }
  }

  private var line: some View {
    Rectangle().fill(tokens.isDark ? Color.white.opacity(0.1) : Forest.s200).frame(height: 1)
  }
}

/// Satır içi metin bağlantısı (ör. "Şifremi unuttum?").
struct LinkText: View {
  @Environment(\.tokens) private var tokens
  let title: String
  var size: CGFloat = 12.25
  var weight: Font.Weight = .bold
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
        .font(.system(size: size, weight: weight))
        .foregroundStyle(tokens.isDark ? Accent.s400 : Accent.s600)
    }
    .buttonStyle(PressableStyle())
  }
}
