import SwiftUI

/// Yıl özeti: hikâye akışı. Tam ekran sayfalar sırayla gelir (dokununca ileri/geri, kendiliğinden de geçer);
/// sayılar sayarak yükselir, halka ve çubuklar dolar. Son sayfada paylaşılabilir özet. Android YearSummaryScreen.
struct YearSummaryView: View {
  @Environment(\.tokens) private var tokens
  @Environment(\.dismiss) private var dismiss
  @State private var year: Int
  @State private var sharing = false

  init(year: Int? = nil) {
    _year = State(initialValue: year ?? YearSummaryStore.years().first ?? Calendar.current.component(.year, from: Date()) - 1)
  }

  var body: some View {
    let store = YearSummaryStore.shared
    ZStack {
      tokens.hero.ignoresSafeArea()
      if let summary = store.cached(year), !summary.isEmpty {
        YearStory(summary: summary, onShare: share, onClose: close)
      } else {
        VStack(spacing: 0) {
          HStack {
            Spacer()
            closeButton
          }
          .padding(.horizontal, 16).padding(.top, 8)
          Spacer()
          if let summary = store.cached(year), summary.isEmpty {
            VStack(spacing: 10) {
              Ionicon("calendar-outline", size: 40, color: Gold.s300)
              Text(t("yearSummary.emptyTitle")).font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
              Text(t("yearSummary.empty")).font(.system(size: 15)).foregroundStyle(.white.opacity(0.8)).multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
          } else if store.failed {
            VStack(spacing: 16) {
              Text(t("yearSummary.failed")).font(.system(size: 15)).foregroundStyle(.white.opacity(0.85)).multilineTextAlignment(.center)
              Button {
                Haptics.impact(.light)
                Task { await store.load(year) }
              } label: {
                Text(t("common.retry")).font(.system(size: 15, weight: .semibold)).foregroundStyle(Accent.s900)
                  .padding(.horizontal, 28).padding(.vertical, 12).background(.white, in: .capsule)
              }
              .buttonStyle(PressableStyle())
            }
            .padding(.horizontal, 32)
          } else {
            ProgressView().tint(.white)
          }
          Spacer()
        }
      }
    }
    .toolbar(.hidden, for: .navigationBar)
    .toolbar(.hidden, for: .tabBar)
    .statusBar(.light)
    .task(id: year) { await store.load(year) }
    .fullScreenCover(isPresented: $sharing) {
      if let summary = store.cached(year) { YearSummaryShareSheet(summary: summary) }
    }
  }

  private var closeButton: some View {
    Button { close() } label: {
      Ionicon("close", size: 20, color: .white).frame(width: 36, height: 36).background(.white.opacity(0.14), in: .circle)
    }
    .buttonStyle(PressableStyle())
    .accessibilityLabel(t("common.close"))
  }

  private func share() {
    Haptics.impact(.medium)
    sharing = true
    Task { await StoreReview.maybeRequest() }
  }

  private func close() {
    Haptics.impact(.light)
    dismiss()
  }
}

/// Hikâye sayfaları ve geçişleri.
private struct YearStory: View {
  let summary: YearSummary
  let onShare: () -> Void
  let onClose: () -> Void

  enum Page: Hashable { case intro, prayers, streak, byPrayer, bestMonth, quran, more, final }

  /// Değeri olmayan sayfalar atlanır.
  static func pages(_ s: YearSummary) -> [Page] {
    var list: [Page] = [.intro, .prayers]
    if s.longestStreak > 0 || s.perfectDays > 0 { list.append(.streak) }
    if s.prayers > 0 { list.append(.byPrayer) }
    if s.bestMonth != nil { list.append(.bestMonth) }
    if s.quranPages > 0 || s.hatims > 0 { list.append(.quran) }
    if !YearStoryMore.items(s).isEmpty { list.append(.more) }
    list.append(.final)
    return list
  }

  /// Sayfa başına süre (son sayfa durur).
  static let pageSeconds = 6.0

  @State private var index = 0
  @State private var elapsed = 0.0
  @State private var paused = false

  private var pages: [Page] { Self.pages(summary) }
  private var page: Page { pages[min(index, pages.count - 1)] }

  var body: some View {
    VStack(spacing: 0) {
      header
      ZStack {
        content(page)
          .id(page)
          .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.96)), removal: .opacity))
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .contentShape(.rect)
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { _ in paused = true }
          .onEnded { value in
            paused = false
            guard abs(value.translation.width) < 30, abs(value.translation.height) < 30 else {
              if value.translation.width < -60 { go(1) } else if value.translation.width > 60 { go(-1) }
              return
            }
            // Ekranın soluna dokunmak geri, sağına ileri (yazı yönünden bağımsız: hikâye düzeni).
            go(value.location.x < UIScreen.main.bounds.width * 0.3 ? -1 : 1)
          }
      )
      .accessibilityElement(children: .contain)
      .accessibilityAction(named: t("yearSummary.story.next")) { go(1) }
      .accessibilityAction(named: t("yearSummary.story.previous")) { go(-1) }
    }
    .environment(\.layoutDirection, .leftToRight)
    .task(id: index) {
      elapsed = 0
      guard page != .final else { return }
      while elapsed < Self.pageSeconds {
        try? await Task.sleep(for: .milliseconds(50))
        if Task.isCancelled { return }
        if !paused { elapsed += 0.05 }
      }
      go(1)
    }
  }

  private var header: some View {
    HStack(spacing: 10) {
      HStack(spacing: 4) {
        ForEach(pages.indices, id: \.self) { i in
          GeometryReader { g in
            ZStack(alignment: .leading) {
              Capsule().fill(.white.opacity(0.25))
              Capsule().fill(.white).frame(width: g.size.width * fill(i))
            }
          }
          .frame(height: 3)
        }
      }
      Button { onClose() } label: {
        Ionicon("close", size: 20, color: .white).frame(width: 36, height: 36).background(.white.opacity(0.14), in: .circle)
      }
      .buttonStyle(PressableStyle())
      .accessibilityLabel(t("common.close"))
    }
    .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 4)
    .accessibilityElement(children: .contain)
  }

  private func fill(_ i: Int) -> Double {
    if i < index { return 1 }
    if i > index { return 0 }
    return page == .final ? 1 : min(1, elapsed / Self.pageSeconds)
  }

  private func go(_ step: Int) {
    let next = index + step
    guard next >= 0, next < pages.count else {
      if next >= pages.count { onClose() }
      return
    }
    Haptics.impact(.light)
    withAnimation(.easeInOut(duration: 0.35)) { index = next }
  }

  @ViewBuilder
  private func content(_ page: Page) -> some View {
    switch page {
    case .intro: YearStoryIntro(year: summary.year)
    case .prayers: YearStoryPrayers(summary: summary)
    case .streak: YearStoryStreak(summary: summary)
    case .byPrayer: YearStoryByPrayer(summary: summary)
    case .bestMonth: YearStoryBestMonth(summary: summary)
    case .quran: YearStoryQuran(summary: summary)
    case .more: YearStoryMore(summary: summary)
    case .final: YearStoryFinal(summary: summary, onShare: onShare) { withAnimation(.easeInOut(duration: 0.35)) { index = 0 } }
    }
  }
}

/// Sıfırdan hedefe sayarak yükselen sayı.
private struct CountingText: View {
  let target: Int
  var duration = 1.4
  var delay = 0.2
  var size: CGFloat = 64
  var color: Color = .white
  @State private var value = 0

  var body: some View {
    Text(value.formatted(.number.locale(Localizer.shared.locale)))
      .font(.system(size: size, weight: .bold)).monospacedDigit().foregroundStyle(color)
      .contentTransition(.numericText(value: Double(value)))
      .lineLimit(1).minimumScaleFactor(0.5)
      .accessibilityLabel(target.formatted(.number.locale(Localizer.shared.locale)))
      .task {
        value = 0
        try? await Task.sleep(for: .seconds(delay))
        let steps = 40
        for i in 1...steps {
          if Task.isCancelled { return }
          let p = Double(i) / Double(steps)
          let eased = 1 - pow(1 - p, 3)
          value = Int((Double(target) * eased).rounded())
          try? await Task.sleep(for: .seconds(duration / Double(steps)))
        }
        value = target
      }
  }
}

/// Sayfa öğeleri sırayla aşağıdan belirir.
private struct Appear: ViewModifier {
  let delay: Double
  @State private var shown = false
  func body(content: Content) -> some View {
    content
      .opacity(shown ? 1 : 0)
      .offset(y: shown ? 0 : 24)
      .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(delay)) { shown = true } }
  }
}

private extension View {
  func appear(_ delay: Double) -> some View { modifier(Appear(delay: delay)) }
}

private struct StoryLabel: View {
  let text: String
  var body: some View {
    Text(text).font(.system(size: 15, weight: .semibold)).foregroundStyle(Gold.s300).textCase(nil)
  }
}

private struct YearStoryIntro: View {
  let year: Int
  @State private var scale = 0.6
  var body: some View {
    VStack(spacing: 18) {
      Ionicon("sparkles", size: 30, color: Gold.s300).appear(0.1)
      Text(String(year)).font(.system(size: 96, weight: .heavy)).monospacedDigit().foregroundStyle(.white)
        .scaleEffect(scale)
        .onAppear { withAnimation(.spring(response: 0.7, dampingFraction: 0.6).delay(0.15)) { scale = 1 } }
      Text(t("yearSummary.story.introLine1")).font(.system(size: 22, weight: .bold)).foregroundStyle(.white).multilineTextAlignment(.center).appear(0.6)
      Text(t("yearSummary.story.introLine2")).font(.system(size: 16)).foregroundStyle(.white.opacity(0.8)).multilineTextAlignment(.center).appear(0.9)
    }
    .padding(.horizontal, 32)
  }
}

private struct YearStoryPrayers: View {
  let summary: YearSummary
  @State private var ring = 0.0
  var body: some View {
    VStack(spacing: 20) {
      StoryLabel(text: t("yearSummary.story.inYear", ["year": summary.year])).appear(0)
      CountingText(target: summary.prayers, size: 76)
      Text(t("yearSummary.prayed")).font(.system(size: 20, weight: .semibold)).foregroundStyle(.white).appear(0.3)
      ZStack {
        Circle().stroke(.white.opacity(0.15), lineWidth: 12)
        Circle().trim(from: 0, to: ring).stroke(Gold.s300, style: StrokeStyle(lineWidth: 12, lineCap: .round)).rotationEffect(.degrees(-90))
        Text("%\(Int((ring * 100).rounded()))").font(.system(size: 26, weight: .bold)).monospacedDigit().foregroundStyle(.white)
          .contentTransition(.numericText(value: ring))
      }
      .frame(width: 132, height: 132)
      .padding(.top, 8)
      .onAppear { withAnimation(.easeOut(duration: 1.6).delay(0.6)) { ring = Double(summary.percent) / 100 } }
      .accessibilityLabel(t("yearSummary.percent", ["percent": summary.percent, "days": summary.days]))
      Text(t("yearSummary.percent", ["percent": summary.percent, "days": summary.days])).font(.system(size: 15)).foregroundStyle(.white.opacity(0.8))
        .multilineTextAlignment(.center).appear(1.2)
    }
    .padding(.horizontal, 32)
  }
}

private struct YearStoryStreak: View {
  let summary: YearSummary
  @State private var pulse = false
  var body: some View {
    VStack(spacing: 18) {
      Ionicon("flame", size: 64, color: Gold.s300)
        .scaleEffect(pulse ? 1.08 : 0.92)
        .onAppear { withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true } }
      StoryLabel(text: t("yearSummary.story.streakTitle")).appear(0.2)
      CountingText(target: summary.longestStreak, delay: 0.3, size: 80)
      Text(t("yearSummary.story.streakUnit")).font(.system(size: 20, weight: .semibold)).foregroundStyle(.white).appear(0.5)
      if summary.perfectDays > 0 {
        HStack(spacing: 8) {
          Ionicon("checkmark-circle", size: 18, color: Gold.s300)
          Text(t("yearSummary.perfectDays", ["count": summary.perfectDays])).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
        }
        .padding(.horizontal, 16).padding(.vertical, 10).background(.white.opacity(0.12), in: .capsule)
        .appear(1.1)
      }
    }
    .padding(.horizontal, 32)
  }
}

private struct YearStoryByPrayer: View {
  let summary: YearSummary
  @State private var grown = false

  private var top: String? {
    YearSummary.prayerOrder.max { (summary.byPrayerTime[$0] ?? 0) < (summary.byPrayerTime[$1] ?? 0) }
  }

  var body: some View {
    let maxCount = max(1, YearSummary.prayerOrder.map { summary.byPrayerTime[$0] ?? 0 }.max() ?? 1)
    VStack(alignment: .leading, spacing: 22) {
      StoryLabel(text: t("yearSummary.byPrayer")).appear(0)
      if let top {
        Text(t("yearSummary.story.topPrayer", ["prayer": prayerLabel(top)])).font(.system(size: 26, weight: .bold)).foregroundStyle(.white).appear(0.15)
      }
      VStack(spacing: 14) {
        ForEach(Array(YearSummary.prayerOrder.enumerated()), id: \.element) { i, id in
          let count = summary.byPrayerTime[id] ?? 0
          let isTop = id == top
          HStack(spacing: 12) {
            Text(prayerLabel(id)).font(.system(size: 15, weight: isTop ? .bold : .medium)).foregroundStyle(isTop ? Gold.s300 : .white)
              .frame(width: 72, alignment: .leading)
            GeometryReader { g in
              ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.12))
                Capsule().fill(isTop ? Gold.s300 : .white.opacity(0.85))
                  .frame(width: grown ? max(8, g.size.width * Double(count) / Double(maxCount)) : 8)
                  .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.4 + Double(i) * 0.15), value: grown)
              }
            }
            .frame(height: 14)
            Text("\(count)").font(.system(size: 15, weight: .semibold)).monospacedDigit().foregroundStyle(.white).frame(width: 48, alignment: .trailing)
          }
          .accessibilityElement(children: .combine)
        }
      }
    }
    .padding(.horizontal, 28)
    .onAppear { grown = true }
  }
}

private struct YearStoryBestMonth: View {
  let summary: YearSummary
  var body: some View {
    VStack(spacing: 18) {
      Ionicon("trophy", size: 56, color: Gold.s300).appear(0)
      StoryLabel(text: t("yearSummary.bestMonth")).appear(0.15)
      if let best = summary.bestMonth {
        Text(YearSummaryText.month(best.month)).font(.system(size: 52, weight: .heavy)).foregroundStyle(.white)
          .lineLimit(1).minimumScaleFactor(0.5).appear(0.35)
        HStack(spacing: 6) {
          CountingText(target: best.prayers, delay: 0.6, size: 28, color: Gold.s300)
          Text(t("yearSummary.story.prayersUnit")).font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
        }
        .appear(0.5)
      }
    }
    .padding(.horizontal, 32)
  }
}

private struct YearStoryQuran: View {
  let summary: YearSummary
  @State private var open = false
  var body: some View {
    VStack(spacing: 18) {
      Ionicon(open ? "book" : "book-outline", size: 60, color: Gold.s300)
        .rotation3DEffect(.degrees(open ? 0 : 70), axis: (x: 0, y: 1, z: 0))
        .onAppear { withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1)) { open = true } }
      StoryLabel(text: t("yearSummary.quran")).appear(0.2)
      CountingText(target: summary.quranPages, delay: 0.3, size: 76)
      Text(t("yearSummary.story.pagesUnit")).font(.system(size: 20, weight: .semibold)).foregroundStyle(.white).appear(0.5)
      if summary.hatims > 0 {
        Text(t("yearSummary.hatims", ["count": summary.hatims])).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
          .padding(.horizontal, 16).padding(.vertical, 10).background(.white.opacity(0.12), in: .capsule)
          .appear(1.1)
      }
    }
    .padding(.horizontal, 32)
  }
}

struct YearStoryMore: View {
  let summary: YearSummary

  struct Item: Identifiable {
    let icon: String
    let title: String
    let value: String
    var id: String { title }
  }

  static func items(_ s: YearSummary) -> [Item] {
    var list: [Item] = []
    if s.teheccud.count > 0 { list.append(.init(icon: "moon-outline", title: t("yearSummary.teheccud"), value: t("yearSummary.nights", ["count": s.teheccud.count]))) }
    if s.nafile.count > 0 { list.append(.init(icon: "star-outline", title: t("yearSummary.nafile"), value: t("yearSummary.rakaat", ["count": Int(s.nafile.rakaat)]))) }
    if s.fastingDays > 0 { list.append(.init(icon: "restaurant-outline", title: t("yearSummary.fasting"), value: t("yearSummary.days", ["count": s.fastingDays]))) }
    if s.kazaPaid + s.kazaMarked > 0 { list.append(.init(icon: "refresh-outline", title: t("yearSummary.kaza"), value: t("yearSummary.prayersCount", ["count": s.kazaPaid + s.kazaMarked]))) }
    if s.sadaka.count > 0 { list.append(.init(icon: "heart-outline", title: t("yearSummary.sadaka"), value: t("yearSummary.times", ["count": s.sadaka.count]))) }
    if s.duaMinutes > 0 { list.append(.init(icon: "hand-left-outline", title: t("yearSummary.dua"), value: t("yearSummary.minutes", ["count": s.duaMinutes]))) }
    if s.memorizedAyets > 0 { list.append(.init(icon: "school-outline", title: t("yearSummary.memorization"), value: t("yearSummary.ayets", ["count": s.memorizedAyets]))) }
    return list
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      StoryLabel(text: t("yearSummary.story.moreTitle")).appear(0)
      LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
        ForEach(Array(Self.items(summary).enumerated()), id: \.element.id) { i, item in
          VStack(alignment: .leading, spacing: 6) {
            Ionicon(item.icon, size: 20, color: Gold.s300)
            Text(item.title).font(.system(size: 13)).foregroundStyle(.white.opacity(0.75))
            Text(item.value).font(.system(size: 18, weight: .bold)).monospacedDigit().foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
          }
          .padding(14)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(.white.opacity(0.1), in: .rect(cornerRadius: 21))
          .accessibilityElement(children: .combine)
          .appear(0.2 + Double(i) * 0.12)
        }
      }
    }
    .padding(.horizontal, 24)
  }
}

private struct YearStoryFinal: View {
  let summary: YearSummary
  let onShare: () -> Void
  let onReplay: () -> Void

  var body: some View {
    VStack(spacing: 18) {
      StoryLabel(text: t("yearSummary.shareLabel", ["year": summary.year])).appear(0)
      VStack(spacing: 6) {
        Text(summary.prayers.formatted(.number.locale(Localizer.shared.locale))).font(.system(size: 52, weight: .bold)).monospacedDigit().foregroundStyle(.white)
        Text(t("yearSummary.prayed")).font(.system(size: 17, weight: .semibold)).foregroundStyle(.white.opacity(0.85))
        GoldDivider().padding(.vertical, 12)
        HStack(spacing: 10) {
          stat(t("yearSummary.days", ["count": summary.longestStreak]), t("yearSummary.streak"))
          stat(t("yearSummary.pages", ["count": summary.quranPages]), t("yearSummary.quran"))
          stat(t("yearSummary.days", ["count": summary.perfectDays]), t("yearSummary.fullDays"))
        }
      }
      .padding(.vertical, 24).padding(.horizontal, 16)
      .frame(maxWidth: .infinity)
      .background(.white.opacity(0.1), in: .rect(cornerRadius: 24))
      .appear(0.15)
      Text(t("yearSummary.story.closing")).font(.system(size: 20, weight: .bold)).foregroundStyle(Gold.s300).appear(0.45)
      VStack(spacing: 10) {
        Button(action: onShare) {
          HStack(spacing: 8) {
            Ionicon("share-outline", size: 18, color: Accent.s900)
            Text(t("yearSummary.share")).font(.system(size: 16, weight: .semibold)).foregroundStyle(Accent.s900)
          }
          .frame(maxWidth: .infinity).padding(.vertical, 14).background(.white, in: .capsule)
        }
        .buttonStyle(PressableStyle())
        Button {
          Haptics.impact(.light)
          onReplay()
        } label: {
          Text(t("yearSummary.story.replay")).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
            .frame(maxWidth: .infinity).padding(.vertical, 12).background(.white.opacity(0.14), in: .capsule)
        }
        .buttonStyle(PressableStyle())
      }
      .appear(0.6)
    }
    .padding(.horizontal, 24)
  }

  private func stat(_ value: String, _ label: String) -> some View {
    VStack(spacing: 3.5) {
      Text(value).font(.system(size: 17, weight: .semibold)).monospacedDigit().foregroundStyle(Gold.s300).lineLimit(1).minimumScaleFactor(0.7)
      Text(label).font(.system(size: 12)).foregroundStyle(.white.opacity(0.8)).lineLimit(1).minimumScaleFactor(0.7)
    }
    .frame(maxWidth: .infinity)
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
          Text(t("yearSummary.entryTitle", ["year": YearSummaryStore.years().first ?? Calendar.current.component(.year, from: Date()) - 1])).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
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
