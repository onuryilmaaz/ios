import Foundation
import Observation

/// Dua defteri: kullanıcının kendi duaları ve niyetleri. Yalnız cihazda (sunucuya gitmez).
/// Hatırlatmalar bildirim planına girer (`NotificationPlan.build(journal:)`); günler JS gün numarası (0 Pazar).
/// Android `core/dua/DuaJournalStore.kt` aynı anahtar ve biçim.
struct DuaJournalEntry: Codable, Identifiable, Equatable, Sendable {
  struct Reminder: Codable, Equatable, Sendable {
    var hour = 21
    var minute = 0
    var days: [Int] = [0, 1, 2, 3, 4, 5, 6]
  }

  var id = UUID().uuidString
  var title = ""
  var text = ""
  var reminder: Reminder?
  var updatedAt = Date().timeIntervalSince1970
}

@MainActor
@Observable
final class DuaJournalStore {
  static let shared = DuaJournalStore()
  private static let key = "@salah_dua_journal_v1"
  static let titleLimit = 60
  static let textLimit = 2000

  private(set) var entries: [DuaJournalEntry]

  private init() {
    entries = LocalStore.decode([DuaJournalEntry].self, Self.key) ?? []
  }

  func save(_ entry: DuaJournalEntry) {
    var value = entry
    value.title = String(value.title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.titleLimit))
    value.text = String(value.text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.textLimit))
    value.updatedAt = Date().timeIntervalSince1970
    if let i = entries.firstIndex(where: { $0.id == value.id }) { entries[i] = value } else { entries.insert(value, at: 0) }
    persist()
  }

  func delete(_ id: String) {
    entries.removeAll { $0.id == id }
    persist()
  }

  /// Bildirim planına giren hatırlatmalar.
  var reminders: [JournalReminder] {
    entries.compactMap { e in
      guard let r = e.reminder else { return nil }
      return JournalReminder(id: e.id, title: e.title.isEmpty ? String(e.text.prefix(60)) : e.title, hour: r.hour, minute: r.minute, days: Set(r.days))
    }
  }

  /// Plan imzası: hatırlatma değişince bildirim planı beklemeden yeniden kurulur.
  var signature: String {
    reminders.map { "\($0.id):\($0.hour):\($0.minute):\($0.days.sorted())" }.joined(separator: ",")
  }

  private func persist() {
    LocalStore.encode(entries, for: Self.key)
    Task { await NotificationStore.shared.reschedule(force: true) }
  }
}
