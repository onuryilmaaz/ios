import UIKit
import UserNotifications

/// Panelden gönderilen duyuru bildirimleri için cihaz kaydı. Kapatılırsa kayıt sunucudan silinir.
/// Bildirim izni istemez: vakit bildirimleri için verilmiş izni kullanır, izin yoksa kaydolmaz.
@MainActor
@Observable
final class PushStore {
  static let shared = PushStore()
  private static let enabledKey = "@salah_push_announcements_v1"
  private static let tokenKey = "@salah_push_token_v1"
  private static let signatureKey = "@salah_push_signature_v1"

  private(set) var enabled: Bool = LocalStore.decode(Bool.self, PushStore.enabledKey) ?? true

  private static var environment: String {
    #if DEBUG
    return "sandbox"
    #else
    return "production"
    #endif
  }

  func setEnabled(_ value: Bool) {
    enabled = value
    LocalStore.encode(value, for: Self.enabledKey)
    Task { await sync() }
  }

  /// Öne gelişte, oturum ve dil değişince çağrılır. Değişiklik yoksa sunucuya gitmez.
  func sync() async {
    guard !DebugLaunch.isIsolated else { return }
    guard enabled else { return await removeFromServer() }
    let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    guard status == .authorized || status == .provisional || status == .ephemeral else { return }
    if let token = LocalStore.string(Self.tokenKey) { await upload(token) }
    UIApplication.shared.registerForRemoteNotifications()
  }

  func didRegister(deviceToken: Data) {
    let token = deviceToken.map { String(format: "%02x", $0) }.joined()
    LocalStore.set(token, for: Self.tokenKey)
    guard enabled else { return }
    Task { await upload(token) }
  }

  private func upload(_ token: String) async {
    let language = Localizer.shared.serverLanguage
    let signature = [token, language, UpdateGate.currentVersion, AuthStore.shared.user?.id ?? ""].joined(separator: "|")
    guard LocalStore.string(Self.signatureKey) != signature else { return }
    let body: JSONValue = [
      "token": .string(token), "platform": .string("ios"), "environment": .string(Self.environment),
      "language": .string(language), "appVersion": .string(UpdateGate.currentVersion),
    ]
    guard (try? await APIClient.shared.send("POST", "/push/device", body: body)) != nil else { return }
    LocalStore.set(signature, for: Self.signatureKey)
  }

  /// Panel sayacı: bildirime dokunuldu.
  func recordOpen(_ campaignId: String) {
    guard !campaignId.isEmpty, !DebugLaunch.isIsolated else { return }
    Task { _ = try? await APIClient.shared.send("POST", "/push/campaigns/\(campaignId)/open") }
  }

  private func removeFromServer() async {
    guard LocalStore.string(Self.signatureKey) != "", let token = LocalStore.string(Self.tokenKey) else { return }
    guard (try? await APIClient.shared.send("DELETE", "/push/device", body: ["token": .string(token)])) != nil else { return }
    LocalStore.set("", for: Self.signatureKey)
  }
}
