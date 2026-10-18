import Foundation

/// Backend kimlik uçları. RN: modules/auth/auth.api.ts
/// Sosyal giriş Clerk'siz: native Apple ve Google kimlik token'ları doğrudan
/// backend'e (`/auth/apple`, `/auth/google`) gider.
enum AuthAPI {
  struct LoginResponse: Decodable {
    let user: AuthUser
    let accessToken: String
    let refreshToken: String
  }

  struct RegisterResponse: Decodable {
    let user: AuthUser?
  }

  static func login(email: String, password: String) async throws -> LoginResponse {
    try await APIClient.shared.post("/auth/login", body: ["email": .string(email), "password": .string(password)])
  }

  static func register(email: String, password: String, firstName: String, lastName: String) async throws -> RegisterResponse {
    try await APIClient.shared.post(
      "/auth/register",
      body: ["email": .string(email), "password": .string(password), "firstName": .string(firstName), "lastName": .string(lastName)])
  }

  static func verifyEmail(email: String, code: String) async throws {
    try await APIClient.shared.send("POST", "/auth/verify-email", body: ["email": .string(email), "code": .string(code)])
  }

  static func resendEmailOtp(email: String) async throws {
    try await APIClient.shared.send("POST", "/auth/resend-email-otp", body: ["email": .string(email)])
  }

  static func forgotPassword(email: String) async throws {
    try await APIClient.shared.send("POST", "/auth/forgot-password", body: ["email": .string(email)])
  }

  static func resetPassword(email: String, otp: String, newPassword: String) async throws {
    try await APIClient.shared.send(
      "POST", "/auth/reset-password",
      body: ["email": .string(email), "otp": .string(otp), "newPassword": .string(newPassword)])
  }

  static func apple(identityToken: String, firstName: String?, lastName: String?) async throws -> LoginResponse {
    var body: [String: JSONValue] = ["identityToken": .string(identityToken)]
    if let firstName, !firstName.isEmpty { body["firstName"] = .string(firstName) }
    if let lastName, !lastName.isEmpty { body["lastName"] = .string(lastName) }
    return try await APIClient.shared.post("/auth/apple", body: .object(body))
  }

  static func google(idToken: String) async throws -> LoginResponse {
    try await APIClient.shared.post("/auth/google", body: ["idToken": .string(idToken)])
  }
}

extension APIError {
  /// Sunucunun `{ message }` alanı (RN'de `err.response.data.message`).
  var serverMessage: String? {
    guard case .http(_, let body) = self,
      let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
      let message = json["message"] as? String, !message.isEmpty
    else { return nil }
    return message
  }
}
