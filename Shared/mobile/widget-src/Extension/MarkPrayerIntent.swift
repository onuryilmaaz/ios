import AppIntents
import WidgetKit

@available(iOS 17.0, *)
struct MarkPrayerIntent: AppIntent {
  static var title: LocalizedStringResource = "Mark Prayer"

  @Parameter(title: "Prayer ID")
  var prayerId: String

  init() {}
  init(prayerId: String) { self.prayerId = prayerId }

  func perform() async throws -> some IntentResult {
    guard let ud = UserDefaults(suiteName: appGroupID) else { return .result() }

    let backendId = widgetToBackendPrayerID[prayerId] ?? prayerId

    // Detect kaza: check if prayer window has expired
    var isKaza = false
    if let raw = ud.data(forKey: "salah_widget_data"),
       let widget = try? JSONDecoder().decode(WidgetData.self, from: raw) {
      isKaza = prayerIsExpired(prayerId: prayerId, widget: widget)
    }

    // Optimistic local update so widget refreshes instantly
    applyLocalUpdate(ud: ud, backendId: backendId, isKaza: isKaza)
    ud.synchronize()

    WidgetCenter.shared.reloadAllTimelines()

    // Try direct API call — no need to open the app
    let apiSuccess = await trackOnBackend(ud: ud, prayerTime: backendId, isKaza: isKaza)

    if !apiSuccess {
      // Fallback: queue so App.tsx syncs it when the app opens
      let existing = ud.string(forKey: "salah_pending_prayers") ?? ""
      let entry = isKaza ? "\(backendId):kaza" : backendId
      ud.set(existing.isEmpty ? entry : "\(existing),\(entry)", forKey: "salah_pending_prayers")
    }

    // Second reload after API completes to sync any widgets that missed the first
    WidgetCenter.shared.reloadAllTimelines()

    return .result()
  }

  // MARK: - Local Optimistic Update

  private func applyLocalUpdate(ud: UserDefaults, backendId: String, isKaza: Bool) {
    guard let raw = ud.data(forKey: "salah_tracker_data"),
          var tracker = try? JSONDecoder().decode(TrackerData.self, from: raw) else { return }

    let alreadyDone = tracker.completedPrayers.contains(prayerId)
      || tracker.completedPrayers.contains(backendId)
    guard !alreadyDone else { return }

    tracker.completedPrayers.append(backendId)
    if isKaza { tracker.kazaPrayers.append(backendId) }

    if let enc = try? JSONEncoder().encode(tracker) {
      ud.set(enc, forKey: "salah_tracker_data")
    }
  }

  // MARK: - Backend API Call

  private func trackOnBackend(ud: UserDefaults, prayerTime: String, isKaza: Bool) async -> Bool {
    // Eski sürümden kalan düz metin token'lar varsa önce Keychain'e taşı.
    SalahKeychain.migrateFromDefaults(ud)
    guard let apiUrl = ud.string(forKey: "salah_api_url"),
          let token = SalahKeychain.get(SalahKeychain.accessToken), !token.isEmpty,
          let url = URL(string: "\(apiUrl)/prayer/track") else { return false }

    if let result = await postTrack(url: url, token: token, prayerTime: prayerTime, isKaza: isKaza) {
      return result
    }

    // 401 → try refresh
    if let newToken = await refreshAccessToken(ud: ud) {
      return await postTrack(url: url, token: newToken, prayerTime: prayerTime, isKaza: isKaza) ?? false
    }

    return false
  }

  // Returns true on 2xx, false on other errors, nil on 401
  private func postTrack(url: URL, token: String, prayerTime: String, isKaza: Bool) async -> Bool? {
    var req = URLRequest(url: url, timeoutInterval: 10)
    req.httpMethod = "POST"
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    req.httpBody = try? JSONSerialization.data(withJSONObject: [
      "prayer_time": prayerTime,
      "is_kaza": isKaza,
    ])

    do {
      let (_, response) = try await URLSession.shared.data(for: req)
      guard let http = response as? HTTPURLResponse else { return false }
      if http.statusCode == 401 { return nil }      // signal refresh needed
      // 400 = already tracked → treat as success (optimistic was correct)
      return (200...499).contains(http.statusCode)
    } catch {
      return false
    }
  }

  // MARK: - Token Refresh

  private func refreshAccessToken(ud: UserDefaults) async -> String? {
    guard let apiUrl = ud.string(forKey: "salah_api_url"),
          let refreshToken = SalahKeychain.get(SalahKeychain.refreshToken), !refreshToken.isEmpty,
          let url = URL(string: "\(apiUrl)/auth/refresh") else { return nil }

    // Yanıt kaybolursa yeni token kaydedilemez; yavaş ağda erken pes etme.
    var req = URLRequest(url: url, timeoutInterval: 20)
    req.httpMethod = "POST"
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.httpBody = try? JSONSerialization.data(withJSONObject: ["refreshToken": refreshToken])

    do {
      let (data, _) = try await URLSession.shared.data(for: req)
      guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let newAccess = json["accessToken"] as? String,
            let newRefresh = json["refreshToken"] as? String else { return nil }
      // Uygulama ile ortak Keychain: uygulama bir sonraki isteğinde bu taze
      // token'ları doğrudan okur.
      SalahKeychain.store(access: newAccess, refresh: newRefresh, stampMs: Date().timeIntervalSince1970 * 1000)
      return newAccess
    } catch {
      return nil
    }
  }

  // MARK: - Kaza Detection

  private func timeToMinutes(_ timeStr: String) -> Int {
    let parts = timeStr.split(separator: ":").compactMap { Int($0) }
    guard parts.count >= 2 else { return 0 }
    return parts[0] * 60 + parts[1]
  }

  private func prayerIsExpired(prayerId: String, widget: WidgetData) -> Bool {
    let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
    let nowMin = (now.hour ?? 0) * 60 + (now.minute ?? 0)

    let imsakMin = timeToMinutes(widget.imsak)
    let inBridge = imsakMin > 0 && nowMin < imsakMin

    switch prayerId {
    case "sabah":
      if inBridge { return true }
      let end = timeToMinutes(widget.gunes)
      return end > 0 && nowMin >= end
    case "ogle":
      if inBridge { return true }
      let end = timeToMinutes(widget.ikindi)
      return end > 0 && nowMin >= end
    case "ikindi":
      if inBridge { return true }
      let end = timeToMinutes(widget.aksam)
      return end > 0 && nowMin >= end
    case "aksam":
      if inBridge { return true }
      let end = timeToMinutes(widget.yatsi)
      return end > 0 && nowMin >= end
    case "yatsi":
      return false
    default:
      return false
    }
  }
}
