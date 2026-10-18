#if DEBUG
import Foundation

/// Görsel kontrol: gerçek hesap veya backend kullanılmaz, mutation kapalıdır.
enum AdminPreview {
  static func response(_ method: String, _ path: String) throws -> Data {
    guard method == "GET" else { throw APIError.network(URLError(.notConnectedToInternet)) }
    let roles = [["id": "preview-admin", "name": "admin"], ["id": "preview-role", "name": "user"], ["id": "preview-editor", "name": "editor"]]
    let user: [String: Any] = ["id": "preview-user", "email": "preview@example.invalid", "username": "ornek",
      "firstName": "Örnek", "lastName": "Kullanıcı", "roles": ["user"], "isActive": true, "isPremium": true,
      "premiumUntil": "2027-10-18T00:00:00Z"]
    let value: Any
    if path == "/admin/dashboard" {
      value = ["users": ["total": 128, "active": 120, "inactive": 8], "sessions": ["active": 42]]
    } else if path == "/admin/roles" { value = roles }
    else if path.hasSuffix("/sessions") { value = ["sessions": [["id": "preview-session"]]] }
    else if path.contains("/admin/users?") {
      let search = URLComponents(string: "https://preview.invalid" + path)?.queryItems?.first { $0.name == "search" }?.value ?? ""
      let matches = search.isEmpty || "Örnek Kullanıcı ornek preview@example.invalid".localizedCaseInsensitiveContains(search)
      value = ["users": matches ? [user] : [], "total": matches ? 1 : 0, "page": 1, "totalPages": 1]
    } else { value = ["user": user] }
    return try JSONSerialization.data(withJSONObject: value)
  }
}
#endif
