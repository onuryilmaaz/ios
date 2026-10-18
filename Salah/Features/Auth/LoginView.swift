import SwiftUI

/// E-posta ile giriş. RN: screens/auth/LoginScreen.tsx
struct LoginView: View {
  @Environment(\.tokens) private var tokens
  @State private var email = ""
  @State private var password = ""
  @State private var loading = false
  @State private var error: String?
  @State private var social = SocialAuthModel()

  var body: some View {
    let dark = tokens.isDark
    let busy = loading || social.loading != nil
    EmailAuthLayout(title: t("auth.login.welcome"), subtitle: t("auth.login.subtitle")) {
      VStack(alignment: .leading, spacing: 0) {
        if let error, !error.isEmpty {
          ErrorBanner(message: error).padding(.bottom, 18)
        }

        InputField(
          label: t("auth.email"), placeholder: t("auth.emailPlaceholder"), text: $email,
          keyboard: .emailAddress, leftIcon: "mail-outline", contentType: .username,
          prominent: true
        )
        InputField(
          label: t("auth.password"), placeholder: "••••••••", text: $password,
          leftIcon: "lock-closed-outline", isPassword: true, contentType: .password,
          prominent: true
        )

        LinkText(title: t("auth.login.forgot"), size: 14, weight: .semibold) {
          AuthFlow.shared.path.append(.forgot)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.top, 2)
        .padding(.bottom, 24)

        AppButton(title: t("auth.login.submit"), loading: loading, disabled: busy, prominent: true) {
          Haptics.impact(.medium)
          Task { await login() }
        }

        OrDivider(muted: true).padding(.vertical, 24)

        HStack(spacing: 10.5) {
          socialButton(.apple) {
            Ionicon("logo-apple", size: 18, color: dark ? .white : Forest.s900)
            Text(verbatim: "Apple").font(.system(size: 15, weight: .bold)).foregroundStyle(dark ? .white : Forest.s900)
          }
          socialButton(.google) {
            GoogleIcon(size: 17)
            Text(verbatim: "Google").font(.system(size: 15, weight: .bold)).foregroundStyle(dark ? .white : Forest.s900)
          }
        }
        .disabled(busy)

        HStack(spacing: 0) {
          Text(t("auth.login.noAccount"))
            .font(.system(size: 15))
            .foregroundStyle(tokens.textSecondary)
          LinkText(title: t("auth.register.submit"), size: 15, weight: .semibold) {
            AuthFlow.shared.path.append(.register)
          }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 30)
      }
    }
  }

  private func socialButton<Content: View>(_ provider: SocialAuthModel.Provider, @ViewBuilder content: () -> Content) -> some View {
    let dark = tokens.isDark
    return Button {
      Task { await social.signIn(provider) { error = $0 } }
    } label: {
      HStack(spacing: 8.75) { content() }
        .opacity(social.loading == provider ? 0 : 1)
        .overlay {
          if social.loading == provider { ProgressView().tint(provider == .apple ? (dark ? .white : Forest.s900) : Accent.s600) }
        }
        .frame(maxWidth: .infinity, minHeight: 42)
        .background(dark ? Color.white.opacity(0.06) : .white, in: .rect(cornerRadius: 21))
        .overlay(RoundedRectangle(cornerRadius: 21).stroke(dark ? Color.white.opacity(0.1) : Forest.s200, lineWidth: 1))
    }
    .buttonStyle(PressableStyle(pressedOpacity: 0.85))
  }

  private func login() async {
    guard !email.isEmpty, !password.isEmpty else {
      error = t("auth.login.required")
      return
    }
    loading = true
    error = nil
    defer { loading = false }
    do {
      let res = try await AuthAPI.login(email: email.trimmingCharacters(in: .whitespaces), password: password)
      if res.user.emailVerified == false {
        AuthFlow.shared.path.removeLast()
        AuthFlow.shared.path.append(.otp(email: email, password: password))
        return
      }
      await AuthStore.shared.login(res)
    } catch let api as APIError {
      if let message = api.serverMessage {
        error = message
      } else {
        error = switch api.status {
        case 401: t("auth.login.invalid")
        case 403: t("auth.login.inactive")
        case 423: t("auth.login.locked")
        default: t("auth.login.failed")
        }
      }
    } catch {
      self.error = t("auth.login.failed")
    }
  }
}
