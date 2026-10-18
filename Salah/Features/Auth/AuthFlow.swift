import SwiftUI

/// Giriş akışı: sekmelerin üstünde tam ekran açılır (RN'de kök yığındaki `Auth`).
/// Giriş başarılı olunca kendiliğinden kapanır.
@Observable
final class AuthFlow {
  static let shared = AuthFlow()

  enum Route: Hashable {
    case login
    case register
    case otp(email: String, password: String?)
    case forgot
    case reset(email: String)
  }

  var isPresented = false
  var path: [Route] = []

  /// Hoş geldin ekranından başlar; `route` verilirse onun üstüne açılır
  /// (RN'deki `rootNavigate('Auth', { screen: 'Login' })` gibi).
  func present(_ route: Route? = nil) {
    path = route.map { [$0] } ?? []
    isPresented = true
  }

  func dismiss() {
    isPresented = false
    path = []
  }
}

struct AuthFlowView: View {
  @Environment(\.tokens) private var tokens
  @Bindable private var flow = AuthFlow.shared

  var body: some View {
    NavigationStack(path: $flow.path) {
      WelcomeView()
        .navigationDestination(for: AuthFlow.Route.self) { route in
          switch route {
          case .login: LoginView()
          case .register: RegisterView()
          case .otp(let email, let password): OtpView(email: email, password: password)
          case .forgot: ForgotPasswordView()
          case .reset(let email): ResetPasswordView(email: email)
          }
        }
    }
    .overlay(alignment: .topTrailing) {
      Button {
        Haptics.impact(.light)
        flow.dismiss()
      } label: {
        Ionicon("close", size: 22, color: tokens.ink)
          .frame(width: 44, height: 44)
          .background(tokens.isDark ? Forest.s900 : .white, in: .circle)
          .overlay(Circle().stroke(tokens.line, lineWidth: 1))
      }
      .buttonStyle(PressableStyle())
      .accessibilityLabel(t("common.close"))
      .accessibilityIdentifier("auth.close")
      .padding(.trailing, 20)
      .padding(.top, 8)
    }
    .accessibilityAction(.escape) { flow.dismiss() }
    .onChange(of: AuthStore.shared.isAuthenticated) { _, authed in
      if authed { flow.dismiss() }
    }
  }
}

/// Apple/Google girişini yürüten ortak model (RN: components/auth/useSocialAuth.ts).
@Observable
final class SocialAuthModel {
  enum Provider { case apple, google }
  private(set) var loading: Provider?

  /// Hata mesajı; iptal hata sayılmaz.
  func signIn(_ provider: Provider, onError: (String?) -> Void) async {
    loading = provider
    onError(nil)
    defer { loading = nil }
    do {
      let response: AuthAPI.LoginResponse
      switch provider {
      case .apple:
        let credential = try await SocialSignIn.apple()
        response = try await AuthAPI.apple(identityToken: credential.identityToken, firstName: credential.firstName, lastName: credential.lastName)
      case .google:
        let idToken = try await SocialSignIn.google()
        response = try await AuthAPI.google(idToken: idToken)
      }
      await AuthStore.shared.login(response)
    } catch SocialSignIn.Failure.cancelled {
      return
    } catch {
      onError((error as? APIError)?.serverMessage ?? t("auth.social.failed"))
    }
  }
}
