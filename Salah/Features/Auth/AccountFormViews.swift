import SwiftUI

/// Hesap oluşturma. RN: screens/auth/RegisterScreen.tsx
struct RegisterView: View {
  @Environment(\.tokens) private var tokens
  @State private var firstName = ""
  @State private var lastName = ""
  @State private var email = ""
  @State private var password = ""
  @State private var loading = false
  @State private var error: String?
  @State private var social = SocialAuthModel()

  var body: some View {
    EmailAuthLayout(title: t("auth.register.title"), subtitle: t("auth.register.subtitle"), compact: true) {
      VStack(alignment: .leading, spacing: 0) {
        if let error, !error.isEmpty { ErrorBanner(message: error).padding(.bottom, 18) }

        HStack(alignment: .top, spacing: 12) {
          InputField(label: t("auth.register.firstName"), placeholder: t("auth.register.firstNamePh"), text: $firstName, contentType: .givenName, prominent: true)
          InputField(label: t("auth.register.lastName"), placeholder: t("auth.register.lastNamePh"), text: $lastName, contentType: .familyName, prominent: true)
        }
        InputField(label: t("auth.email"), placeholder: t("auth.emailPlaceholder"), text: $email, keyboard: .emailAddress, contentType: .emailAddress, prominent: true)
        InputField(label: t("auth.password"), placeholder: t("auth.register.passwordPh"), text: $password, isPassword: true, contentType: .newPassword, prominent: true)

        AppButton(title: t(loading ? "auth.register.submitting" : "auth.register.submit"), loading: loading, disabled: social.loading != nil, prominent: true) {
          Task { await register() }
        }
        .padding(.top, 10)

        SocialButtons(model: social) { error = $0 }

        HStack(spacing: 0) {
          Text(t("auth.register.haveAccount"))
            .font(.system(size: 14))
            .foregroundStyle(tokens.isDark ? Forest.s300 : Forest.s600)
          LinkText(title: t("auth.signIn"), size: 14) {
            AuthFlow.shared.path.removeLast()
            AuthFlow.shared.path.append(.login)
          }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
      }
    }
  }

  private func register() async {
    guard !email.isEmpty, !password.isEmpty, !firstName.isEmpty, !lastName.isEmpty else {
      error = t("auth.register.required")
      return
    }
    loading = true
    error = nil
    defer { loading = false }
    do {
      let res = try await AuthAPI.register(email: email.trimmingCharacters(in: .whitespaces), password: password, firstName: firstName, lastName: lastName)
      if res.user?.emailVerified != true {
        AuthFlow.shared.path.append(.otp(email: email, password: password))
      } else {
        AuthFlow.shared.path.removeLast()
        AuthFlow.shared.path.append(.login)
      }
    } catch {
      self.error = (error as? APIError)?.serverMessage ?? t("auth.register.failed")
    }
  }
}

/// Kayıt kartındaki "veya" + Google/Apple düğmeleri. RN: components/auth/SocialAuth.tsx
private struct SocialButtons: View {
  @Environment(\.tokens) private var tokens
  let model: SocialAuthModel
  let onError: (String?) -> Void

  var body: some View {
    let dark = tokens.isDark
    VStack(spacing: 10.5) {
      OrDivider().padding(.vertical, 7)

      Button {
        Task { await model.signIn(.google, onError: onError) }
      } label: {
        HStack(spacing: 10.5) {
          GoogleIcon(size: 18)
          Text(t("auth.welcome.google")).font(.system(size: 14, weight: .semibold)).foregroundStyle(dark ? .white : Forest.s800)
        }
        .opacity(model.loading == .google ? 0 : 1)
        .overlay { if model.loading == .google { ProgressView().tint(Accent.s600) } }
        .frame(maxWidth: .infinity, minHeight: 42)
        .background(dark ? Forest.s900.opacity(0.5) : .white, in: .rect(cornerRadius: 21))
        .overlay(RoundedRectangle(cornerRadius: 21).stroke(dark ? Color.white.opacity(0.1) : Forest.s200, lineWidth: 1))
      }
      .buttonStyle(PressableStyle(pressedOpacity: 0.8))

      Button {
        Task { await model.signIn(.apple, onError: onError) }
      } label: {
        HStack(spacing: 10.5) {
          Ionicon("logo-apple", size: 20, color: dark ? .black : .white)
          Text(t("auth.welcome.apple")).font(.system(size: 14, weight: .semibold)).foregroundStyle(dark ? .black : .white)
        }
        .opacity(model.loading == .apple ? 0 : 1)
        .overlay { if model.loading == .apple { ProgressView().tint(dark ? .black : .white) } }
        .frame(maxWidth: .infinity, minHeight: 42)
        .background(dark ? .white : .black, in: .rect(cornerRadius: 14))
      }
      .buttonStyle(PressableStyle(pressedOpacity: 0.8))
    }
    .padding(.top, 14)
    .disabled(model.loading != nil)
  }
}

/// E-posta doğrulama kodu. RN: screens/auth/OtpScreen.tsx
struct OtpView: View {
  let email: String
  let password: String?
  @State private var code = ""
  @State private var loading = false
  @State private var error: String?
  @State private var message: String?

  var body: some View {
    AuthLayout(title: t("auth.otp.title"), subtitle: t("auth.otp.subtitle", ["email": email]), icon: "shield-checkmark", showBack: true) {
      AuthCard {
        if let error { ErrorBanner(message: error).padding(.bottom, 14) }
        if let message { SuccessBanner(message: message).padding(.bottom, 14) }

        OtpInput(value: $code) { full in Task { await verify(full) } }
          .padding(.bottom, 21)

        AppButton(title: t("auth.otp.verify"), loading: loading, disabled: code.count != 6) {
          Task { await verify(code) }
        }

        LinkText(title: t("auth.otp.resend"), weight: .semibold) { Task { await resend() } }
          .frame(maxWidth: .infinity)
          .padding(.top, 17.5)
          .disabled(loading)
      }
    }
  }

  private func verify(_ value: String) async {
    guard value.count == 6 else {
      error = t("auth.otp.enterCode")
      return
    }
    guard !loading else { return }
    loading = true
    error = nil
    message = nil
    defer { loading = false }
    do {
      try await AuthAPI.verifyEmail(email: email, code: value)
      if let password, let res = try? await AuthAPI.login(email: email, password: password) {
        await AuthStore.shared.login(res)
      } else {
        AuthFlow.shared.path = [.login]
      }
    } catch {
      let server = (error as? APIError)?.serverMessage
      self.error = server == "Invalid or expired code" ? t("auth.otp.invalid") : t("auth.otp.failed")
      code = ""
    }
  }

  private func resend() async {
    loading = true
    error = nil
    defer { loading = false }
    do {
      try await AuthAPI.resendEmailOtp(email: email)
      message = t("auth.otp.sent")
    } catch {
      self.error = t("auth.otp.sendFailed")
    }
  }
}

/// Şifre sıfırlama kodu isteme. RN: screens/auth/ForgotPasswordScreen.tsx
struct ForgotPasswordView: View {
  @State private var email = ""
  @State private var loading = false
  @State private var error: String?

  var body: some View {
    AuthLayout(title: t("auth.forgot.title"), subtitle: t("auth.forgot.subtitle"), icon: "lock-closed", showBack: true) {
      AuthCard {
        if let error { ErrorBanner(message: error).padding(.bottom, 14) }
        InputField(label: t("auth.email"), placeholder: t("auth.emailPlaceholder"), text: $email, keyboard: .emailAddress, contentType: .emailAddress)
        AppButton(title: t(loading ? "auth.forgot.sending" : "auth.forgot.send"), loading: loading) {
          Task { await send() }
        }
        .padding(.top, 7)
      }
    }
  }

  private func send() async {
    guard !email.isEmpty else {
      error = t("auth.emailRequired")
      return
    }
    loading = true
    error = nil
    defer { loading = false }
    do {
      try await AuthAPI.forgotPassword(email: email.trimmingCharacters(in: .whitespaces))
      AuthFlow.shared.path.append(.reset(email: email))
    } catch {
      self.error = t("auth.requestFailed")
    }
  }
}

/// Kod + yeni şifre. RN: screens/auth/ResetPasswordScreen.tsx
struct ResetPasswordView: View {
  @Environment(\.tokens) private var tokens
  let email: String
  @State private var code = ""
  @State private var newPassword = ""
  @State private var confirm = ""
  @State private var step = Step.otp
  @State private var loading = false
  @State private var error: String?

  private enum Step { case otp, password }

  var body: some View {
    AuthLayout(
      title: t(step == .otp ? "auth.reset.titleOtp" : "auth.reset.titleNew"),
      subtitle: step == .otp ? t("auth.otp.subtitle", ["email": email]) : t("auth.reset.subtitleNew"),
      icon: "key",
      showBack: true,
      onBack: step == .password ? { step = .otp } : nil
    ) {
      AuthCard {
        if let error { ErrorBanner(message: error).padding(.bottom, 14) }

        if step == .otp {
          OtpInput(value: $code) { _ in step = .password }
            .padding(.bottom, 21)
          AppButton(title: t("auth.reset.continue"), disabled: code.count != 6) {
            guard code.count == 6 else {
              error = t("auth.otp.enterCode")
              return
            }
            error = nil
            step = .password
          }
        } else {
          InputField(label: t("auth.reset.newPassword"), placeholder: t("auth.reset.newPasswordPh"), text: $newPassword, isPassword: true, contentType: .newPassword)
          InputField(label: t("auth.reset.confirm"), placeholder: t("auth.reset.confirmPh"), text: $confirm, isPassword: true, contentType: .newPassword)
          AppButton(title: t(loading ? "auth.reset.updating" : "auth.reset.update"), loading: loading) {
            Task { await reset() }
          }
          .padding(.top, 7)
          Button {
            step = .otp
            error = nil
          } label: {
            HStack(spacing: 3.5) {
              Ionicon(dirIcon("arrow-back"), size: 16, color: tokens.isDark ? Forest.s400 : Forest.s500)
              Text(t("auth.reset.changeCode"))
                .font(.system(size: 12.25, weight: .medium))
                .foregroundStyle(tokens.textSecondary)
            }
            .frame(maxWidth: .infinity)
          }
          .buttonStyle(PressableStyle())
          .padding(.top, 14)
        }
      }
    }
  }

  private func reset() async {
    guard !newPassword.isEmpty, !confirm.isEmpty else {
      error = t("auth.register.required")
      return
    }
    guard newPassword == confirm else {
      error = t("auth.reset.mismatch")
      return
    }
    guard newPassword.count >= 6 else {
      error = t("auth.reset.tooShort")
      return
    }
    loading = true
    error = nil
    defer { loading = false }
    do {
      try await AuthAPI.resetPassword(email: email, otp: code, newPassword: newPassword)
      AuthFlow.shared.path = [.login]
    } catch {
      self.error = (error as? APIError)?.serverMessage ?? t("auth.reset.failed")
      step = .otp
      code = ""
    }
  }
}
