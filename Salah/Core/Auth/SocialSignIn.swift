import AuthenticationServices
import CryptoKit
import UIKit

/// Clerk'siz sosyal giriş.
/// - Apple: iOS'un kendi "Apple ile Giriş" penceresi (AuthenticationServices).
/// - Google: SDK'sız OAuth 2.0 + PKCE (ASWebAuthenticationSession). Tek gereken
///   Google Cloud'daki iOS istemci kimliği (Info.plist `GoogleIOSClientID`).
///
/// İki yolda da kimlik token'ı backend'e gider; kullanıcı e-postayla eşleştiği için
/// Clerk ile açılmış hesaplar aynen devam eder.
enum SocialSignIn {
  enum Failure: Error {
    case cancelled
    case notConfigured
    case failed
  }

  // MARK: - Apple

  struct AppleCredential {
    let identityToken: String
    /// Tek kullanımlık, 5 dk geçerli; hesap silerken Apple yetkisini iptal etmek için.
    var authorizationCode: String?
    let firstName: String?
    let lastName: String?
  }

  static func apple() async throws -> AppleCredential {
    let request = ASAuthorizationAppleIDProvider().createRequest()
    request.requestedScopes = [.fullName, .email]
    let controller = ASAuthorizationController(authorizationRequests: [request])
    let delegate = AppleDelegate()
    controller.delegate = delegate
    controller.presentationContextProvider = delegate
    return try await withCheckedThrowingContinuation { continuation in
      delegate.continuation = continuation
      controller.performRequests()
    }
  }

  private final class AppleDelegate: NSObject, ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding
  {
    var continuation: CheckedContinuation<AppleCredential, Error>?
    /// Denetleyici yaşadıkça delegeyi de canlı tutar.
    private var retainSelf: AppleDelegate?

    override init() {
      super.init()
      retainSelf = self
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
      keyWindow()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
      defer { retainSelf = nil }
      guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
        let data = credential.identityToken, let token = String(data: data, encoding: .utf8)
      else {
        continuation?.resume(throwing: Failure.failed)
        return
      }
      // Ad yalnız ilk girişte gelir.
      continuation?.resume(
        returning: AppleCredential(
          identityToken: token, authorizationCode: credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) },
          firstName: credential.fullName?.givenName, lastName: credential.fullName?.familyName))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
      defer { retainSelf = nil }
      let cancelled = (error as? ASAuthorizationError)?.code == .canceled
      continuation?.resume(throwing: cancelled ? Failure.cancelled : Failure.failed)
    }
  }

  // MARK: - Google

  static var googleClientID: String? {
    let raw = (Bundle.main.object(forInfoDictionaryKey: "GoogleIOSClientID") as? String) ?? ""
    let id = raw.trimmingCharacters(in: .whitespaces)
    return id.isEmpty || id.hasPrefix("$(") ? nil : id
  }

  /// Google id_token döndürür.
  static func google() async throws -> String {
    guard let clientID = googleClientID else { throw Failure.notConfigured }
    // iOS istemcisinin yönlendirme şeması: istemci kimliğinin ters çevrilmiş hali.
    let scheme = clientID.split(separator: ".").reversed().joined(separator: ".")
    let redirectURI = "\(scheme):/oauth2redirect"
    let verifier = randomURLSafe(32)
    let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncoded()
    let state = randomURLSafe(16)

    var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
    components.queryItems = [
      .init(name: "client_id", value: clientID),
      .init(name: "redirect_uri", value: redirectURI),
      .init(name: "response_type", value: "code"),
      .init(name: "scope", value: "openid email profile"),
      .init(name: "code_challenge", value: challenge),
      .init(name: "code_challenge_method", value: "S256"),
      .init(name: "state", value: state),
      .init(name: "prompt", value: "select_account"),
    ]

    let callback = try await webAuth(url: components.url!, scheme: scheme)
    let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
    guard items.first(where: { $0.name == "state" })?.value == state,
      let code = items.first(where: { $0.name == "code" })?.value
    else { throw Failure.failed }

    // Kodu token'a çevir (iOS istemcileri gizli anahtar kullanmaz; PKCE yeterli).
    var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    var form = URLComponents()
    form.queryItems = [
      .init(name: "client_id", value: clientID),
      .init(name: "code", value: code),
      .init(name: "code_verifier", value: verifier),
      .init(name: "redirect_uri", value: redirectURI),
      .init(name: "grant_type", value: "authorization_code"),
    ]
    request.httpBody = form.percentEncodedQuery?.data(using: .utf8)
    struct TokenResponse: Decodable { let id_token: String? }
    let (data, response) = try await URLSession.shared.data(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 200,
      let idToken = try JSONDecoder().decode(TokenResponse.self, from: data).id_token
    else { throw Failure.failed }
    return idToken
  }

  private static func webAuth(url: URL, scheme: String) async throws -> URL {
    let provider = WebAuthContext()
    return try await withCheckedThrowingContinuation { continuation in
      let session = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { callback, error in
        _ = provider
        if let callback {
          continuation.resume(returning: callback)
        } else {
          let cancelled = (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin
          continuation.resume(throwing: cancelled ? Failure.cancelled : Failure.failed)
        }
      }
      session.presentationContextProvider = provider
      session.prefersEphemeralWebBrowserSession = false
      if !session.start() { continuation.resume(throwing: Failure.failed) }
    }
  }

  private final class WebAuthContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor { keyWindow() }
  }

  private static func randomURLSafe(_ bytes: Int) -> String {
    var data = Data(count: bytes)
    _ = data.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, bytes, $0.baseAddress!) }
    return data.base64URLEncoded()
  }
}

private func keyWindow() -> UIWindow {
  let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
  return scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? scenes.first.map { UIWindow(windowScene: $0) } ?? UIWindow()
}

extension Data {
  func base64URLEncoded() -> String {
    base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }
}
