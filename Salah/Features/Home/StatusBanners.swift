import SwiftUI

/// Kerahat vakti içindeyken gösterilen şerit. RN: components/home/ForbiddenTimeBanner.tsx
struct ForbiddenTimeBanner: View {
  @Environment(\.tokens) private var tokens
  let times: PrayerTimes?

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      if let times, let active = ForbiddenWindow.active(times, now: context.date) {
        let remaining = Self.format(active.end.timeIntervalSince(context.date))
        let end = formatHHMM(active.end)
        BannerRow(icon: "hand-left-outline", iconColor: tokens.danger, iconBackground: tokens.isDark ? Color(hex: 0xef4444).opacity(0.15) : Color(hex: 0xfef2f2)) {
          Text(t(active.labelKey))
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(tokens.textPrimary)
          Text(t(active.descriptionKey))
            .font(.system(size: 13))
            .foregroundStyle(tokens.textSecondary)
            .lineLimit(2)
            .padding(.top, 1.75)
        } trailing: {
          VStack(alignment: .trailing, spacing: 0) {
            Text(remaining)
              .font(.system(size: 15, weight: .semibold))
              .foregroundStyle(tokens.textPrimary)
              .tabularNumbers()
            Text(t("forbidden.until", ["time": end]))
              .font(.system(size: 10.5))
              .foregroundStyle(tokens.textSecondary)
          }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(t("forbidden.a11y", ["label": t(active.labelKey), "time": end, "remaining": remaining]))
      }
    }
  }

  private static func format(_ interval: TimeInterval) -> String {
    guard interval > 0 else { return t("forbidden.sec", ["s": 0]) }
    let total = Int(interval.rounded(.up))
    let m = total / 60
    let s = total % 60
    return m > 0 ? t("forbidden.min", ["m": m, "s": s]) : t("forbidden.sec", ["s": s])
  }
}

/// Perşembe akşamı ve Cuma günü hutbe kısayolu. RN: components/home/CumaHutbesiCard.tsx
struct CumaCard: View {
  @Environment(\.tokens) private var tokens
  let onOpen: () -> Void
  @SwiftUI.State private var sharing = false

  private enum State: String {
    case tomorrow, today, done
    var icon: String {
      switch self {
      case .tomorrow: "moon-outline"
      case .today: "sunny-outline"
      case .done: "checkmark-circle-outline"
      }
    }
  }

  var body: some View {
    TimelineView(.everyMinute) { context in
      if let state = Self.state(context.date) {
        let label = t("cuma.\(state.rawValue).label")
        Button {
          Haptics.impact(.light)
          onOpen()
        } label: {
          BannerRow(icon: state.icon, iconColor: tokens.accent, iconBackground: tokens.isDark ? Accent.s900 : Accent.s50) {
            Text(label)
              .font(.system(size: 15, weight: .semibold))
              .foregroundStyle(tokens.textPrimary)
            Text(t("cuma.\(state.rawValue).subtitle"))
              .font(.system(size: 13))
              .foregroundStyle(tokens.textSecondary)
              .padding(.top, 1.75)
          } trailing: {
            if state != .tomorrow {
              Button {
                Haptics.impact(.light)
                sharing = true
              } label: {
                Ionicon("share-outline", size: 16, color: tokens.accent)
                  .frame(width: 31.5, height: 31.5)
                  .background(tokens.isDark ? Accent.s900 : Accent.s50, in: .circle)
                  .contentShape(.rect.inset(by: -8))
              }
              .buttonStyle(PressableStyle())
              .accessibilityLabel(t("shareCards.greeting.cumaA11y"))
            }
            Ionicon(dirIcon("chevron-forward"), size: 18, color: tokens.inkSubtle)
          }
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(t("cuma.a11y", ["label": label]))
        .fullScreenCover(isPresented: $sharing) {
          GreetingShareSheet(kind: .cuma, dateText: GreetingKind.dateText(context.date))
            .environment(\.tokens, tokens)
        }
      }
    }
  }

  /// Perşembe 18:00 sonrası, Cuma 06–14 arası ve Cuma 14–22 arası.
  private static func state(_ now: Date) -> State? {
    let cal = Calendar.current
    let weekday = cal.component(.weekday, from: now)  // 5 = Perşembe, 6 = Cuma
    let hour = cal.component(.hour, from: now)
    if weekday == 5 && hour >= 18 { return .tomorrow }
    if weekday == 6 && (6..<14).contains(hour) { return .today }
    if weekday == 6 && (14..<22).contains(hour) { return .done }
    return nil
  }
}

/// İkonlu, iki satırlı kart şeridi (durum uyarıları).
struct BannerRow<Content: View, Trailing: View>: View {
  @Environment(\.tokens) private var tokens
  let icon: String
  let iconColor: Color
  let iconBackground: Color
  @ViewBuilder var content: Content
  @ViewBuilder var trailing: Trailing

  var body: some View {
    HStack(spacing: 10.5) {
      Ionicon(icon, size: 20, color: iconColor)
        .frame(width: 35, height: 35)
        .background(iconBackground, in: .circle)
      VStack(alignment: .leading, spacing: 0) { content }
        .frame(maxWidth: .infinity, alignment: .leading)
      trailing
    }
    .padding(17.5)
    .background(tokens.surface, in: .rect(cornerRadius: 21))
    .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
    .padding(.horizontal, 14)
    .padding(.bottom, 10.5)
  }
}
