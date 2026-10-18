import Foundation

enum APIError: Error {
  /// Sunucudan yanıt alınamadı (uçak modu, DNS, zaman aşımı).
  case network(URLError)
  /// Sunucu yanıt verdi ama başarısız.
  case http(status: Int, body: Data)
  case decoding(Error)

  var status: Int? {
    if case .http(let status, _) = self { return status }
    return nil
  }
}

extension Error {
  /// Yanıt hiç gelmediyse ağ hatası; 4xx/5xx ağ hatası DEĞİLDİR (sunucuya ulaşıldı).
  var isNetworkError: Bool {
    if let api = self as? APIError, case .network = api { return true }
    return self is URLError
  }
}

/// Backend istemcisi. Davranış RN'deki services/api.ts ile aynı:
/// - JWT her isteğe eklenir; 401'de token tek noktadan yenilenip istek bir kez tekrarlanır.
/// - Oturum yalnız /auth/refresh 400/401 dönerse kapanır; ağ/5xx hatasında token'a dokunulmaz.
/// - Zaman aşımı oturum hatası sayılmaz; istek bir kez sessizce tekrarlanır.
final class APIClient {
  static let shared = APIClient()

  let baseURL: URL
  /// Oturum sunucu tarafından kesin reddedildiğinde (AuthStore çıkış yapar).
  var onSessionDead: (() async -> Void)?

  private let session: URLSession
  private var refreshTask: Task<RefreshOutcome, Never>?
  private var isLoggingOut = false

  private struct RefreshOutcome {
    var token: String?
    var sessionDead: Bool
  }

  private init() {
    let raw = (Bundle.main.object(forInfoDictionaryKey: "SalahAPIURL") as? String) ?? ""
    let trimmed = raw.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
    baseURL = URL(string: trimmed.isEmpty ? "http://localhost:3000" : trimmed)!
    let config = URLSessionConfiguration.default
    config.waitsForConnectivity = false
    session = URLSession(configuration: config)
  }

  // MARK: - Public

  func get<T: Decodable>(_ path: String, as type: T.Type = T.self) async throws -> T {
    try decode(try await send("GET", path))
  }

  func post<T: Decodable>(_ path: String, body: JSONValue? = nil, as type: T.Type = T.self) async throws -> T {
    try decode(try await send("POST", path, body: body))
  }

  /// Yanıt gövdesi gerekmeyen istekler (kuyruk tekrarı, silme).
  @discardableResult
  func send(
    _ method: String,
    _ path: String,
    body: JSONValue? = nil,
    headers: [String: String] = [:],
    timeout: TimeInterval = 10
  ) async throws -> Data {
    try await perform(method, path, body: body, raw: nil, headers: headers, timeout: timeout, authRetried: false, timeoutRetried: false)
  }

  /// Ham gövdeli POST (multipart dosya yükleme). Oturum kuralları aynı.
  @discardableResult
  func upload(_ path: String, body: Data, contentType: String, timeout: TimeInterval = 60) async throws -> Data {
    try await perform("POST", path, body: nil, raw: (body, contentType), headers: [:], timeout: timeout, authRetried: false, timeoutRetried: false)
  }

  /// Uygulama açılışı ve store'lar da doğrudan /auth/refresh yerine bunu kullanır.
  /// Aynı anda yalnızca bir yenileme yapılır.
  func refreshAccessToken() async -> (token: String?, sessionDead: Bool) {
    if DebugLaunch.isIsolated { return (nil, false) }
    if let refreshTask {
      let r = await refreshTask.value
      return (r.token, r.sessionDead)
    }
    let task = Task { await self.runRefresh() }
    refreshTask = task
    let r = await task.value
    refreshTask = nil
    return (r.token, r.sessionDead)
  }

  // MARK: - Internals

  private func perform(
    _ method: String,
    _ path: String,
    body: JSONValue?,
    raw: (data: Data, contentType: String)?,
    headers: [String: String],
    timeout: TimeInterval,
    authRetried: Bool,
    timeoutRetried: Bool
  ) async throws -> Data {
    if DebugLaunch.isIsolated { throw APIError.network(URLError(.notConnectedToInternet)) }
    var request = makeRequest(method, path, body: body, timeout: timeout)
    if let raw {
      request.httpBody = raw.data
      request.setValue(raw.contentType, forHTTPHeaderField: "Content-Type")
    }
    for (k, v) in headers { request.setValue(v, forHTTPHeaderField: k) }
    if let token = TokenStore.accessToken {
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await session.data(for: request)
    } catch let error as URLError {
      if error.code == .timedOut, !timeoutRetried, !path.contains("/auth/refresh") {
        return try await perform(method, path, body: body, raw: raw, headers: headers, timeout: timeout, authRetried: authRetried, timeoutRetried: true)
      }
      throw APIError.network(error)
    }

    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
    if (200..<300).contains(status) { return data }

    let isAuthEndpoint = ["/auth/login", "/auth/refresh", "/auth/logout"].contains { path.contains($0) }
    guard status == 401, !isAuthEndpoint, !isLoggingOut, !authRetried else {
      throw APIError.http(status: status, body: data)
    }

    let outcome = await refreshAccessToken()
    if outcome.token != nil {
      return try await perform(method, path, body: body, raw: raw, headers: headers, timeout: timeout, authRetried: true, timeoutRetried: timeoutRetried)
    }
    if outcome.sessionDead, !isLoggingOut {
      isLoggingOut = true
      if let onSessionDead { await onSessionDead() } else { TokenStore.clear() }
      isLoggingOut = false
    }
    throw APIError.http(status: status, body: data)
  }

  private func runRefresh() async -> RefreshOutcome {
    guard let refreshToken = TokenStore.refreshToken else {
      TokenStore.removeAccessToken()
      return RefreshOutcome(token: nil, sessionDead: true)
    }
    do {
      let pair = try await postRefresh(refreshToken)
      TokenStore.adopt(access: pair.accessToken, refresh: pair.refreshToken)
      return RefreshOutcome(token: pair.accessToken, sessionDead: false)
    } catch let APIError.http(status, _) where status == 400 || status == 401 {
      // Widget aynı Keychain'deki token'ı biz okuduktan sonra yenilemiş olabilir.
      if let current = TokenStore.refreshToken, current != refreshToken,
        let pair = try? await postRefresh(current)
      {
        TokenStore.adopt(access: pair.accessToken, refresh: pair.refreshToken)
        return RefreshOutcome(token: pair.accessToken, sessionDead: false)
      }
      TokenStore.clear()
      return RefreshOutcome(token: nil, sessionDead: true)
    } catch {
      // Ağ hatası / 429 / 5xx: token büyük ihtimalle geçerli, oturuma DOKUNMA.
      return RefreshOutcome(token: nil, sessionDead: false)
    }
  }

  private struct TokenPair: Decodable {
    let accessToken: String
    let refreshToken: String
  }

  private func postRefresh(_ refreshToken: String) async throws -> TokenPair {
    // Yanıt kaybolursa yeni token kaydedilemez; yavaş ağda erken pes etme.
    let request = makeRequest("POST", "/auth/refresh", body: ["refreshToken": .string(refreshToken)], timeout: 20)
    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await session.data(for: request)
    } catch let error as URLError {
      throw APIError.network(error)
    }
    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
    guard (200..<300).contains(status) else { throw APIError.http(status: status, body: data) }
    return try decode(data)
  }

  private func makeRequest(_ method: String, _ path: String, body: JSONValue?, timeout: TimeInterval) -> URLRequest {
    // appendingPathComponent sorgu dizesini (`?period=week`) kodlayıp bozar; metin olarak birleştir.
    let url = URL(string: baseURL.absoluteString + (path.hasPrefix("/") ? path : "/" + path)) ?? baseURL
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.timeoutInterval = timeout
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    if let body {
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.httpBody = try? JSONEncoder().encode(body)
    }
    return request
  }

  private func decode<T: Decodable>(_ data: Data) throws -> T {
    do {
      return try JSONDecoder().decode(T.self, from: data)
    } catch {
      throw APIError.decoding(error)
    }
  }
}
