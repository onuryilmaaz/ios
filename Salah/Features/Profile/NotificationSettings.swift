import SwiftUI

extension SettingsView {
  @ViewBuilder
  var notificationSections: some View {
    let store = NotificationStore.shared
    let prefs = store.preferences
    SectionLabel(t("settings.mute.title")).padding(.leading, 10.5)
    group {
      TimelineView(.periodic(from: .now, by: 60)) { context in
        if let until = prefs.muteUntil, until > context.date {
          row("notifications-off-outline", t("settings.mute.activeLabel", ["time": muteRemaining(until, now: context.date)]),
              sub: t("settings.mute.resumesAt", ["date": until.formatted(.dateTime.year().month(.abbreviated).day().hour().minute().locale(Localizer.shared.locale))]))
          row("close-circle-outline", t("settings.mute.turnOff"), sub: t("settings.mute.turnOffSub"), chevron: true, last: true) {
            store.unmute()
            Toast.success(t("mute.enabled"), t("mute.enabledMessage"))
          }
        } else {
          row("moon-outline", t("settings.mute.mute"), sub: t("settings.mute.muteSub"), chevron: true, last: true) { chooseMute() }
        }
      }
    }
    .id("mute")

    SectionLabel(t("settings.notifications.section")).padding(.leading, 10.5)
    group {
      row("notifications-outline", t("settings.notifications.prayer"), sub: t("settings.notifications.prayerSub"), last: !prefs.enabled,
          toggle: Binding(get: { store.preferences.enabled }, set: { value in
            guard !requestingNotifications else { return }
            Haptics.impact(.light)
            requestingNotifications = true
            Task {
              let enabled = await store.setEnabled(value)
              requestingNotifications = false
              if !enabled { AppAlert.warning(t("settings.location.permission"), t("settings.notifications.permissionMessage")) }
            }
          }))
      if prefs.enabled {
        VStack(alignment: .leading, spacing: 10.5) {
          optionLabel("settings.notifications.when")
          FlowLayout {
            ForEach([0, 5, 10, 15, 30], id: \.self) { offset in
              selectionChip(offset == 0 ? t("settings.notifications.atTime") : t("settings.notifications.minutesBefore", ["min": offset]),
                selected: prefs.offsets.first == offset, radio: true) {
                  store.update { $0.offsets = [offset] }
                }
            }
          }
          optionLabel("settings.notifications.whichPrayers")
          prayerChips(adhan: false)
        }
        .padding(.horizontal, 14).padding(.vertical, 10.5)
        row("flask-outline", t("settings.notifications.test"), sub: t("settings.notifications.testSub"), chevron: true, last: true) {
          Task {
            let sent = await store.sendTest()
            let summary = await store.summary()
            let detail = t("settings.notifications.scheduledDetail", ["total": summary.total, "prayer": summary.prayer, "other": summary.other])
            if sent {
              AppAlert.success(t("settings.notifications.testSent"), t("settings.notifications.testSentMessage", ["detail": detail]))
            } else {
              AppAlert.info(t("settings.notifications.scheduled"), detail)
            }
          }
        }
      }
    }
    .id("notifications")

    SectionLabel(t("settings.inspiration.section")).padding(.leading, 10.5)
    group {
      row("book-outline", t("settings.inspiration.section"), sub: t("settings.inspiration.sub"), last: !prefs.inspiration,
          toggle: preferenceBinding(\.inspiration))
      if prefs.inspiration {
        HStack(alignment: .top, spacing: 7) {
          Ionicon("information-circle-outline", size: 16, color: tokens.inkSubtle)
          Text(t("settings.inspiration.info")).font(.system(size: 12)).foregroundStyle(tokens.inkSubtle).lineSpacing(5)
        }.padding(.horizontal, 14).padding(.vertical, 10.5)
      }
    }
    SectionLabel(t("settings.holidays.section")).padding(.leading, 10.5)
    group {
      row("moon-outline", t("settings.holidays.title"), sub: t("settings.holidays.sub"), toggle: preferenceBinding(\.religiousDays))
      row("book-outline", t("settings.holidays.friday"), sub: t("settings.holidays.fridaySub"), last: true, toggle: preferenceBinding(\.friday))
    }
    SectionLabel(t("settings.adhan.section")).padding(.leading, 10.5)
    group {
      row("volume-high-outline", t("settings.adhan.title"), sub: t("settings.adhan.foregroundHint"))
      VStack(alignment: .leading, spacing: 7) {
        optionLabel("settings.adhan.which")
        prayerChips(adhan: true)
      }.padding(.horizontal, 14).padding(.vertical, 10.5)
      if AuthStore.shared.user?.roles?.contains("admin") == true {
        row("flask-outline", t("settings.adhan.test"), sub: t("settings.adhan.testSub"), chevron: true, last: true) { testAdhan() }
      }
    }
    .id("adhan")
  }

  private func optionLabel(_ key: String) -> some View {
    Text(t(key)).font(.system(size: 10.5, weight: .bold)).foregroundStyle(tokens.inkSubtle)
  }

  private func prayerChips(adhan: Bool) -> some View {
    let p = NotificationStore.shared.preferences
    return FlowLayout {
      ForEach(NotificationPreferences.prayers, id: \.self) { key in
        selectionChip(prayerLabel(key), selected: (adhan ? p.adhanEnabled[key] : p.prayerEnabled[key]) == true, gold: adhan) {
          NotificationStore.shared.update {
            if adhan { $0.adhanEnabled[key] = !($0.adhanEnabled[key] ?? false) }
            else { $0.prayerEnabled[key] = !($0.prayerEnabled[key] ?? false) }
          }
        }
      }
    }
  }

  private func selectionChip(_ title: String, selected: Bool, radio: Bool = false, gold: Bool = false, action: @escaping () -> Void) -> some View {
    let color = gold ? tokens.gold : tokens.accent
    return Button {
      Haptics.impact(.light)
      action()
    } label: {
      HStack(spacing: 5.25) {
        Ionicon(radio ? (selected ? "radio-button-on" : "radio-button-off") : (selected ? "checkmark-circle" : "ellipse-outline"), size: 14, color: selected ? color : tokens.inkSubtle)
        Text(title).font(.system(size: 10.5, weight: .bold)).foregroundStyle(selected ? color : tokens.inkSubtle)
      }
      .padding(.horizontal, 10.5).padding(.vertical, 7)
      .background(selected ? color.opacity(0.12) : tokens.fill, in: .rect(cornerRadius: 10.5))
      .overlay(RoundedRectangle(cornerRadius: 10.5).stroke(selected ? color : .clear, lineWidth: 1))
    }
    .buttonStyle(PressableStyle())
    .accessibilityAddTraits(selected ? .isSelected : [])
  }

  private func preferenceBinding(_ keyPath: WritableKeyPath<NotificationPreferences, Bool>) -> Binding<Bool> {
    Binding(get: { NotificationStore.shared.preferences[keyPath: keyPath] }, set: { value in
      Haptics.impact(.light)
      NotificationStore.shared.update { $0[keyPath: keyPath] = value }
    })
  }

  private func chooseMute() {
    func mute(_ minutes: Int) {
      NotificationStore.shared.mute(minutes: minutes)
      Haptics.notify(.success)
      if let until = NotificationStore.shared.preferences.muteUntil {
        Toast.success(t("settings.mute.muted"), t("settings.mute.mutedMessage", ["time": muteRemaining(until)]))
      }
    }
    let now = Date(), cal = Calendar.current
    let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now))!
    AppAlert.show(.info, t("settings.mute.title"), t("settings.mute.question"), buttons: [
      .init(text: t("settings.mute.15m")) { mute(15) },
      .init(text: t("settings.mute.1h")) { mute(60) },
      .init(text: t("settings.mute.3h")) { mute(180) },
      .init(text: t("settings.mute.endOfDay")) { mute(max(1, Int(ceil(end.timeIntervalSince(now) / 60)))) },
      .init(text: t("common.cancel"), style: .cancel),
    ])
  }

  private func testAdhan() {
    let buttons: [AppAlert.Button] = NotificationPreferences.prayers.filter { $0 != "gunes" }.map { key in
      .init(text: prayerLabel(key)) { _ = AdhanPlayer.shared.play(key, test: true) }
    }
    AppAlert.show(.info, t("settings.adhan.testTitle"), t("settings.adhan.testQuestion"), buttons: buttons + [
      .init(text: t("settings.adhan.stop"), style: .cancel) { AdhanPlayer.shared.stop() },
      .init(text: t("common.cancel"), style: .cancel),
    ])
  }
}
