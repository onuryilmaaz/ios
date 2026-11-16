import SwiftUI
import UserNotifications

/// Yönetici tanı ekranı: bu cihazda sistemde gerçekten kurulu bildirimler, planlama durumu ve vakit ayarları.
/// Yönetici ekranları gibi yalnız Türkçe.
struct AdminNotificationsView: View {
  @Environment(\.tokens) private var tokens
  @State private var items: [Item] = []
  @State private var loading = true

  struct Item: Identifiable {
    let id: String
    let date: Date?
    let type: String
    let prayerKey: String
    let adhan: Bool
    let offset: Int?
    let title: String
    let body: String
  }

  var body: some View {
    AdminScreen(title: "Bildirim planı") {
      ScrollView {
        VStack(alignment: .leading, spacing: 14) {
          status
          prayers
          actions
          list
        }
        .padding(14)
        .padding(.bottom, 84)
      }
      .scrollIndicators(.hidden)
      .refreshable { await load() }
    }
    .task { await load() }
    .onChange(of: NotificationStore.shared.isScheduling) { _, scheduling in
      if !scheduling { Task { await load() } }
    }
  }

  // MARK: Durum

  private var status: some View {
    let store = NotificationStore.shared
    let p = store.preferences
    return Card {
      title("Durum")
      line("İzin", permissionText(store.permission), ok: store.permission == .allowed)
      line("Vakit bildirimleri", p.enabled ? "Açık" : "Kapalı", ok: p.enabled)
      line("Sessiz", p.muteUntil.map { "\(format($0)) tarihine kadar" } ?? "Hayır", ok: p.muteUntil == nil)
      line("Bildirim zamanı", p.offsets.map { $0 == 0 ? "vaktinde" : "\($0) dk önce" }.joined(separator: ", "))
      line("Son planlama", store.debugLastScheduled.map(format) ?? "Yok", ok: store.debugLastScheduled != nil)
      line("Planlanıyor", store.isScheduling ? "Evet" : "Hayır")
      line("Kurulu bildirim", "\(items.count) / 64", ok: !items.isEmpty)
      line("Ezanlı bildirim", "\(items.filter(\.adhan).count)")
      line("İlçe", Locations.selectedDistrictId)
      line("Saat dilimi", TimeZone.current.identifier)
      if let error = store.lastError { line("Son hata", error, ok: false) }
      if let signature = store.debugSignature {
        Text(signature)
          .font(.system(size: 10, design: .monospaced))
          .foregroundStyle(tokens.textSecondary)
          .textSelection(.enabled)
          .padding(.top, 7)
      }
    }
  }

  private var prayers: some View {
    let p = NotificationStore.shared.preferences
    let covered = AlarmStore.shared.coveredPrayerKeys
    return Card {
      title("Vakitler")
      ForEach(NotificationPreferences.prayers, id: \.self) { key in
        let parts = [
          p.prayerEnabled[key] == true ? "bildirim" : nil,
          p.adhanEnabled[key] == true ? "ezan (\(AdhanSound.name(key)))" : nil,
          covered.contains(key) ? "alarm" : nil,
        ].compactMap { $0 }
        line(prayerLabel(key), parts.isEmpty ? "kapalı" : parts.joined(separator: " · "))
      }
    }
  }

  private var actions: some View {
    HStack(spacing: 10.5) {
      AppButton(title: "Yeniden planla", variant: .secondary, loading: NotificationStore.shared.isScheduling) {
        Haptics.impact(.medium)
        Task {
          await NotificationStore.shared.reschedule(force: true)
          await load()
          Toast.success("Plan yeniden kuruldu", "\(items.count) bildirim kurulu.")
        }
      }
      AppButton(title: "Test bildirimi") {
        Haptics.impact(.medium)
        Task {
          let sent = await NotificationStore.shared.sendTest()
          await load()
          if sent { Toast.success("Test bildirimi", "Birkaç saniye içinde gelir.") } else { Toast.error("Gönderilemedi", "Bildirim izni yok.") }
        }
      }
    }
  }

  // MARK: Liste

  @ViewBuilder private var list: some View {
    if loading && items.isEmpty {
      ProgressView().tint(tokens.accent).frame(maxWidth: .infinity).padding(.top, 21)
    } else if items.isEmpty {
      EmptyState(icon: "notifications-off-outline", title: "Kurulu bildirim yok", message: "Bu cihazda bekleyen bildirim bulunmuyor.")
    } else {
      let groups = Dictionary(grouping: items) { $0.date.map { Calendar.current.startOfDay(for: $0) } ?? .distantFuture }
      ForEach(groups.keys.sorted(), id: \.self) { day in
        VStack(alignment: .leading, spacing: 7) {
          Text(day == .distantFuture ? "Zamanı bilinmeyen" : day.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Localizer.shared.locale)))
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(tokens.textSecondary)
            .padding(.leading, 3.5)
          GroupedCard {
            let rows = groups[day]!.sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
            ForEach(Array(rows.enumerated()), id: \.element.id) { i, item in
              if i > 0 { RowDivider() }
              row(item)
            }
          }
        }
      }
    }
  }

  private func row(_ item: Item) -> some View {
    HStack(alignment: .top, spacing: 10.5) {
      Text(item.date?.formatted(.dateTime.hour().minute().locale(Localizer.shared.locale)) ?? "--:--")
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(tokens.textPrimary)
        .tabularNumbers()
        .frame(width: 52, alignment: .leading)
      VStack(alignment: .leading, spacing: 3.5) {
        HStack(spacing: 5.25) {
          chip(typeText(item), color: tokens.accent)
          if item.adhan { chip(AdhanSound.name(item.prayerKey), color: tokens.gold) }
        }
        Text(item.title)
          .font(.system(size: 14, weight: .medium))
          .foregroundStyle(tokens.textPrimary)
          .lineLimit(2)
        if !item.body.isEmpty {
          Text(item.body).font(.system(size: 13)).foregroundStyle(tokens.textSecondary).lineLimit(2)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10.5)
  }

  // MARK: Yardımcılar

  private func title(_ text: String) -> some View {
    Text(text).font(.system(size: 14, weight: .bold)).foregroundStyle(tokens.textPrimary).padding(.bottom, 7)
  }

  private func line(_ label: String, _ value: String, ok: Bool? = nil) -> some View {
    HStack(alignment: .firstTextBaseline) {
      Text(label).font(.system(size: 13)).foregroundStyle(tokens.textSecondary)
      Spacer(minLength: 10.5)
      Text(value)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(ok == false ? Color(hex: 0xdc2626) : tokens.textPrimary)
        .multilineTextAlignment(.trailing)
        .tabularNumbers()
    }
    .padding(.vertical, 3.5)
  }

  private func chip(_ text: String, color: Color) -> some View {
    Text(text)
      .font(.system(size: 10.5, weight: .bold))
      .foregroundStyle(color)
      .padding(.horizontal, 7)
      .padding(.vertical, 2)
      .background(color.opacity(0.12), in: .capsule)
  }

  private func typeText(_ item: Item) -> String {
    let prayer = item.prayerKey.isEmpty ? "" : " · " + prayerLabel(item.prayerKey)
    switch item.type {
    case "prayer_time": return "Vakit" + prayer
    case "prayer_reminder": return "\(item.offset ?? 0) dk önce" + prayer
    case "missed_prayer": return "Kılınmadı" + prayer
    case "spiritual_reminder": return "Ayet/hadis"
    case "religious_day": return "Dini gün"
    case "cuma_reminder": return "Cuma"
    case "app_reminder": return "Geri dönüş"
    case "hatim_reminder": return "Hatim"
    case "ramadan_night": return "Ramazan gecesi"
    case "": return "Diğer"
    default: return item.type
    }
  }

  private func permissionText(_ p: NotificationPermission) -> String {
    switch p {
    case .allowed: "Verildi"
    case .denied: "Reddedildi"
    default: "Bilinmiyor"
    }
  }

  private func format(_ date: Date) -> String {
    date.formatted(.dateTime.day().month(.abbreviated).hour().minute().locale(Localizer.shared.locale))
  }

  private func load() async {
    loading = true
    defer { loading = false }
    let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
    items = requests.map { r in
      let info = r.content.userInfo
      let date = (r.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
        ?? (r.trigger as? UNTimeIntervalNotificationTrigger)?.nextTriggerDate()
      return Item(
        id: r.identifier, date: date, type: info["type"] as? String ?? "",
        prayerKey: info["prayerKey"] as? String ?? "", adhan: info["adhanSound"] as? Bool ?? false,
        offset: info["offset"] as? Int, title: r.content.title, body: r.content.body)
    }
  }
}
