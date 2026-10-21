import Foundation

struct AuthUser: Codable, Equatable, Sendable {
  let id: String
  let email: String
  var username: String?
  var emailVerified: Bool?
  var roles: [String]?
  var firstName: String?
  var lastName: String?
  var phone: String?
  var avatarUrl: String?
  /// "erkek" | "kadin"
  var gender: String?
  /// "local" | "apple" | "google" | "clerk"
  var authProvider: String?
}

/// Oturum durumu. Akış RN'deki modules/auth/auth.store.ts ile aynı:
/// token varsa yerelde saklı kullanıcıyla oturum HEMEN açılır (internetsiz
/// açılışta da), ağ gelince profil tazelenir. Oturum yalnız sunucu yenilemeyi
/// kesin reddederse kapanır.
@Observable
final class AuthStore {
  static let shared = AuthStore()

  private(set) var user: AuthUser?
  private(set) var isAuthenticated = false
  private(set) var hydrated = false

  private init() {
    APIClient.shared.onSessionDead = { [weak self] in await self?.logout(callServer: false) }
  }

  func hydrate() async {
    defer { hydrated = true }
    let storedAccess = TokenStore.accessToken
    let storedRefresh = TokenStore.refreshToken
    guard storedAccess != nil || storedRefresh != nil else { return }

    let storedUser = LocalStore.decode(AuthUser.self, TokenStore.storedUserKey)
    if let storedUser {
      user = storedUser
      isAuthenticated = true
    }

    if storedAccess == nil {
      let outcome = await APIClient.shared.refreshAccessToken()
      if outcome.sessionDead {
        signOutLocally()
        return
      }
      // Ağ hatası: token'lara dokunma; yerel kullanıcı varsa oturumda kal.
      if outcome.token == nil { return }
    }

    do {
      try await fetchProfile()
    } catch APIError.http(401, _) where TokenStore.refreshToken == nil {
      signOutLocally()
    } catch {
      // Ağ hatası / 5xx → offline. Token geçerli; yerel kullanıcıyla oturumda KAL.
      isAuthenticated = user != nil
    }
  }

  /// Başarılı girişten sonra (e-posta, Apple, Google): token'ları yazar, profili çeker.
  /// Profil alınamazsa (ör. offline) giriş yanıtındaki kullanıcı saklanır.
  func login(_ response: AuthAPI.LoginResponse) async {
    TokenStore.adopt(access: response.accessToken, refresh: response.refreshToken)
    do {
      try await fetchProfile()
    } catch {
      LocalStore.encode(response.user, for: TokenStore.storedUserKey)
      user = response.user
      isAuthenticated = true
    }
  }

  func refreshUser() async {
    guard TokenStore.accessToken != nil else { return }
    try? await fetchProfile()
  }

  func logout(callServer: Bool = true) async {
    if callServer, let refresh = TokenStore.refreshToken {
      _ = try? await APIClient.shared.send("POST", "/auth/logout", body: ["refreshToken": .string(refresh)])
    }
    TokenStore.clear()
    signOutLocally()
  }

  /// Admin kendi rolünü değiştirince oturumdaki kullanıcı da güncellenir (RN `setUser`).
  func setRoles(_ roles: [String]) {
    guard var u = user else { return }
    u.roles = roles
    LocalStore.encode(u, for: TokenStore.storedUserKey)
    user = u
  }

  private func fetchProfile() async throws {
    // Uç bazen `{ user: {...} }`, bazen kullanıcıyı doğrudan döndürüyor.
    struct Wrapped: Decodable { let user: AuthUser }
    let data = try await APIClient.shared.send("GET", "/user/profile")
    let decoder = JSONDecoder()
    let profile: AuthUser
    if let wrapped = try? decoder.decode(Wrapped.self, from: data) {
      profile = wrapped.user
    } else {
      profile = try decoder.decode(AuthUser.self, from: data)
    }
    LocalStore.encode(profile, for: TokenStore.storedUserKey)
    user = profile
    isAuthenticated = true
  }

  private func signOutLocally() {
    user = nil
    isAuthenticated = false
    GamificationStore.shared.reset()
    TrackerStore.shared.reset()
  }

  #if DEBUG
  /// Mağaza görseli fikstürü (`-SalahDebugSample YES`): örnek kullanıcıyla oturum açık görünüm, yalnız bellek.
  func preview(_ user: AuthUser) {
    self.user = user
    isAuthenticated = true
    hydrated = true
  }
  #endif
}
