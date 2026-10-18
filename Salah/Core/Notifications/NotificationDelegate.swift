import UIKit
import UserNotifications

/// Sistem bu delegeyi soğuk açılışta da çağırır; SwiftUI task'ından önce bağlanır.
final class SalahApplicationDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask { ReadingOrientation.mask }
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
    let center = UNUserNotificationCenter.current()
    center.delegate = SalahNotificationDelegate.shared
    center.setNotificationCategories([UNNotificationCategory(identifier: "spiritual_reminder", actions: [], intentIdentifiers: [])])
    return true
  }
}

struct NotificationPayload: Sendable {
  let type: String
  let prayerKey: String
  let adhanSound: Bool
  let body: String
  let subtitle: String
  let arabic: String
  let contentType: String

  nonisolated init(_ info: [AnyHashable: Any]) {
    type = info["type"] as? String ?? ""
    prayerKey = info["prayerKey"] as? String ?? ""
    adhanSound = info["adhanSound"] as? Bool ?? false
    body = info["body"] as? String ?? ""
    subtitle = info["subtitle"] as? String ?? ""
    arabic = info["arabic"] as? String ?? ""
    contentType = info["contentType"] as? String ?? "ayet"
  }

  var inspiration: InspirationModel.Item? {
    guard type == "spiritual_reminder", !body.isEmpty else { return nil }
    return .init(kind: contentType == "hadis" ? .hadith : .verse, text: body, arabic: arabic, source: subtitle)
  }
}

@Observable
final class NotificationNavigation {
  static let shared = NotificationNavigation()
  private(set) var inspiration: InspirationModel.Item? {
    didSet { if let inspiration { InspirationModel.publish(inspiration) } }
  }
  private(set) var homeRequest = 0
  @ObservationIgnored private let readLast: () -> String?
  @ObservationIgnored private let writeLast: (String) -> Void
  @ObservationIgnored private let openHome: () -> Void

  init(readLast: @escaping () -> String? = { LocalStore.string("LAST_SPIRITUAL_TAP_NOTIF_ID") },
       writeLast: @escaping (String) -> Void = { LocalStore.set($0, for: "LAST_SPIRITUAL_TAP_NOTIF_ID") },
       openHome: @escaping () -> Void = { HomeNavigation.shared.path.removeAll() }) {
    self.readLast = readLast
    self.writeLast = writeLast
    self.openHome = openHome
  }

  @discardableResult
  func receive(_ payload: NotificationPayload, id: String) -> Bool {
    guard let item = payload.inspiration, readLast() != id else { return false }
    writeLast(id)
    inspiration = item
    homeRequest += 1
    openHome()
    return true
  }
  func clear() { inspiration = nil }
  func requestHome() { homeRequest += 1 }
}

final class SalahNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
  static let shared = SalahNotificationDelegate()

  nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
    let payload = NotificationPayload(notification.request.content.userInfo)
    let options: UNNotificationPresentationOptions = await MainActor.run {
      if NotificationStore.shared.preferences.isMuted() { return [] }
      let plays = payload.type == "prayer_time" && payload.adhanSound && AdhanPlayer.shared.play(payload.prayerKey)
      // Tam ezan çalınmıyorsa (ör. ses dosyası okunamadıysa) kısa sesi koru.
      return plays ? [.banner, .list] : [.banner, .list, .sound]
    }
    return options
  }

  nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
    guard response.actionIdentifier != UNNotificationDismissActionIdentifier else { return }
    let payload = NotificationPayload(response.notification.request.content.userInfo)
    let id = response.notification.request.identifier
    await MainActor.run {
      NotificationNavigation.shared.receive(payload, id: id)
      if payload.type == "prayer_time" { AdhanPlayer.shared.receiveTap(payload.prayerKey) }
    }
  }
}
