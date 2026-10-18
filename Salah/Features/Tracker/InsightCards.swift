import SwiftUI

/// Haftalık / aylık özet. RN: components/insights/RecapCard.tsx
struct RecapCard: View {
  @Environment(\.tokens) private var tokens
  @State private var period: InsightsStore.Period = .week
  @State private var sharing: InsightsStore.Recap?

  private static let prayers = ["fajr", "dhuhr", "asr", "maghrib", "isha"]

  var body: some View {
    if let recap = InsightsStore.shared.recap(period) {
      let pct = Int((Double(recap.prayers) / Double(max(1, recap.possiblePrayers)) * 100).rounded())
      let activities = ActivityType.allCases.filter { recap.activities[$0.rawValue] != nil }

      Card {
        HStack {
          segmented
          Spacer()
          Button {
            Haptics.impact(.light)
            sharing = recap
          } label: {
            Ionicon("share-outline", size: 16, color: tokens.inkMuted)
              .frame(width: 31.5, height: 31.5)
              .background(tokens.fill, in: .circle)
              .contentShape(.rect.inset(by: -8))
          }
          .buttonStyle(PressableStyle())
          .accessibilityLabel(t("insights.recap.share"))
        }

        Text(Self.range(recap))
          .font(.system(size: 13))
          .foregroundStyle(tokens.textSecondary)
          .padding(.top, 14)

        HStack(alignment: .firstTextBaseline) {
          (Text("\(recap.prayers)").font(.system(size: 34, weight: .semibold)).foregroundStyle(tokens.textPrimary)
            + Text(verbatim: " / \(recap.possiblePrayers)").font(.system(size: 17)).foregroundStyle(tokens.textSecondary))
            .tabularNumbers()
          Spacer()
          Text(verbatim: "%\(pct)")
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(tokens.isDark ? Accent.s300 : Accent.s700)
            .tabularNumbers()
        }
        .padding(.top, 3.5)

        ProgressBar(fraction: Double(pct) / 100, height: 7, fill: tokens.accent)
          .padding(.top, 7)

        HStack {
          ForEach(Array(Self.prayers.enumerated()), id: \.element) { i, p in
            if i > 0 { Spacer(minLength: 0) }
            let n = recap.byPrayerTime[p] ?? 0
            VStack(spacing: 3.5) {
              Capsule()
                .fill(tokens.fill)
                .frame(width: 8.75, height: 49)
                .overlay(alignment: .bottom) {
                  Capsule().fill(Gold.s400).frame(height: 49 * min(1, Double(n) / Double(max(1, recap.days))))
                }
                .clipShape(.capsule)
              Text(prayerLabel(p))
                .font(.system(size: 12))
                .foregroundStyle(tokens.textSecondary)
              Text("\(n)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tokens.isDark ? Forest.s200 : Forest.s700)
                .tabularNumbers()
            }
          }
        }
        .padding(.top, 14)

        HStack(spacing: 7) {
          stat(recap.perfectDays, t("insights.recap.perfectDays"))
          stat(recap.kaza, t("insights.recap.kaza"))
          stat(recap.quranPages, t("insights.recap.quranPages"))
        }
        .padding(.top, 14)

        if !activities.isEmpty {
          FlowLayout(spacing: 7) {
            ForEach(activities) { a in
              HStack(spacing: 5.25) {
                Ionicon(a.icon, size: 13, color: tokens.accent)
                Text("\(a.label) · \(recap.activities[a.rawValue] ?? 0)")
                  .font(.system(size: 13))
                  .foregroundStyle(tokens.isDark ? Accent.s200 : Accent.s700)
              }
              .padding(.horizontal, 10.5)
              .padding(.vertical, 5.25)
              .background(tokens.isDark ? Accent.s900 : Accent.s50, in: .capsule)
            }
          }
          .padding(.top, 14)
        }
      }
      .fullScreenCover(isPresented: Binding(get: { sharing != nil }, set: { if !$0 { sharing = nil } })) {
        if let sharing { RecapShareSheet(recap: sharing, range: Self.range(sharing)).environment(\.tokens, tokens) }
      }
    }
  }

  private var segmented: some View {
    HStack(spacing: 0) {
      ForEach([InsightsStore.Period.week, .month], id: \.self) { p in
        Button {
          Haptics.impact(.light)
          period = p
        } label: {
          Text(t(p == .week ? "insights.recap.week" : "insights.recap.month"))
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(period == p ? tokens.textPrimary : tokens.textSecondary)
            .padding(.horizontal, 12.25)
            .padding(.vertical, 5.25)
            .background(period == p ? (tokens.isDark ? Forest.s700 : .white) : .clear, in: .capsule)
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(period == p ? .isSelected : [])
      }
    }
    .padding(3.5)
    .background(tokens.fill, in: .capsule)
  }

  private func stat(_ value: Int, _ label: String) -> some View {
    VStack(alignment: .leading, spacing: 1.75) {
      Text("\(value)")
        .font(.system(size: 20, weight: .semibold))
        .foregroundStyle(tokens.textPrimary)
        .tabularNumbers()
      Text(label)
        .font(.system(size: 12))
        .foregroundStyle(tokens.textSecondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(10.5)
    .background(tokens.isDark ? Forest.s800 : Forest.s50, in: .rect(cornerRadius: 14))
  }

  /// "28 Eylül - 4 Ekim"
  private static func range(_ r: InsightsStore.Recap) -> String {
    let style = Date.FormatStyle.dateTime.day().month(.wide).locale(Localizer.shared.locale)
    let from = Heatmap.parse(r.from)?.formatted(style) ?? r.from
    let to = Heatmap.parse(r.to)?.formatted(style) ?? r.to
    return "\(from) - \(to)"
  }
}

/// Son 12 ayın namaz ısı haritası. RN: components/insights/HeatmapCard.tsx
struct HeatmapCard: View {
  @Environment(\.tokens) private var tokens

  private let cell: CGFloat = 12
  private let gap: CGFloat = 3

  var body: some View {
    if let history = InsightsStore.shared.history {
      let columns = Heatmap.build(history)
      let summary = Heatmap.summarize(history)
      let weekdays = Localizer.shared.list("common.weekdaysShort")

      Card {
        Text(t("insights.heatmap.title"))
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(tokens.textPrimary)
        Text(t("insights.heatmap.summary", ["prayers": summary.prayers.formatted(.number.locale(Localizer.shared.locale)), "perfect": summary.perfectDays]))
          .font(.system(size: 13))
          .foregroundStyle(tokens.textSecondary)
          .tabularNumbers()
          .padding(.top, 1.75)

        HStack(alignment: .top, spacing: 5.25) {
          // Gün etiketleri: yalnız Pzt, Çar, Cum, Paz görünür.
          VStack(alignment: .leading, spacing: gap) {
            ForEach(Array(weekdays.enumerated()), id: \.offset) { i, d in
              Text(d)
                .font(.system(size: 10))
                .foregroundStyle(tokens.isDark ? Forest.s500 : Forest.s400)
                .frame(height: cell)
                .opacity(i % 2 == 0 ? 1 : 0)
            }
          }
          .padding(.top, 18)

          ScrollViewReader { proxy in
            ScrollView(.horizontal) {
              VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                  ForEach(Array(columns.enumerated()), id: \.offset) { i, col in
                    if let month = col.monthStart {
                      Text(Self.monthName(month))
                        .font(.system(size: 10))
                        .foregroundStyle(tokens.isDark ? Forest.s500 : Forest.s400)
                        .fixedSize()
                        .offset(x: CGFloat(i) * (cell + gap))
                    }
                  }
                }
                .frame(width: CGFloat(columns.count) * (cell + gap), height: 18, alignment: .topLeading)

                HStack(spacing: gap) {
                  ForEach(Array(columns.enumerated()), id: \.offset) { i, col in
                    VStack(spacing: gap) {
                      ForEach(col.cells, id: \.date) { c in
                        RoundedRectangle(cornerRadius: 3).fill(color(c)).frame(width: cell, height: cell)
                      }
                    }
                    .id(i)
                  }
                }
              }
            }
            .scrollIndicators(.hidden)
            .defaultScrollAnchor(.trailing)
            .onAppear { proxy.scrollTo(columns.count - 1, anchor: .trailing) }
          }
        }
        .padding(.top, 14)
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(t("insights.heatmap.a11y", ["prayers": summary.prayers, "perfect": summary.perfectDays]))

        HStack {
          HStack(spacing: 5.25) {
            RoundedRectangle(cornerRadius: 3).fill(ozelColor).frame(width: 8.75, height: 8.75)
            Text(t("insights.heatmap.ozelGun")).font(.system(size: 12)).foregroundStyle(tokens.textSecondary)
          }
          Spacer()
          HStack(spacing: 3.5) {
            Text(t("insights.heatmap.less")).font(.system(size: 12)).foregroundStyle(tokens.textSecondary).padding(.trailing, 3.5)
            ForEach(0..<4, id: \.self) { level in
              RoundedRectangle(cornerRadius: 3).fill(levelColor(level)).frame(width: 8.75, height: 8.75)
            }
            Text(t("insights.heatmap.more")).font(.system(size: 12)).foregroundStyle(tokens.textSecondary).padding(.leading, 3.5)
          }
        }
        .padding(.top, 14)
      }
    }
  }

  private var ozelColor: Color { tokens.isDark ? Gold.s700.opacity(0.3) : Gold.s100 }

  private func levelColor(_ level: Int) -> Color {
    switch level {
    case 1: tokens.isDark ? Accent.s700 : Accent.s200
    case 2: tokens.isDark ? Accent.s500 : Accent.s400
    case 3: tokens.isDark ? Accent.s300 : Accent.s600
    default: tokens.fill
    }
  }

  private func color(_ c: Heatmap.Cell) -> Color {
    if c.future { return .clear }
    if c.count == 0 && c.ozelGun { return ozelColor }
    return levelColor(Heatmap.level(c.count))
  }

  private static func monthName(_ month: Int) -> String {
    let d = Calendar.current.date(from: DateComponents(year: 2026, month: month + 1, day: 1))!
    return d.formatted(.dateTime.month(.abbreviated).locale(Localizer.shared.locale))
  }
}

/// Mevcut hatmin ilerlemesi: 30 cüz. RN: components/insights/HatimCard.tsx
struct HatimCard: View {
  @Environment(\.tokens) private var tokens
  private static let juz = 30

  var body: some View {
    if let q = InsightsStore.shared.quran, q.pagesPerHatim > 0 {
      let perJuz = Double(q.pagesPerHatim) / Double(Self.juz)
      let pct = Int((Double(q.currentPages) / Double(q.pagesPerHatim) * 100).rounded())

      Card {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 1.75) {
            Text(t("insights.hatim.title", ["n": q.completedHatims + 1]))
              .font(.system(size: 17, weight: .semibold))
              .foregroundStyle(tokens.textPrimary)
            Text(t("insights.hatim.progress", ["pages": q.currentPages, "total": q.pagesPerHatim]))
              .font(.system(size: 13))
              .foregroundStyle(tokens.textSecondary)
              .tabularNumbers()
          }
          Spacer()
          Text(verbatim: "%\(pct)")
            .font(.system(size: 28, weight: .semibold))
            .foregroundStyle(tokens.isDark ? Gold.s300 : Gold.s700)
            .tabularNumbers()
        }

        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
          ForEach(0..<Self.juz, id: \.self) { i in
            let fill = min(1, max(0, (Double(q.currentPages) - Double(i) * perJuz) / perJuz))
            RoundedRectangle(cornerRadius: 7)
              .fill(tokens.fill)
              .frame(height: 24.5)
              .overlay(alignment: .bottom) {
                Rectangle().fill(tokens.isDark ? Gold.s500 : Gold.s300).frame(height: 24.5 * fill)
              }
              .overlay(alignment: .top) {
                Text("\(i + 1)")
                  .font(.system(size: 10, weight: .semibold))
                  .foregroundStyle(fill >= 0.5 ? (tokens.isDark ? Forest.s950 : Gold.s700) : Forest.s400)
                  .padding(.top, 5.25)
              }
              .clipShape(.rect(cornerRadius: 7))
          }
        }
        .padding(.top, 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(t("insights.hatim.a11y", ["pct": pct, "done": q.completedHatims]))

        HStack(spacing: 7) {
          Ionicon("book-outline", size: 15, color: tokens.inkMuted)
          Text(
            q.completedHatims > 0
              ? t("insights.hatim.completed", ["count": q.completedHatims, "pages": q.totalPages.formatted(.number.locale(Localizer.shared.locale))])
              : t("insights.hatim.hint")
          )
          .font(.system(size: 13))
          .foregroundStyle(tokens.textSecondary)
        }
        .padding(.top, 14)
      }
    }
  }
}

/// Yuvarlak uçlu ilerleme çubuğu.
struct ProgressBar: View {
  @Environment(\.tokens) private var tokens
  let fraction: Double
  var height: CGFloat = 8
  let fill: Color

  var body: some View {
    GeometryReader { geo in
      Capsule().fill(tokens.fill)
        .overlay(alignment: .leading) {
          Capsule().fill(fill).frame(width: geo.size.width * min(1, max(0, fraction)))
        }
    }
    .frame(height: height)
    .clipShape(.capsule)
  }
}
