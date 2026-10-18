import Foundation
import UserNotifications

struct PendingNotice: Sendable {
  var id: String
  var type: String
}

enum NotificationPermission: Equatable, Sendable { case unknown, denied, allowed }

protocol NotificationDelivery {
  func permission() async -> NotificationPermission
  func requestPermission() async throws -> Bool
  func pending() async -> [PendingNotice]
  func removePending()
  func add(_ notice: PlannedNotification) async throws
}

struct SystemNotificationDelivery: NotificationDelivery {
  private let center = UNUserNotificationCenter.current()

  func permission() async -> NotificationPermission {
    switch await center.notificationSettings().authorizationStatus {
    case .authorized, .provisional, .ephemeral: .allowed
    case .denied: .denied
    default: .unknown
    }
  }
  func requestPermission() async throws -> Bool { try await center.requestAuthorization(options: [.alert, .sound]) }
  func pending() async -> [PendingNotice] {
    await center.pendingNotificationRequests().map { .init(id: $0.identifier, type: $0.content.userInfo["type"] as? String ?? "") }
  }
  func removePending() { center.removeAllPendingNotificationRequests() }

  func add(_ notice: PlannedNotification) async throws {
    let content = Self.content(notice)
    let date = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: notice.date)
    let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: false)
    try await center.add(UNNotificationRequest(identifier: "salah.native.\(notice.id)", content: content, trigger: trigger))
  }

  static func content(_ n: PlannedNotification) -> UNMutableNotificationContent {
    let content = UNMutableNotificationContent()
    content.sound = n.adhan ? UNNotificationSound(named: .init("notif_ezan.caf")) : .default
    var info: [String: Any] = ["type": n.kind.rawValue]
    if n.kind == .prayerTime || n.kind == .prayerReminder {
      let prayer = prayerLabel(n.prayerKey)
      if n.kind == .prayerTime {
        content.title = t("notif.prayerTitle", ["prayer": prayer])
        content.subtitle = t("notif.prayerSubtitle")
        content.body = t("notif.prayerBody", ["prayer": prayer])
      } else {
        content.title = t("notif.reminderTitle", ["prayer": prayer, "minutes": n.offset])
        content.subtitle = t("notif.reminderSubtitle")
        content.body = t("notif.reminderBody", ["prayer": prayer])
      }
      let names = ["imsak": "İmsak", "gunes": "Güneş", "ogle": "Öğle", "ikindi": "İkindi", "aksam": "Akşam", "yatsi": "Yatsı"]
      info["prayerKey"] = n.prayerKey
      info["prayerName"] = names[n.prayerKey]
      info["adhanSound"] = n.adhan
      if n.kind == .prayerReminder { info["offset"] = n.offset }
    } else {
      content.title = n.title
      content.subtitle = n.subtitle
      content.body = n.body
      if n.kind == .inspiration {
        content.categoryIdentifier = "spiritual_reminder"
        // NSString uzunluğu JS string.length ile aynı (UTF-16).
        if (n.body as NSString).length > 220 {
          let end = n.body.utf16.index(n.body.utf16.startIndex, offsetBy: 217)
          let prefix = String(decoding: n.body.utf16[..<end], as: UTF16.self).trimmingCharacters(in: .whitespacesAndNewlines)
          content.body = prefix + "…, " + t("notif.tapForMore")
        }
        info["contentType"] = n.contentType
        info["subtitle"] = n.subtitle
        info["body"] = n.body
        info["arabic"] = n.arabic
      }
      if !n.dayID.isEmpty { info["dayId"] = n.dayID }
      if !n.when.isEmpty { info["when"] = n.when }
    }
    content.userInfo = info
    return content
  }
}
