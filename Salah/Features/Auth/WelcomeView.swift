import SafariServices
import SwiftUI

/// Giriş seçenekleri. RN: screens/auth/WelcomeScreen.tsx
struct WelcomeView: View {
  @Environment(\.tokens) private var tokens
  @State private var social = SocialAuthModel()
  @State private var error: String?

  private static let termsURL = URL(string: "https://onuryilmaaz.github.io/Salah-privacy-terms/#terms")!
  private static let privacyURL = URL(string: "https://onuryilmaaz.github.io/Salah-privacy-terms/#privacy")!

  var body: some View {
    let dark = tokens.isDark
    GeometryReader { geo in
    ScrollView {
    VStack(alignment: .leading, spacing: 0) {
      CrescentMoon(size: 64)

      (Text(t("auth.welcome.line1") + "\n" + t("auth.welcome.line2") + "\n")
        .foregroundStyle(dark ? .white : Forest.s900)
        + Text(t("auth.welcome.accent")).foregroundStyle(dark ? Accent.s400 : Accent.s700))
        .font(.system(size: 40, weight: .semibold))
        .tracking(-0.5)
        .lineSpacing(4)
        .padding(.top, 28)

      Text(t("auth.welcome.subtitle"))
        .font(.system(size: 17))
        .lineSpacing(6)
        .foregroundStyle(dark ? Forest.s400 : Forest.s500)
        .frame(maxWidth: 300, alignment: .leading)
        .padding(.top, 17.5)

      if let error, !error.isEmpty {
        ErrorBanner(message: error).padding(.top, 17.5)
      }

      Spacer(minLength: 24)

      VStack(spacing: 10.5) {
        socialButton(.apple) {
          HStack(spacing: 10.5) {
            Ionicon("logo-apple", size: 20, color: dark ? Forest.s950 : .white)
            Text(t("auth.welcome.apple")).font(.system(size: 17, weight: .bold)).foregroundStyle(dark ? Forest.s950 : .white)
          }
          .frame(maxWidth: .infinity, minHeight: 49)
          .background(dark ? .white : Color(hex: 0x132e29), in: .rect(cornerRadius: 14))
        }

        socialButton(.google) {
          HStack(spacing: 10.5) {
            GoogleIcon(size: 19)
            Text(t("auth.welcome.google")).font(.system(size: 17, weight: .bold)).foregroundStyle(dark ? .white : Forest.s900)
          }
          .frame(maxWidth: .infinity, minHeight: 49)
          .background(dark ? Color.white.opacity(0.06) : .white, in: .rect(cornerRadius: 21))
          .overlay(RoundedRectangle(cornerRadius: 21).stroke(dark ? Color.white.opacity(0.1) : Forest.s200, lineWidth: 1))
        }

        Button {
          Haptics.impact(.light)
          AuthFlow.shared.path.append(.login)
        } label: {
          HStack(spacing: 10.5) {
            Ionicon("mail-outline", size: 20, color: dark ? Forest.s400 : Forest.s600)
            Text(t("auth.welcome.email")).font(.system(size: 17, weight: .bold)).foregroundStyle(dark ? Forest.s300 : Forest.s600)
          }
          .frame(maxWidth: .infinity, minHeight: 49)
          .background(dark ? Color.clear : Color.white.opacity(0.6), in: .rect(cornerRadius: 21))
          .overlay(RoundedRectangle(cornerRadius: 21).stroke(dark ? Color.white.opacity(0.1) : Forest.s200, lineWidth: 1))
        }
        .buttonStyle(PressableStyle(pressedOpacity: 0.85))
        .disabled(social.loading != nil)
      }

      terms
        .padding(.top, 21)
        .padding(.horizontal, 14)
    }
    .padding(.horizontal, 21)
    .padding(.top, 40)
    .padding(.bottom, 16)
    .frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: .topLeading)
    }
    .scrollBounceBehavior(.basedOnSize)
    }
    .background(dark ? Forest.s950 : Color(hex: 0xf6f8f7))
    .toolbar(.hidden, for: .navigationBar)
    .statusBar(.auto)
  }

  private func socialButton<Label: View>(_ provider: SocialAuthModel.Provider, @ViewBuilder label: () -> Label) -> some View {
    Button {
      Haptics.impact(.light)
      Task { await social.signIn(provider) { error = $0 } }
    } label: {
      label()
        .overlay {
          if social.loading == provider {
            ProgressView().tint(provider == .apple ? (tokens.isDark ? Forest.s950 : .white) : Accent.s600)
          }
        }
    }
    .buttonStyle(PressableStyle(pressedOpacity: 0.85))
    .disabled(social.loading != nil)
  }

  private var terms: some View {
    let muted = tokens.isDark ? Forest.s500 : Forest.s400
    let link = tokens.isDark ? Forest.s400 : Forest.s500
    var text = AttributedString(t("auth.welcome.termsPrefix") + " ")
    var termsLink = AttributedString(t("auth.welcome.terms"))
    termsLink.link = Self.termsURL
    termsLink.underlineStyle = .single
    termsLink.foregroundColor = link
    var privacyLink = AttributedString(t("auth.welcome.privacy"))
    privacyLink.link = Self.privacyURL
    privacyLink.underlineStyle = .single
    privacyLink.foregroundColor = link
    text += termsLink + AttributedString(" " + t("auth.welcome.and") + " ") + privacyLink + AttributedString(t("auth.welcome.termsSuffix"))
    return Text(text)
      .font(.system(size: 13))
      .lineSpacing(4)
      .foregroundStyle(muted)
      .tint(link)
      .multilineTextAlignment(.center)
      .frame(maxWidth: .infinity)
      .environment(\.openURL, OpenURLAction { url in
        InAppBrowser.open(url)
        return .handled
      })
  }
}

/// Bağlantıyı uygulama içi Safari'de açar (RN'deki expo-web-browser).
enum InAppBrowser {
  static func open(_ url: URL) {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    guard var top = scenes.flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController else { return }
    while let presented = top.presentedViewController { top = presented }
    top.present(SFSafariViewController(url: url), animated: true)
  }
}
