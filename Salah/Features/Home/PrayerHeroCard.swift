import SwiftUI

/// Ana sayfanın üst alanı: o anki/sıradaki vakte geri sayım ve günün vakitleri.
/// RN: components/home/PrayerTimesCard.tsx
struct PrayerHeroCard: View {
  let today: PrayerDay?
  let isLoading: Bool
  let locationName: String
  var onLocation: () -> Void = {}
  /// Alarmlar ekranı (iOS 26+ AlarmKit).
  var onAlarms: () -> Void = {}

  /// Koyu zümrüt zemin üzerindeki altın (gold-300).
  private let goldOnDark = Gold.s300

  var body: some View {
    let completed = GamificationStore.shared.stats?.today_prayers ?? []
    TimelineView(.periodic(from: .now, by: 1)) { context in
      let window = today.map { PrayerWindow.compute($0.times, completed: completed, now: context.date) }
      content(window: window, now: context.date)
    }
  }

  @ViewBuilder
  private func content(window: PrayerWindow?, now: Date) -> some View {
    let headline =
      window.map {
        t($0.mode == .current ? "home.hero.untilEnd" : "home.hero.untilStart", ["prayer": prayerLabel($0.prayerName)])
      } ?? t("home.hero.fallback")

    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 7) {
        Text(headline)
          .font(.system(size: 17))
          .foregroundStyle(.white.opacity(0.75))
          .lineLimit(1)
          .layoutPriority(-1)
        Spacer(minLength: 0)
        if AlarmStore.shared.supported {
          let next = AlarmStore.shared.authorized ? AlarmStore.shared.next : nil
          Button {
            Haptics.impact(.light)
            onAlarms()
          } label: {
            HStack(spacing: 3.5) {
              Ionicon(next == nil ? "alarm-outline" : "alarm", size: 12, color: next == nil ? .white.opacity(0.75) : goldOnDark)
              Text(next.map { formatHHMM($0.fireAt) } ?? t("alarm.quick.pill"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
                .tabularNumbers()
            }
            .padding(.horizontal, 8.75)
            .padding(.vertical, 3.5)
            .background(.white.opacity(0.1), in: .capsule)
          }
          .buttonStyle(PressableStyle())
          .accessibilityLabel(t("alarm.screen.title"))
          .tourAnchor("home.alarms")
        }
        if !locationName.isEmpty {
          Button {
            Haptics.impact(.light)
            onLocation()
          } label: {
            HStack(spacing: 3.5) {
              Ionicon("location", size: 12, color: .white.opacity(0.75))
              Text(locationName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
            }
            .padding(.horizontal, 8.75)
            .padding(.vertical, 3.5)
            .background(.white.opacity(0.1), in: .capsule)
          }
          .buttonStyle(PressableStyle())
          .accessibilityLabel("\(t("settings.location.prayerLocation")): \(locationName)")
          .tourAnchor("home.location")
        }
      }

      Countdown(target: window?.end, now: now)
        .padding(.top, 3.5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(headline)

      if let window {
        let showProgress = window.start.map { now > $0 } ?? false
        HStack(spacing: 10.5) {
          if showProgress, let start = window.start {
            WindowProgress(start: start, end: window.end, now: now)
          }
          Text(
            window.mode == .current
              ? "\(prayerLabel(window.nextPrayer)) \(formatHHMM(window.end))"
              : t("home.hero.entry", ["time": formatHHMM(window.end)])
          )
          .font(.system(size: 13))
          .foregroundStyle(.white.opacity(0.7))
          .tabularNumbers()
          .frame(maxWidth: showProgress ? nil : .infinity, alignment: .leading)
        }
        .padding(.top, 3.5)
      }

      timesRow(window: window)
        // Vakte dokununca hızlı alarm menüsü açılır (yalnız alarm destekli cihazda).
        .tourAnchor(AlarmStore.shared.supported ? "home.times" : nil)
        .padding(.top, 17.5)
    }
    .padding(.horizontal, 17.5)
    .padding(.top, 10.5)
    .padding(.bottom, 17.5)
  }

  private func timesRow(window: PrayerWindow?) -> some View {
    // Kutularda vurgulanan: gösterilen pencerenin vakti (Sabah → İmsak kutusu).
    let highlighted = window?.prayerName == "Sabah" ? "İmsak" : (window?.prayerName ?? "")
    let items: [(label: String, key: String)] = [
      ("İmsak", "imsak"), ("Güneş", "gunes"), ("Öğle", "ogle"),
      ("İkindi", "ikindi"), ("Akşam", "aksam"), ("Yatsı", "yatsi"),
    ]
    return HStack(spacing: 0) {
      if isLoading && today == nil {
        ForEach(0..<6, id: \.self) { _ in
          VStack(spacing: 7) {
            Capsule().fill(.white.opacity(0.1)).frame(width: 31.5, height: 8.75)
            Capsule().fill(.white.opacity(0.1)).frame(width: 35, height: 12.25)
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 10.5)
        }
      } else if let today {
        ForEach(items, id: \.key) { item in
          let active = item.label == highlighted
          let time = today.times[item.key] ?? "--:--"
          let alarms = AlarmStore.shared
          let alarmOn = alarms.supported && alarms.authorized && alarms.settings.prayers[item.key]?.enabled == true
          Button {
            AlarmQuickMenu.open(item.key, openAlarms: onAlarms)
          } label: {
          VStack(spacing: 0) {
            Ionicon(prayerIcon(item.label), size: 14, color: active ? goldOnDark : .white.opacity(0.45))
            Text(prayerLabel(item.label))
              .font(.system(size: 12, weight: active ? .semibold : .regular))
              .foregroundStyle(active ? goldOnDark : .white.opacity(0.55))
              .lineLimit(1)
              .padding(.top, 3.5)
            Text(time)
              .font(.system(size: 14, weight: .medium))
              .foregroundStyle(active ? .white : .white.opacity(0.8))
              .tabularNumbers()
              .padding(.top, 1.75)
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 8.75)
          .background(active ? .white.opacity(0.12) : .clear, in: .rect(cornerRadius: 20))
          .overlay(alignment: .topTrailing) {
            if alarmOn { Ionicon("alarm", size: 10, color: goldOnDark).padding(5.25) }
          }
          .contentShape(.rect)
          }
          .buttonStyle(PressableStyle())
          .disabled(!alarms.supported)
          .accessibilityElement(children: .ignore)
          .accessibilityLabel("\(prayerLabel(item.label)) \(time)\(active ? ", \(t("home.hero.now"))" : "")\(alarmOn ? ", \(t("alarm.quick.pill"))" : "")")
        }
      }
    }
    .padding(3.5)
    .background(.white.opacity(0.06), in: .rect(cornerRadius: 21))
  }
}

/// Saniyelik geri sayım; rakamlar yuvarlanarak değişir (RN'deki RollingCountdown).
private struct Countdown: View {
  let target: Date?
  let now: Date

  var body: some View {
    if let target {
      let text = format(max(0, target.timeIntervalSince(now)))
      HStack(spacing: 0) {
        ForEach(Array(text.enumerated()), id: \.offset) { _, char in
          if char == ":" {
            Text(verbatim: ":")
              .font(.system(size: 54, weight: .thin))
              .foregroundStyle(.white.opacity(0.4))
              .padding(.horizontal, 1.75)
              .offset(y: -3)
          } else {
            Text(String(char))
              .font(.system(size: 66, weight: .thin))
              .foregroundStyle(.white)
              .frame(width: 39, height: 80)
              .contentTransition(.numericText(countsDown: true))
          }
        }
      }
      .environment(\.layoutDirection, .leftToRight)
      .animation(.easeOut(duration: 0.24), value: text)
    } else {
      Text(verbatim: "--:--:--")
        .font(.system(size: 66, weight: .thin))
        .foregroundStyle(.white.opacity(0.4))
        .frame(height: 80)
    }
  }

  private func format(_ interval: TimeInterval) -> String {
    let total = Int(interval)
    return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
  }
}

/// Vaktin geçen kısmı (3 pt, altın).
private struct WindowProgress: View {
  let start: Date
  let end: Date
  let now: Date

  var body: some View {
    let pct = min(1, max(0, now.timeIntervalSince(start) / end.timeIntervalSince(start)))
    Capsule()
      .fill(.white.opacity(0.15))
      .frame(height: 3)
      .overlay(alignment: .leading) {
        GeometryReader { geo in
          Capsule().fill(Gold.s300).frame(width: geo.size.width * pct)
        }
      }
      .clipShape(.capsule)
  }
}
