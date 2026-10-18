import SwiftUI

/// Oturum ve hesap işlemleri. RN: screens/user/AccountScreen.tsx
struct AccountView: View {
  @Environment(\.tokens) private var tokens
  @State private var deactivating = false
  @State private var deleting = false
  @State private var revoking = false

  var body: some View {
    VStack(spacing: 0) {
      StandardHeader(title: t("profile.account"))
      ScrollView {
        VStack(spacing: 14) {
          Card {
            sectionHeader(icon: "log-out-outline", title: t("account.signOut"), subtitle: t("account.signOutSub"), danger: false)
            AppButton(title: t("account.signOut"), variant: .outline) { confirmLogout() }
            AppButton(title: t("account.signOutOthersTitle"), variant: .secondary, loading: revoking) { confirmRevoke() }
              .padding(.top, 10.5)
          }

          dangerCard(border: tokens.isDark ? Color(hex: 0x7f1d1d) : Color(hex: 0xfecaca)) {
            sectionHeader(icon: "warning-outline", title: t("account.dangerZone"), subtitle: t("account.dangerSub"), danger: true)
            AppButton(title: t("account.deactivateTitle"), variant: .danger, loading: deactivating) { confirmDeactivate() }
          }

          dangerCard(border: tokens.isDark ? Color(hex: 0x7f1d1d) : Color(hex: 0xfca5a5)) {
            sectionHeader(icon: "trash-outline", title: t("account.deleteSection"), subtitle: t("account.deleteSectionSub"), danger: true)
            AppButton(title: t("account.deleteTitle"), variant: .danger, loading: deleting) { confirmDelete() }
          }
        }
        .padding(14)
        .padding(.bottom, 24)
      }
      .scrollIndicators(.hidden)
      .refreshable { await AuthStore.shared.refreshUser() }
    }
    .background(tokens.canvas)
    .toolbar(.hidden, for: .navigationBar)
  }

  private func sectionHeader(icon: String, title: String, subtitle: String, danger: Bool) -> some View {
    let dark = tokens.isDark
    return HStack(spacing: 10.5) {
      Ionicon(icon, size: 24, color: danger ? Color(hex: 0xdc2626) : (dark ? Accent.s500 : Accent.s600))
        .frame(width: 42, height: 42)
        .background(danger ? (dark ? Color(hex: 0xef4444).opacity(0.2) : Color(hex: 0xfee2e2)) : (dark ? Accent.s500.opacity(0.1) : Accent.s50), in: .circle)
      VStack(alignment: .leading, spacing: 0) {
        Text(title)
          .font(.system(size: 15.75, weight: .semibold))
          .foregroundStyle(danger ? (dark ? Color(hex: 0xf87171) : Color(hex: 0xb91c1c)) : (dark ? .white : Forest.s900))
        Text(subtitle)
          .font(.system(size: 12.25))
          .foregroundStyle(danger ? (dark ? Color(hex: 0xf87171).opacity(0.8) : Color(hex: 0xdc2626)) : (dark ? Forest.s300 : Forest.s500))
      }
      Spacer(minLength: 0)
    }
    .padding(.bottom, 14)
  }

  private func dangerCard<Content: View>(border: Color, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 0) { content() }
      .padding(17.5)
      .background(tokens.isDark ? Color(hex: 0xef4444).opacity(0.05) : Color(hex: 0xfef2f2), in: .rect(cornerRadius: 21))
      .overlay(RoundedRectangle(cornerRadius: 21).stroke(border, lineWidth: 1))
  }

  /// Çıkış sonrası ana sayfanın köküne dönülür (RN `rootResetToHome`).
  private func signOut() async {
    await AuthStore.shared.logout()
    HomeNavigation.shared.path.removeAll()
  }

  private func confirmLogout() {
    AppAlert.confirm(
      t("account.signOut"), t("account.signOutMessage"),
      confirmText: t("account.signOut"), cancelText: t("common.cancel"), destructive: true
    ) { await signOut() }
  }

  private func confirmRevoke() {
    AppAlert.confirm(
      t("account.signOutOthersTitle"), t("account.signOutOthersMessage"),
      confirmText: t("account.signOut"), cancelText: t("common.cancel"), destructive: true
    ) {
      revoking = true
      defer { revoking = false }
      do {
        try await UserAPI.revokeOtherSessions()
        AppAlert.success(t("common.success"), t("account.signedOutOthers"))
      } catch {
        AppAlert.error(t("common.error"), t("account.signOutOthersFailed"))
      }
    }
  }

  private func confirmDeactivate() {
    AppAlert.confirm(
      t("account.deactivateTitle"), t("account.deactivateMessage"),
      confirmText: t("account.deactivate"), cancelText: t("common.cancel"), destructive: true
    ) {
      deactivating = true
      defer { deactivating = false }
      do {
        try await UserAPI.deactivate()
        AppAlert.success(t("common.success"), t("account.deactivated"))
        await signOut()
      } catch {
        AppAlert.error(t("common.error"), t("account.deactivateFailed"))
      }
    }
  }

  private func confirmDelete() {
    guard let accountID = AuthStore.shared.user?.id, !deleting else { return }
    AppAlert.confirm(
      t("account.deleteTitle"), t("account.deleteMessage"),
      confirmText: t("account.continue"), cancelText: t("common.cancel"), destructive: true
    ) {
      // İkinci (son) onay: kalıcı işlem için ek güvenlik.
      AppAlert.confirm(
        t("account.finalConfirm"), t("account.deleteFinal"),
        confirmText: t("account.deleteConfirm"), cancelText: t("common.cancel"), destructive: true
      ) {
        guard AuthStore.shared.user?.id == accountID, !deleting else { return }
        deleting = true
        defer { deleting = false }
        // Apple ile kayıtlı hesap: Apple'daki yetki de iptal edilsin diye taze yetki kodu alınır.
        var appleCode: String?
        if AuthStore.shared.user?.authProvider == "apple" {
          do {
            appleCode = try await SocialSignIn.apple().authorizationCode
          } catch SocialSignIn.Failure.cancelled {
            return
          } catch {
            appleCode = nil
          }
        }
        guard AuthStore.shared.user?.id == accountID else { return }
        do {
          try await UserAPI.deleteAccount(appleAuthorizationCode: appleCode)
          AppAlert.success(t("account.deletedTitle"), t("account.deleted"))
          await signOut()
        } catch {
          AppAlert.error(t("common.error"), t("account.deleteFailed"))
        }
      }
    }
  }
}

/// Şifre değiştirme. RN: screens/user/ChangePasswordScreen.tsx
struct ChangePasswordView: View {
  @Environment(\.tokens) private var tokens
  @State private var current = ""
  @State private var new = ""
  @State private var loading = false

  var body: some View {
    VStack(spacing: 0) {
      StandardHeader(title: t("profile.changePassword"))
      ScrollView {
        Card {
          titleRow(icon: "lock-closed-outline", title: t("changePassword.title"), intro: t("changePassword.intro"))
          InputField(label: t("changePassword.current"), placeholder: t("changePassword.currentPlaceholder"), text: $current, isPassword: true, contentType: .password)
          InputField(label: t("changePassword.new"), placeholder: t("changePassword.newPlaceholder"), text: $new, isPassword: true, contentType: .newPassword)
          AppButton(title: t("changePassword.update"), loading: loading) { Task { await submit() } }
        }
        .padding(14)
      }
      .scrollDismissesKeyboard(.interactively)
    }
    .background(tokens.canvas)
    .toolbar(.hidden, for: .navigationBar)
  }

  private func submit() async {
    guard !current.isEmpty, !new.isEmpty else {
      AppAlert.error(t("common.error"), t("changePassword.required"))
      return
    }
    loading = true
    defer { loading = false }
    do {
      try await UserAPI.changePassword(current: current, new: new)
      AppAlert.success(t("common.success"), t("changePassword.updated"))
      current = ""
      new = ""
    } catch {
      AppAlert.error(t("common.error"), t("changePassword.failed"))
    }
  }
}

/// E-posta değiştirme (kodla onay). RN: screens/user/ChangeEmailScreen.tsx
struct ChangeEmailView: View {
  @Environment(\.tokens) private var tokens
  @State private var email = ""
  @State private var code = ""
  @State private var codeSent = false
  @State private var loading = false

  var body: some View {
    VStack(spacing: 0) {
      StandardHeader(title: t("profile.changeEmail"))
      ScrollView {
        Card {
          titleRow(icon: "mail-outline", title: t("changeEmail.title"), intro: t("changeEmail.intro"))
          InputField(label: t("changeEmail.newEmail"), placeholder: t("changeEmail.placeholder"), text: $email, keyboard: .emailAddress, contentType: .emailAddress)
          if !codeSent {
            AppButton(title: t("changeEmail.sendCode"), loading: loading) { Task { await sendCode() } }
          } else {
            RowDivider(leading: 0).padding(.vertical, 10.5)
            Text(t("changeEmail.code"))
              .font(.system(size: 12.25, weight: .medium))
              .foregroundStyle(tokens.isDark ? Forest.s300 : Forest.s700)
              .padding(.bottom, 10.5)
            OtpInput(value: $code).padding(.bottom, 14)
            AppButton(title: t("changeEmail.update"), loading: loading, disabled: code.count != 6) { Task { await confirm() } }
            AppButton(title: t("changeEmail.resend"), variant: .outline, loading: loading) { Task { await sendCode() } }
              .padding(.top, 10.5)
          }
        }
        .padding(14)
      }
      .scrollDismissesKeyboard(.interactively)
    }
    .background(tokens.canvas)
    .toolbar(.hidden, for: .navigationBar)
  }

  private func sendCode() async {
    guard !email.isEmpty else {
      AppAlert.error(t("common.error"), t("changeEmail.newRequired"))
      return
    }
    loading = true
    defer { loading = false }
    do {
      try await UserAPI.changeEmailRequest(newEmail: email.trimmingCharacters(in: .whitespaces))
      codeSent = true
      AppAlert.success(t("common.success"), t("changeEmail.codeSent"))
    } catch {
      AppAlert.error(t("common.error"), t("changeEmail.startFailed"))
    }
  }

  private func confirm() async {
    guard !code.isEmpty, !email.isEmpty else {
      AppAlert.error(t("common.error"), t("changeEmail.codeRequired"))
      return
    }
    loading = true
    defer { loading = false }
    do {
      try await UserAPI.changeEmailConfirm(otp: code, newEmail: email.trimmingCharacters(in: .whitespaces))
      AppAlert.success(t("common.success"), t("changeEmail.updated"))
      await AuthStore.shared.refreshUser()
      email = ""
      code = ""
      codeSent = false
    } catch {
      AppAlert.error(t("common.error"), t("changeEmail.confirmFailed"))
    }
  }
}

/// Kart başlığı: ikon + başlık + açıklama.
private func titleRow(icon: String, title: String, intro: String) -> some View {
  TitleRow(icon: icon, title: title, intro: intro)
}

private struct TitleRow: View {
  @Environment(\.tokens) private var tokens
  let icon: String
  let title: String
  let intro: String

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 7) {
        Ionicon(icon, size: 20, color: tokens.isDark ? Accent.s500 : Accent.s600)
        Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(tokens.isDark ? .white : Forest.s900)
      }
      .padding(.bottom, 14)
      Text(intro)
        .font(.system(size: 12.25))
        .foregroundStyle(tokens.isDark ? Forest.s400 : Forest.s600)
        .padding(.bottom, 21)
    }
  }
}
