import SwiftUI

/// Yıl özeti: kılınan vakitler, seri, en iyi ay, Kur'an, teheccüd, oruç, sadaka, kaza; paylaşılabilir kart.
struct YearSummaryView: View {
  @Environment(\.tokens) private var tokens
  @State private var year = YearSummaryStore.years().first ?? 2026
  @State private var sharing = false

  var body: some View {
    let store = YearSummaryStore.shared
    let summary = store.cached(year)
    VStack(spacing: 0) {
      StandardHeader(title: t("yearSummary.title"))
      ScrollView {
        VStack(alignment: .leading, spacing: 14) {
          HStack(spacing: 7) {
            ForEach(YearSummaryStore.years(), id: \.self) { value in
              Chip(title: String(value), selected: value == year) {
                Haptics.impact(.light)
                year = value
              }
            }
          }
          if let summary {
            if summary.isEmpty {
              EmptyState(icon: "calendar-outline", title: t("yearSummary.emptyTitle"), message: t("yearSummary.empty"))
            } else {
              content(summary)
            }
          } else if store.failed {
            VStack(spacing: 16) {
              Text(t("yearSummary.failed")).font(.system(size: 15)).foregroundStyle(tokens.textSecondary).multilineTextAlignment(.center)
              AppButton(title: t("common.retry")) { Task { await store.load(year) } }.frame(width: 180)
            }.frame(maxWidth: .infinity).padding(.vertical, 24)
          } else {
            ProgressView().tint(tokens.accent).frame(maxWidth: .infinity).padding(40)
          }
        }
        .padding(16).padding(.bottom, 24)
      }
      .scrollIndicators(.hidden)
    }
    .background(tokens.canvas)
    .toolbar(.hidden, for: .navigationBar)
    .task(id: year) { await store.load(year) }
    .fullScreenCover(isPresented: $sharing) {
      if let summary { YearSummaryShareSheet(summary: summary) }
    }
  }

  @ViewBuilder
  private func content(_ s: YearSummary) -> some View {
    hero(s)
    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10.5), GridItem(.flexible(), spacing: 10.5)], spacing: 10.5) {
      tile("flame", t("yearSummary.streak"), t("yearSummary.days", ["count": s.longestStreak]), gold: true)
      if let best = s.bestMonth {
        tile("trophy-outline", t("yearSummary.bestMonth"), YearSummaryText.month(best.month), detail: t("yearSummary.prayersCount", ["count": best.prayers]))
      }
      tile("book-outline", t("yearSummary.quran"), t("yearSummary.pages", ["count": s.quranPages]),
        detail: s.hatims > 0 ? t("yearSummary.hatims", ["count": s.hatims]) : nil)
      if s.teheccud.count > 0 {
        tile("moon-outline", t("yearSummary.teheccud"), t("yearSummary.nights", ["count": s.teheccud.count]),
          detail: t("yearSummary.rakaat", ["count": Int(s.teheccud.rakaat)]))
      }
      if s.nafile.count > 0 {
        tile("star-outline", t("yearSummary.nafile"), t("yearSummary.rakaat", ["count": Int(s.nafile.rakaat)]))
      }
      if s.fastingDays > 0 { tile("restaurant-outline", t("yearSummary.fasting"), t("yearSummary.days", ["count": s.fastingDays])) }
      if s.kazaPaid > 0 || s.kazaMarked > 0 {
        tile("refresh-outline", t("yearSummary.kaza"), t("yearSummary.prayersCount", ["count": s.kazaPaid + s.kazaMarked]))
      }
      if s.sadaka.count > 0 { tile("heart-outline", t("yearSummary.sadaka"), t("yearSummary.times", ["count": s.sadaka.count])) }
      if s.duaMinutes > 0 { tile("hand-left-outline", t("yearSummary.dua"), t("yearSummary.minutes", ["count": s.duaMinutes])) }
      if s.memorizedAyets > 0 { tile("school-outline", t("yearSummary.memorization"), t("yearSummary.ayets", ["count": s.memorizedAyets])) }
    }
    byPrayer(s)
    AppButton(title: t("yearSummary.share")) {
      Haptics.impact(.medium)
      sharing = true
      Task { await StoreReview.maybeRequest() }
    }
    .padding(.top, 7)
  }

  private func hero(_ s: YearSummary) -> some View {
    VStack(alignment: .leading, spacing: 7) {
      Text(String(s.year)).font(.system(size: 15, weight: .semibold)).foregroundStyle(Gold.s300).monospacedDigit()
      HStack(alignment: .firstTextBaseline, spacing: 7) {
        Text(s.prayers.formatted(.number.locale(Localizer.shared.locale))).font(.system(size: 44, weight: .bold)).monospacedDigit()
        Text(t("yearSummary.prayed")).font(.system(size: 17, weight: .semibold))
      }.foregroundStyle(.white)
      ProgressView(value: Double(s.percent), total: 100).tint(Gold.s300).padding(.vertical, 3.5)
      Text(t("yearSummary.percent", ["percent": s.percent, "days": s.days])).font(.system(size: 13)).foregroundStyle(.white.opacity(0.8))
      Text(t("yearSummary.perfectDays", ["count": s.perfectDays])).font(.system(size: 13, weight: .semibold)).foregroundStyle(Gold.s300)
    }
    .padding(17.5)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(tokens.isDark ? Accent.s900 : Accent.s800, in: .rect(cornerRadius: 21))
  }

  private func tile(_ icon: String, _ title: String, _ value: String, detail: String? = nil, gold: Bool = false) -> some View {
    VStack(alignment: .leading, spacing: 5.25) {
      Ionicon(icon, size: 18, color: gold ? tokens.gold : tokens.accent)
      Text(title).font(.system(size: 13)).foregroundStyle(tokens.textSecondary)
      Text(value).font(.system(size: 17, weight: .semibold)).foregroundStyle(tokens.textPrimary).monospacedDigit().lineLimit(1).minimumScaleFactor(0.8)
      Text(detail ?? " ").font(.system(size: 12)).foregroundStyle(tokens.textSecondary).monospacedDigit()
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(tokens.surface, in: .rect(cornerRadius: 21))
    .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
    .accessibilityElement(children: .combine)
  }

  private func byPrayer(_ s: YearSummary) -> some View {
    let maxCount = max(1, YearSummary.prayerOrder.map { s.byPrayerTime[$0] ?? 0 }.max() ?? 1)
    return VStack(alignment: .leading, spacing: 10.5) {
      Text(t("yearSummary.byPrayer")).font(.system(size: 15, weight: .semibold)).foregroundStyle(tokens.textPrimary)
      ForEach(YearSummary.prayerOrder, id: \.self) { id in
        let count = s.byPrayerTime[id] ?? 0
        HStack(spacing: 10.5) {
          Text(prayerLabel(id)).font(.system(size: 13)).foregroundStyle(tokens.textSecondary).frame(width: 64, alignment: .leading)
          GeometryReader { g in
            Capsule().fill(tokens.fill)
              .overlay(alignment: .leading) { Capsule().fill(tokens.accent).frame(width: max(6, g.size.width * Double(count) / Double(maxCount))) }
          }.frame(height: 8)
          Text("\(count)").font(.system(size: 13, weight: .semibold)).foregroundStyle(tokens.textPrimary).monospacedDigit().frame(width: 44, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
      }
    }
    .padding(17.5)
    .background(tokens.surface, in: .rect(cornerRadius: 21))
    .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
  }
}

enum YearSummaryText {
  /// Ay adı seçili dilde (bağımsız biçim: "Mart").
  static func month(_ month: Int) -> String {
    let formatter = DateFormatter()
    formatter.locale = Localizer.shared.locale
    let names = formatter.standaloneMonthSymbols ?? []
    guard (1...12).contains(month), names.count == 12 else { return "\(month)" }
    return names[month - 1].capitalized(with: Localizer.shared.locale)
  }
}

/// Paylaşılan görsel: yıl, kılınan vakit, seri ve öne çıkan üç sayı.
private struct YearSummaryShareSheet: View {
  let summary: YearSummary

  var body: some View {
    ShareImageSheet(fallbackText: t("yearSummary.shareText", ["year": summary.year, "count": summary.prayers])) { card }
  }

  private var card: some View {
    VStack(spacing: 0) {
      ShareCardHeader(label: t("yearSummary.shareLabel", ["year": summary.year]))
      Text(summary.prayers.formatted(.number.locale(Localizer.shared.locale))).font(.system(size: 52, weight: .bold)).monospacedDigit().foregroundStyle(Forest.s50)
      Text(t("yearSummary.prayed")).font(.system(size: 17, weight: .semibold)).foregroundStyle(Forest.s100)
      GoldDivider().padding(.vertical, 17.5)
      HStack(spacing: 10.5) {
        stat(t("yearSummary.days", ["count": summary.longestStreak]), t("yearSummary.streak"))
        stat(t("yearSummary.pages", ["count": summary.quranPages]), t("yearSummary.quran"))
        stat(t("yearSummary.days", ["count": summary.perfectDays]), t("yearSummary.fullDays"))
      }
    }
  }

  private func stat(_ value: String, _ label: String) -> some View {
    VStack(spacing: 3.5) {
      Text(value).font(.system(size: 17, weight: .semibold)).monospacedDigit().foregroundStyle(Gold.s300).lineLimit(1).minimumScaleFactor(0.7)
      Text(label).font(.system(size: 12)).foregroundStyle(Forest.s100).lineLimit(1).minimumScaleFactor(0.7)
    }.frame(maxWidth: .infinity)
  }
}

/// İbadet ekranındaki giriş kartı.
struct YearSummaryEntryCard: View {
  @Environment(\.tokens) private var tokens
  let action: () -> Void

  var body: some View {
    Button {
      Haptics.impact(.light)
      action()
    } label: {
      HStack(spacing: 10.5) {
        Ionicon("sparkles-outline", size: 19, color: Gold.s300)
          .frame(width: 38.5, height: 38.5).background(.white.opacity(0.12), in: .circle)
        VStack(alignment: .leading, spacing: 2) {
          Text(t("yearSummary.entryTitle", ["year": YearSummaryStore.years().first ?? 2026])).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
          Text(t("yearSummary.entrySub")).font(.system(size: 13)).foregroundStyle(.white.opacity(0.8))
        }
        Spacer(minLength: 0)
        Ionicon(dirIcon("chevron-forward"), size: 16, color: .white.opacity(0.8))
      }
      .padding(14)
      .background(tokens.isDark ? Accent.s900 : Accent.s800, in: .rect(cornerRadius: 21))
    }
    .buttonStyle(PressableStyle(pressedOpacity: 0.85))
  }
}
