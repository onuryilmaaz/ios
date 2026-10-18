import SwiftUI

/// Mübarek gün tebriki: dini günün kimliğinden (ör. "berat_1447") tebrik türü.
/// Metinler i18n'de: shareCards.greeting.<kind>. RN: modules/greetings/greeting.ts
enum GreetingKind: String, Sendable {
  case kandil, kadir, bayram, arife, ramazan, ucAylar, hicriYil, asure, cuma

  init?(dayId: String) {
    let id = dayId.replacing(/_\d+$/, with: "")
    switch id {
    case "mirac", "berat", "mevlid", "regaib": self = .kandil
    case "kadir": self = .kadir
    case "ramazan_bayram_arife", "kurban_bayram_arife": self = .arife
    case "ramazan_start", "ramazan_arife": self = .ramazan
    case "uc_aylar": self = .ucAylar
    case "hicri_yilbasi": self = .hicriYil
    case "asure": self = .asure
    default:
      guard id.wholeMatch(of: /(ramazan|kurban)_bayram_\d/) != nil else { return nil }
      self = .bayram
    }
  }

  var icon: String {
    switch self {
    case .kandil, .ramazan: "moon"
    case .kadir: "star"
    case .bayram: "sparkles"
    case .arife, .ucAylar: "moon-outline"
    case .hicriYil: "calendar"
    case .asure: "water"
    case .cuma: "sunny"
    }
  }

  /// "3 Şubat 2026 · 14 Şaban 1447"
  static func dateText(_ date: Date) -> String {
    let greg = date.formatted(.dateTime.day().month(.wide).year().locale(Localizer.shared.locale))
    return "\(greg) · \(HijriCalendarText.hijri(ReligiousCalendarService.cached().hijri(date)))"
  }
}

/// Kandil / bayram / cuma tebrik kartı. RN: components/share/GreetingShareModal.tsx
struct GreetingShareSheet: View {
  let kind: GreetingKind
  /// "Berat Kandili" (cumada boş)
  var dayName: String?
  let dateText: String

  var body: some View {
    let message = t("shareCards.greeting.\(kind.rawValue)")
    ShareImageSheet(fallbackText: [message, dayName].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n")) {
      ShareCardHeader()

      VStack(spacing: 0) {
        Ionicon(kind.icon, size: 36, color: Gold.s300)
          .frame(width: 70, height: 70)
          .overlay(Circle().stroke(Gold.s300, lineWidth: 1))
        if let dayName, !dayName.isEmpty {
          Text(dayName)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(Gold.s300)
            .multilineTextAlignment(.center)
            .padding(.top, 24)
        }
        Text(message)
          .font(.system(size: 30, weight: .bold))
          .lineSpacing(8)
          .foregroundStyle(.white)
          .multilineTextAlignment(.center)
          .padding(.top, 7)
      }
      .padding(.vertical, 14)

      GoldDivider().padding(.vertical, 17.5)

      Text(t("shareCards.greeting.prayer"))
        .font(.system(size: 15))
        .lineSpacing(9)
        .foregroundStyle(Forest.s100)
        .multilineTextAlignment(.center)
      Text(dateText)
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(Gold.s300)
        .multilineTextAlignment(.center)
        .padding(.top, 20)
    }
  }
}

/// "42. gün, beş vakit" seri kartı: büyük sayı, son 7 gün, en uzun seri.
/// RN: components/share/StreakShareModal.tsx
struct StreakShareSheet: View {
  let streak: Int
  let longest: Int
  let week: [WeekDay]

  var body: some View {
    let headline = t("shareCards.streak.headline", ["count": streak])
    let longestText = t("shareCards.streak.longest", ["count": longest])
    ShareImageSheet(fallbackText: "\(headline). \(longestText)") {
      ShareCardHeader(label: t("shareCards.streak.label"))

      VStack(spacing: 0) {
        Ionicon("flame", size: 30, color: Gold.s300)
          .frame(width: 56, height: 56)
          .overlay(Circle().stroke(Gold.s300, lineWidth: 1))
        Text("\(streak)")
          .font(.system(size: 72, weight: .bold))
          .foregroundStyle(.white)
          .tabularNumbers()
          .frame(height: 80)
          .padding(.top, 14)
        Text(headline)
          .font(.system(size: 18, weight: .medium))
          .foregroundStyle(Forest.s100)
          .multilineTextAlignment(.center)
      }

      GoldDivider().padding(.vertical, 21)

      HStack {
        ForEach(Array(week.enumerated()), id: \.offset) { i, d in
          if i > 0 { Spacer(minLength: 0) }
          VStack(spacing: 5.25) {
            ZStack {
              if d.full {
                Circle().fill(Gold.s300)
                Ionicon("checkmark", size: 17, color: Color(hex: 0x113c2f))
              } else if d.partial {
                Circle().stroke(Gold.s300, lineWidth: 1)
              } else {
                Circle().fill(.white.opacity(0.1))
              }
              if !d.full && d.count > 0 {
                Text("\(d.count)")
                  .font(.system(size: 12, weight: .semibold))
                  .foregroundStyle(Gold.s300)
              }
            }
            .frame(width: 31.5, height: 31.5)
            Text(d.label)
              .font(.system(size: 12, weight: d.isToday ? .semibold : .regular))
              .foregroundStyle(d.isToday ? .white : .white.opacity(0.6))
          }
        }
      }

      Text(longestText)
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(Gold.s300)
        .multilineTextAlignment(.center)
        .padding(.top, 24)
    }
  }
}

/// Haftalık/aylık özetin paylaşılabilir görseli. RN: components/insights/RecapShareModal.tsx
struct RecapShareSheet: View {
  let recap: InsightsStore.Recap
  let range: String

  private static let prayers = ["fajr", "dhuhr", "asr", "maghrib", "isha"]

  var body: some View {
    let pct = Double(recap.prayers) / Double(max(1, recap.possiblePrayers))
    let title = t(recap.period == "week" ? "insights.recap.week" : "insights.recap.month")
    let fallback = "\(title): \(t("insights.recap.prayers", ["done": recap.prayers, "total": recap.possiblePrayers]))"
    ShareImageSheet(fallbackText: fallback) {
      ShareCardHeader(label: title)

      VStack(alignment: .leading, spacing: 0) {
        Text(range)
          .font(.system(size: 13))
          .foregroundStyle(.white.opacity(0.7))
        HStack(alignment: .firstTextBaseline, spacing: 7) {
          Text("\(recap.prayers)")
            .font(.system(size: 56, weight: .bold))
            .foregroundStyle(.white)
            .tabularNumbers()
          Text(t("insights.recap.ofPrayers", ["total": recap.possiblePrayers]))
            .font(.system(size: 17))
            .foregroundStyle(.white.opacity(0.75))
        }
        .padding(.top, 3.5)
        Capsule()
          .fill(.white.opacity(0.15))
          .frame(height: 7)
          .overlay(alignment: .leading) {
            GeometryReader { geo in
              Capsule().fill(Gold.s300).frame(width: geo.size.width * min(1, pct))
            }
          }
          .clipShape(.capsule)
          .padding(.top, 10.5)

        HStack {
          ForEach(Array(Self.prayers.enumerated()), id: \.element) { i, p in
            if i > 0 { Spacer(minLength: 0) }
            VStack(spacing: 3.5) {
              Text("\(recap.byPrayerTime[p] ?? 0)")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Gold.s300)
                .tabularNumbers()
              Text(prayerLabel(p))
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.7))
            }
          }
        }
        .padding(.top, 17.5)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      GoldDivider().padding(.vertical, 17.5)

      HStack(spacing: 0) {
        stat(recap.perfectDays, t("insights.recap.perfectDays"))
        stat(recap.quranPages, t("insights.recap.quranPages"))
        stat(recap.currentStreak ?? 0, t("insights.recap.streak"))
      }
    }
  }

  private func stat(_ value: Int, _ label: String) -> some View {
    VStack(spacing: 2) {
      Text("\(value)")
        .font(.system(size: 24, weight: .semibold))
        .foregroundStyle(.white)
        .tabularNumbers()
      Text(label)
        .font(.system(size: 12))
        .foregroundStyle(.white.opacity(0.7))
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
  }
}

/// Bugün dini bir günse ana sayfada tebrik kartı paylaşma önerisi.
/// RN: components/home/HolidayGreetingCard.tsx
struct HolidayGreetingCard: View {
  @Environment(\.tokens) private var tokens
  @State private var today: ReligiousDay?
  @State private var kind: GreetingKind?
  @State private var open = false

  var body: some View {
    Group {
      if let today, let kind {
        Button {
          Haptics.impact(.light)
          open = true
        } label: {
          HStack(spacing: 10.5) {
            Ionicon(kind.icon, size: 20, color: Gold.s300)
              .frame(width: 38.5, height: 38.5)
              .background(.white.opacity(0.1), in: .circle)
            VStack(alignment: .leading, spacing: 2) {
              Text(today.name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
              Text(t("shareCards.greeting.cta"))
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Ionicon("share-outline", size: 18, color: Gold.s300)
          }
          .padding(17.5)
          .background(tokens.isDark ? Accent.s900 : Accent.s800, in: .rect(cornerRadius: 21))
          .padding(.horizontal, 14)
          .padding(.bottom, 10.5)
        }
        .buttonStyle(PressableStyle(pressedOpacity: 0.8))
        .accessibilityLabel("\(today.name). \(t("shareCards.greeting.cta"))")
        .fullScreenCover(isPresented: $open) {
          GreetingShareSheet(kind: kind, dayName: today.name, dateText: GreetingKind.dateText(today.date))
            .environment(\.tokens, tokens)
        }
      }
    }
    .task(id: Localizer.shared.language) {
      let calendar = await ReligiousCalendarService.load()
      let now = Date()
      let match = calendar.religiousDays(now: now).first {
        GreetingKind(dayId: $0.id) != nil && Calendar.current.isDate($0.date, inSameDayAs: now)
      }
      today = match
      kind = match.flatMap { GreetingKind(dayId: $0.id) }
    }
  }
}
