import Foundation

/// Profil ve hesap uçları. RN: modules/user/user.api.ts
enum UserAPI {
  /// `nil` alan gönderilmez; `.null` alanı temizler (telefon/cinsiyet silme).
  static func updateProfile(firstName: String, lastName: String, username: String, phone: String?, gender: String?) async throws {
    try await APIClient.shared.send(
      "PATCH", "/user/update-profile",
      body: [
        "firstName": .string(firstName),
        "lastName": .string(lastName),
        "username": .string(username),
        "phone": phone.map(JSONValue.string) ?? .null,
        "gender": gender.map(JSONValue.string) ?? .null,
      ])
  }

  static func changePassword(current: String, new: String) async throws {
    try await APIClient.shared.send("POST", "/user/change-password", body: ["currentPassword": .string(current), "newPassword": .string(new)])
  }

  static func changeEmailRequest(newEmail: String) async throws {
    try await APIClient.shared.send("POST", "/auth/change-email/request", body: ["newEmail": .string(newEmail)])
  }

  static func changeEmailConfirm(otp: String, newEmail: String) async throws {
    try await APIClient.shared.send("POST", "/auth/change-email/confirm", body: ["otp": .string(otp), "newEmail": .string(newEmail)])
  }

  static func deactivate() async throws {
    try await APIClient.shared.send("POST", "/user/deactivate")
  }

  /// - Parameter appleAuthorizationCode: Apple ile girişte, sunucunun Apple yetkisini iptal etmesi için.
  static func deleteAccount(appleAuthorizationCode: String? = nil) async throws {
    var body: JSONValue?
    if let code = appleAuthorizationCode {
      body = ["appleAuthorizationCode": .string(code), "appleClientId": .string(Bundle.main.bundleIdentifier ?? "")]
    }
    try await APIClient.shared.send("DELETE", "/user/account", body: body)
  }

  static func revokeOtherSessions() async throws {
    try await APIClient.shared.send("POST", "/auth/sessions/revoke-others", headers: ["x-refresh-token": TokenStore.refreshToken ?? ""])
  }

  /// Ham dışa aktarım (JSON).
  static func exportData() async throws -> Data {
    try await APIClient.shared.send("GET", "/user/export", timeout: 30)
  }

  /// Profil fotoğrafı (multipart, alan adı `avatar`).
  static func uploadAvatar(jpeg: Data) async throws {
    let boundary = "Boundary-\(UUID().uuidString)"
    var body = Data()
    body.append(Data("--\(boundary)\r\n".utf8))
    body.append(Data("Content-Disposition: form-data; name=\"avatar\"; filename=\"avatar.jpg\"\r\n".utf8))
    body.append(Data("Content-Type: image/jpeg\r\n\r\n".utf8))
    body.append(jpeg)
    body.append(Data("\r\n--\(boundary)--\r\n".utf8))
    try await APIClient.shared.upload("/user/avatar", body: body, contentType: "multipart/form-data; boundary=\(boundary)", timeout: 60)
  }
}
