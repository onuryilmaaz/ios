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
/// Cuma akışı: o Cuma'nın Kehf okuması, salavat sayısı ve hutbe ziyareti (Perşembe akşamından Cuma gecesine).
@Observable
final class CumaFlowStore {
  static let shared = CumaFlowStore()
  private static let key = "@salah_cuma_flow_v1"
  static let salavatTarget = 100

  struct State: Codable, Equatable {
    /// Ait olduğu Cuma (yyyy-MM-dd); başka Cuma'ya geçince sıfırdan başlar.
    var friday = ""
    var kehf = false
    var hutbe = false
    var salavat = 0
  }

  private var stored: State

  private init() { stored = LocalStore.decode(State.self, Self.key) ?? State() }

  /// Perşembe akşamı ertesi günün Cuma'sı sayılır.
  static func friday(_ now: Date, calendar: Calendar = .current) -> String {
    let day = calendar.component(.weekday, from: now) == 5 ? calendar.date(byAdding: .day, value: 1, to: now) ?? now : now
    return localDateString(day)
  }

  func state(_ now: Date) -> State {
    let friday = Self.friday(now)
    return stored.friday == friday ? stored : State(friday: friday)
  }

  func update(_ now: Date = Date(), _ change: (inout State) -> Void) {
    var next = state(now)
    change(&next)
    stored = next
    LocalStore.encode(next, for: Self.key)
  }
}

struct CumaCard: View {
  @Environment(\.tokens) private var tokens
  /// Hutbe ekranı; modül panelden kapalıysa nil (hutbe satırı gizlenir).
  let onOpen: (() -> Void)?
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
        let flow = CumaFlowStore.shared.state(context.date)
        VStack(spacing: 0) {
          header(state, label: label)
          RowDivider(leading: 0)
          row("book-outline", t("cuma.flow.kehf"), sub: t("cuma.flow.kehfSub"), done: flow.kehf) {
            Haptics.impact(.light)
            CumaFlowStore.shared.update { $0.kehf = true }
            AppLinks.shared.request = URL(string: "salah://sure/18")
          }
          RowDivider(leading: 0)
          salavatRow(flow.salavat)
          if let onOpen {
            RowDivider(leading: 0)
            row("document-text-outline", t("cuma.flow.hutbe"), sub: t("cuma.flow.hutbeSub"), done: flow.hutbe) {
              Haptics.impact(.light)
              CumaFlowStore.shared.update { $0.hutbe = true }
              onOpen()
            }
          }
        }
        .background(tokens.surface, in: .rect(cornerRadius: 21))
        .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
        .padding(.horizontal, 14)
        .padding(.bottom, 10.5)
        .fullScreenCover(isPresented: $sharing) {
          GreetingShareSheet(kind: .cuma, dateText: GreetingKind.dateText(context.date))
            .environment(\.tokens, tokens)
        }
      }
    }
  }

  private func header(_ state: State, label: String) -> some View {
    HStack(spacing: 10.5) {
      Ionicon(state.icon, size: 20, color: tokens.accent)
        .frame(width: 35, height: 35)
        .background(tokens.isDark ? Accent.s900 : Accent.s50, in: .circle)
      VStack(alignment: .leading, spacing: 1.75) {
        Text(label).font(.system(size: 15, weight: .semibold)).foregroundStyle(tokens.textPrimary)
        Text(t("cuma.\(state.rawValue).subtitle")).font(.system(size: 13)).foregroundStyle(tokens.textSecondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .accessibilityElement(children: .combine)
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
    }
    .padding(17.5)
  }

  private func row(_ icon: String, _ title: String, sub: String, done: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack(spacing: 10.5) {
        Ionicon(icon, size: 17, color: tokens.accent)
          .frame(width: 31.5, height: 31.5)
          .background(tokens.accentSoft, in: .circle)
        VStack(alignment: .leading, spacing: 1.75) {
          Text(title).font(.system(size: 15, weight: .medium)).foregroundStyle(tokens.textPrimary)
          Text(sub).font(.system(size: 13)).foregroundStyle(tokens.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        if done {
          Ionicon("checkmark-circle", size: 20, color: tokens.accent).accessibilityLabel(t("cuma.flow.done"))
        } else {
          Ionicon(dirIcon("chevron-forward"), size: 18, color: tokens.inkSubtle)
        }
      }
      .padding(.horizontal, 17.5)
      .padding(.vertical, 12)
      .contentShape(.rect)
    }
    .buttonStyle(PressableStyle())
  }

  private func salavatRow(_ count: Int) -> some View {
    let target = CumaFlowStore.salavatTarget
    let complete = count >= target
    return Button {
      if complete {
        Haptics.impact(.light)
      } else {
        CumaFlowStore.shared.update { $0.salavat += 1 }
        if count + 1 == target { Haptics.notify(.success) } else { Haptics.impact(.light) }
      }
    } label: {
      HStack(spacing: 10.5) {
        Ionicon("heart-outline", size: 17, color: tokens.accent)
          .frame(width: 31.5, height: 31.5)
          .background(tokens.accentSoft, in: .circle)
        VStack(alignment: .leading, spacing: 1.75) {
          Text(t("cuma.flow.salavat")).font(.system(size: 15, weight: .medium)).foregroundStyle(tokens.textPrimary)
          Text(t("cuma.flow.salavatSub")).font(.system(size: 13)).foregroundStyle(tokens.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        Text(t("cuma.flow.count", ["count": count, "target": target]))
          .font(.system(size: 15, weight: .semibold)).tabularNumbers()
          .foregroundStyle(complete ? tokens.accent : tokens.textPrimary)
        Ionicon(complete ? "checkmark-circle" : "add-circle", size: 22, color: tokens.accent)
      }
      .padding(.horizontal, 17.5)
      .padding(.vertical, 12)
      .contentShape(.rect)
    }
    .buttonStyle(PressableStyle())
    .accessibilityLabel("\(t("cuma.flow.salavat")), \(t("cuma.flow.count", ["count": count, "target": target]))")
  }

  /// Perşembe 18:00 sonrası, Cuma 06–14 arası ve Cuma 14–22 arası.
  private static func state(_ now: Date) -> State? {
    #if DEBUG
    if let raw = UserDefaults.standard.string(forKey: "SalahDebugCuma"), let forced = State(rawValue: raw) { return forced }
    #endif
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
