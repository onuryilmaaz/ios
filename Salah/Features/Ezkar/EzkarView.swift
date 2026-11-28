import SwiftUI

/// Sabah ve akşam zikirleri: Sabah/Akşam seçici, ilerleme ve sayaçlı kartlar. Kart ya da sayaç düğmesine dokununca 1 artar,
/// sayı hedefe ulaşınca kart tamamlanır ve sıradaki karta geçilir; uzun basınca sayaç sıfırlanır. İlerleme yerelde, gün ve oturum başına.
struct EzkarView: View {
  @Environment(\.tokens) private var tokens
  private let progress = EzkarProgressStore.shared

  @State private var session: EzkarSession
  @State private var cards: [EzkarCard]
  @State private var verses: [String: TopicVerseText] = [:]
  @State private var versesFailed = false
  @State private var scrollTarget: String?

  init(initial: EzkarSession? = nil) {
    let start = initial ?? EzkarCatalog.defaultSession(now: Date(), ikindi: EzkarCatalog.todayIkindi())
    _session = State(initialValue: start)
    _cards = State(initialValue: EzkarCatalog.cards(start))
  }

  private var language: String { Localizer.shared.language.rawValue }
  private var specs: [EzkarSpec] { cards.map(\.spec) }
  private var doneCount: Int { progress.completedCount(session, specs: specs) }
  private var allDone: Bool { progress.isComplete(session, specs: specs) }

  var body: some View {
    VStack(spacing: 0) {
      StandardHeader(title: t("ezkar.title")) { EmptyView() }
      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack(spacing: 10.5) {
            picker
            summary
            ForEach(cards) { card in
              EzkarCardView(card: card, session: session, verse: verses[card.id], versesFailed: versesFailed && card.spec.kind == "quran" && verses[card.id] == nil,
                            count: progress.count(session, card.id), onTap: { tap(card) }, onReset: { reset(card) }, onRetry: { Task { await loadVerses() } })
                .id(card.id)
            }
          }.padding(.horizontal, 14).padding(.top, 10.5).padding(.bottom, 24)
        }.scrollIndicators(.hidden)
          .onChange(of: scrollTarget) { _, id in
            guard let id else { return }
            withAnimation(.easeInOut(duration: 0.35)) { proxy.scrollTo(id, anchor: .top) }
            scrollTarget = nil
          }
      }
    }.background(tokens.canvas).toolbar(.hidden, for: .navigationBar).stopsVerseAudioOnDisappear()
      .onChange(of: session) { cards = EzkarCatalog.cards(session) }
      .onChange(of: language) { verses = [:]; cards = EzkarCatalog.cards(session) }
      .task(id: "\(session.rawValue)-\(language)") { await loadVerses() }
  }

  // MARK: Üst bölüm

  private var picker: some View {
    HStack(spacing: 7) {
      ForEach(EzkarSession.allCases, id: \.self) { item in
        let selected = item == session
        Button {
          guard !selected else { return }
          Haptics.impact(.light)
          QuranAudioPlayer.shared.stop()
          session = item
        } label: {
          HStack(spacing: 7) {
            Ionicon(item == .morning ? "sunny-outline" : "moon-outline", size: 17, color: selected ? .white : tokens.inkMuted)
            Text(t(item.labelKey)).font(.system(size: 15, weight: .semibold)).foregroundStyle(selected ? .white : tokens.textPrimary)
          }.frame(maxWidth: .infinity).padding(.vertical, 10.5)
            .background(selected ? (tokens.isDark ? Accent.s700 : Accent.s600) : tokens.surface, in: .rect(cornerRadius: 21))
            .overlay(RoundedRectangle(cornerRadius: 21).stroke(selected ? .clear : tokens.line, lineWidth: 1))
        }.buttonStyle(PressableStyle()).accessibilityAddTraits(selected ? .isSelected : [])
      }
    }
  }

  @ViewBuilder
  private var summary: some View {
    VStack(alignment: .leading, spacing: 7) {
      HStack {
        if allDone {
          Ionicon("checkmark-circle", size: 17, color: tokens.accent)
          Text(t(session == .morning ? "ezkar.doneMorning" : "ezkar.doneEvening")).font(.system(size: 15, weight: .semibold)).foregroundStyle(tokens.accent)
        } else {
          Text(t("ezkar.tapToCount")).font(.system(size: 13)).foregroundStyle(tokens.textSecondary)
        }
        Spacer(minLength: 0)
        Text(t("ezkar.progress", ["done": doneCount, "total": specs.count])).font(.system(size: 15, weight: .semibold)).monospacedDigit()
          .foregroundStyle(tokens.textPrimary)
      }
      GeometryReader { geometry in
        ZStack(alignment: .leading) {
          Capsule().fill(tokens.fill)
          Capsule().fill(Accent.s500).frame(width: geometry.size.width * (specs.isEmpty ? 0 : Double(doneCount) / Double(specs.count)))
        }
      }.frame(height: 5.25).environment(\.layoutDirection, .leftToRight)
    }.padding(.horizontal, 3.5)
  }

  // MARK: İşlemler

  private func tap(_ card: EzkarCard) {
    let completed = progress.tap(session, card.spec)
    if completed {
      Haptics.notify(.success)
      // Sıradaki tamamlanmamış karta kaydır.
      let list = cards
      if let index = list.firstIndex(where: { $0.id == card.id }),
        let next = (list[(index + 1)...] + list[..<index]).first(where: { !progress.isDone($0.spec, session) }) {
        scrollTarget = next.id
      }
      if allDone { sessionCompleted() }
    } else if progress.count(session, card.id) > 0 {
      Haptics.impact(.light)
    }
  }

  private func reset(_ card: EzkarCard) {
    Haptics.impact(.light)
    progress.reset(session, card.id)
  }

  /// Tamamlanan oturumun o günkü hatırlatması bir sonraki planlamada kurulmaz.
  private func sessionCompleted() {
    let prefs = NotificationStore.shared.preferences
    guard prefs.enabled, prefs.ezkarMorning || prefs.ezkarEvening else { return }
    Task { await NotificationStore.shared.reschedule() }
  }

  private func loadVerses() async {
    versesFailed = false
    var failed = false
    for spec in EzkarCatalog.specs(session) where spec.kind == "quran" {
      guard verses[spec.id] == nil, let ref = spec.ref else { continue }
      if let loaded = await VerseTextCache.load(ref, limit: 12) { verses[spec.id] = loaded } else { failed = true }
      if Task.isCancelled { return }
    }
    versesFailed = failed
  }
}

private struct EzkarCardView: View {
  @Environment(\.tokens) private var tokens
  let card: EzkarCard
  let session: EzkarSession
  let verse: TopicVerseText?
  let versesFailed: Bool
  let count: Int
  let onTap: () -> Void
  let onReset: () -> Void
  let onRetry: () -> Void

  private var target: Int { card.spec.target }
  private var done: Bool { count >= target }
  private var isQuran: Bool { card.spec.kind == "quran" }
  private var arabic: String { isQuran ? verse?.arabic ?? "" : card.arabic }
  private var meaning: String { isQuran ? verse?.text ?? "" : card.meaning }
  private var source: String { isQuran ? verse?.source ?? "" : card.source }
  private var showsTransliteration: Bool { Localizer.shared.language != .ar && !card.transliteration.isEmpty }

  var body: some View {
    Card {
      HStack(spacing: 7) {
        Text(card.title).font(.system(size: 17, weight: .semibold)).foregroundStyle(tokens.textPrimary)
          .frame(maxWidth: .infinity, alignment: .leading).accessibilityAddTraits(.isHeader)
        if let ref = card.spec.ref { VerseListenButton(refs: VerseAudio.refs(surah: ref.s, from: ref.a, to: ref.to)) }
      }.padding(.bottom, 10.5)
      if isQuran && verse == nil {
        if versesFailed {
          QuranEmptyView(icon: "cloud-offline-outline", title: t("ezkar.loadFailed"))
          AppButton(title: t("common.retry"), variant: .secondary, action: onRetry)
        } else { skeleton }
      } else {
        if !arabic.isEmpty {
          Text(QuranFont.text(arabic))
            .font(.custom(QuranFont.name, size: 24)).lineSpacing(12)
            .foregroundStyle(tokens.isDark ? Forest.s100 : Forest.s900)
            .multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.layoutDirection, .rightToLeft).padding(.bottom, 14)
        }
        if showsTransliteration {
          Text(card.transliteration).font(.system(size: 14).italic()).lineSpacing(5).foregroundStyle(tokens.textSecondary).padding(.bottom, 10.5)
        }
        if !meaning.isEmpty {
          Text(meaning).font(.system(size: 16)).lineSpacing(6).foregroundStyle(tokens.isDark ? Forest.s300 : Forest.s700)
        }
        if !source.isEmpty { Text(source).font(.system(size: 13)).foregroundStyle(tokens.textSecondary).padding(.top, 14) }
      }
      counter.padding(.top, 14)
    }
    .opacity(done ? 0.62 : 1)
    .overlay { if done { RoundedRectangle(cornerRadius: 21).stroke(tokens.accent.opacity(0.5), lineWidth: 1) } }
    .contentShape(.rect(cornerRadius: 21))
    .onTapGesture(perform: onTap)
    .onLongPressGesture(minimumDuration: 0.6, perform: onReset)
    .accessibilityElement(children: .contain)
    .accessibilityHint(t("ezkar.tapToCount"))
  }

  private var counter: some View {
    HStack(spacing: 10.5) {
      Button(action: onTap) {
        HStack(spacing: 7) {
          if done { Ionicon("checkmark-circle", size: 18, color: .white) }
          Text(done ? t("ezkar.done") : t("ezkar.progress", ["done": count, "total": target])).font(.system(size: 15, weight: .semibold)).monospacedDigit()
            .foregroundStyle(.white)
        }.padding(.horizontal, 17.5).frame(height: 38.5)
          .background(done ? tokens.accent : (tokens.isDark ? Accent.s700 : Accent.s600), in: .capsule)
      }.buttonStyle(PressableStyle()).disabled(done)
      if target > 1 {
        Text(t("ezkar.times", ["count": target])).font(.system(size: 13)).foregroundStyle(tokens.textSecondary)
      }
      Spacer(minLength: 0)
      if count > 0 {
        Text(t("ezkar.resetHint")).font(.system(size: 12)).foregroundStyle(tokens.inkSubtle).lineLimit(1)
      }
    }
  }

  private var skeleton: some View {
    VStack(alignment: .leading, spacing: 10.5) {
      RoundedRectangle(cornerRadius: 4).fill(tokens.fill).frame(height: 26)
      RoundedRectangle(cornerRadius: 4).fill(tokens.fill).frame(height: 14)
      RoundedRectangle(cornerRadius: 4).fill(tokens.fill).frame(width: 180, height: 14)
    }.frame(maxWidth: .infinity, alignment: .leading).accessibilityHidden(true)
  }
}
