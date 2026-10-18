import SwiftUI

@Observable
final class SurahDetailModel {
  private(set) var verses: [Verse] = []
  private(set) var surah: Surah?
  private(set) var loading = true
  private(set) var tajweed: [Int: [TajweedSegment]] = [:]

  func load(_ id: Int) async {
    loading = true
    let language = Localizer.shared.language
    let all = await QuranService.surahs()
    let verses = await QuranService.surah(id)
    guard !Task.isCancelled, Localizer.shared.language == language else { return }
    self.surah = all.first { $0.id == id }
    self.verses = verses
    loading = false
    QuranAudioPlayer.shared.configure(verses)
  }
  func loadTajweed(_ id: Int) async {
    guard tajweed.isEmpty else { return }
    let result = await QuranService.tajweed(id)
    if !Task.isCancelled { tajweed = result }
  }
}

struct SurahDetailView: View {
  @Environment(\.tokens) private var tokens
  let surahID: Int
  var focusVerse: Int?
  @State private var model = SurahDetailModel()
  @State private var search = ""
  @State private var searching = false
  @State private var detail: Verse?
  @State private var share: Verse?
  @State private var initialFocus = false

  private var name: String { model.surah.map { surahName($0) } ?? t("quran.detail") }
  private var displayed: [Verse] { QuranSearch.verses(model.verses, query: search) }

  var body: some View {
    let settings = QuranReadingStore.shared.settings
    let palette = QuranReadingPalette(theme: settings.readingTheme, tokens: tokens)
    VStack(spacing: 0) {
      StandardHeader(title: model.surah.map { surahName($0, withSuffix: true) } ?? t("quran.detail"))
      if model.loading {
        VStack(spacing: 14) {
          ProgressView().tint(palette.accent)
          Text(t("surah.loading")).font(.system(size: 14, weight: .semibold)).foregroundStyle(palette.secondary)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if model.verses.isEmpty {
        VStack {
          QuranEmptyView(icon: "cloud-offline-outline", title: t("surah.loadFailed"))
          AppButton(title: t("common.retry"), variant: .secondary) { Task { await model.load(surahID) } }.padding(16)
        }.frame(maxHeight: .infinity)
      } else {
        ScrollViewReader { proxy in
          ScrollView {
            LazyVStack(spacing: 0) {
              QuranAudioControls().padding(.horizontal, 14).padding(.bottom, 14)
              options(settings).padding(.horizontal, 14).padding(.bottom, 14)
              if searching && !search.isEmpty {
                Text(t("surah.searchResults", ["count": displayed.count])).font(.system(size: 12, weight: .medium))
                  .foregroundStyle(tokens.inkSubtle).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 24).padding(.bottom, 8)
              }
              if displayed.isEmpty { QuranEmptyView(icon: "search-outline", title: t("surah.noMatch")) }
              if settings.tajweed { TajweedLegendView().padding(.horizontal, 14).padding(.bottom, 14) }
              if settings.layoutMode == .verses {
                ForEach(displayed) { verse in
                  verseCard(verse, settings: settings, palette: palette).id(verse.id).padding(.horizontal, 14).padding(.bottom, 21)
                }
              } else {
                flowingText(settings, palette: palette).padding(.horizontal, 14).padding(.bottom, 21)
              }
            }.padding(.top, 16).padding(.bottom, 24)
          }
          .scrollIndicators(.hidden)
          .onChange(of: QuranAudioPlayer.shared.activeIndex) { _, index in
            guard model.verses.indices.contains(index) else { return }
            let verse = model.verses[index]
            if settings.layoutMode == .verses && displayed.contains(where: { $0.id == verse.id }) {
              withAnimation { proxy.scrollTo(verse.id, anchor: UnitPoint(x: 0.5, y: 0.15)) }
            }
            QuranReadingStore.shared.setLastRead(surahId: surahID, name: name, verse: verse.verse_number)
          }
          .task {
            guard !initialFocus else { return }
            initialFocus = true
            let number = focusVerse ?? 1
            QuranReadingStore.shared.setLastRead(surahId: surahID, name: name, verse: number)
            if let verse = model.verses.first(where: { $0.verse_number == number }), number > 1 {
              try? await Task.sleep(for: .milliseconds(250))
              proxy.scrollTo(verse.id, anchor: .top)
            }
            if DebugLaunch.quran == "verse" { detail = model.verses.first }
            if DebugLaunch.quran == "share" { share = model.verses.first }
          }
        }
      }
    }
    .background(palette.canvas).toolbar(.hidden, for: .navigationBar)
    .task(id: "\(surahID)-\(Localizer.shared.language.rawValue)") { await model.load(surahID) }
    .task(id: settings.tajweed) { if settings.tajweed { await model.loadTajweed(surahID) } }
    .sheet(item: $detail) { verse in VerseDetailView(surahID: surahID, name: name, verse: verse).environment(\.tokens, tokens) }
    .fullScreenCover(item: $share) { verse in VerseShareView(verse: verse, surahName: name).environment(\.tokens, tokens) }
    .onAppear {
      if DebugLaunch.quran == "flow" { QuranReadingStore.shared.updateSettings { $0.layoutMode = .mushaf } }
    }
  }

  @ViewBuilder
  private func options(_ settings: QuranReadingSettings) -> some View {
    if searching {
      HStack(spacing: 7) {
        QuranSearchField(text: $search, placeholder: t("surah.searchPlaceholder"), clearLabel: t("quran.clearSearch"))
        Button { Haptics.impact(.light); search = ""; searching = false } label: {
          Ionicon("close-circle", size: 20, color: tokens.inkSubtle)
        }.buttonStyle(PressableStyle()).accessibilityLabel(t("surah.closeSearch"))
      }
    } else {
      ScrollView(.horizontal) {
        HStack(spacing: 7) {
          option("search", t("surah.searchVerse")) { searching = true }
          option("text", t(settings.fontSize.labelKey), label: t("surah.fontSize")) {
            let values = QuranFontSize.allCases
            QuranReadingStore.shared.updateSettings { $0.fontSize = values[(values.firstIndex(of: $0.fontSize)! + 1) % values.count] }
          }
          option(settings.layoutMode == .mushaf ? "book" : "list", t(settings.layoutMode == .mushaf ? "surah.modeMushaf" : "surah.modeVerse"), label: t("surah.layoutMode")) {
            QuranReadingStore.shared.updateSettings { $0.layoutMode = $0.layoutMode == .verses ? .mushaf : .verses }
          }
          option("color-palette-outline", t("surah.tajweed"), label: t("surah.tajweedToggle"), selected: settings.tajweed) {
            QuranReadingStore.shared.updateSettings { $0.tajweed.toggle() }
          }
          option(settings.readingTheme == .night ? "moon" : "contrast-outline", t(settings.readingTheme.labelKey), label: t("surah.readingTheme")) {
            let values = QuranReadingTheme.allCases
            QuranReadingStore.shared.updateSettings { $0.readingTheme = values[(values.firstIndex(of: $0.readingTheme)! + 1) % values.count] }
          }
        }
      }.scrollIndicators(.hidden)
    }
  }

  private func option(_ icon: String, _ text: String, label: String? = nil, selected: Bool = false, action: @escaping () -> Void) -> some View {
    Button { Haptics.impact(.light); action() } label: {
      HStack(spacing: 5.25) {
        Ionicon(icon, size: 14, color: selected ? tokens.accent : tokens.inkMuted)
        Text(text).font(.system(size: 10.5, weight: .semibold)).foregroundStyle(selected ? tokens.accent : tokens.textSecondary)
      }.padding(.horizontal, 10.5).padding(.vertical, 7).background(selected ? tokens.accentSoft : tokens.surface, in: .capsule)
        .overlay(Capsule().stroke(selected ? tokens.accent : tokens.line, lineWidth: 1))
    }.buttonStyle(PressableStyle()).accessibilityLabel(label ?? text)
  }

  private func verseCard(_ verse: Verse, settings: QuranReadingSettings, palette p: QuranReadingPalette) -> some View {
    let active = QuranAudioPlayer.shared.verses.indices.contains(QuranAudioPlayer.shared.activeIndex)
      && QuranAudioPlayer.shared.verses[QuranAudioPlayer.shared.activeIndex].id == verse.id
    let scale = settings.fontSize.scale
    return VStack(spacing: 0) {
      HStack {
        Text("\(verse.verse_number)").font(.system(size: 10.5, weight: .semibold)).foregroundStyle(.white)
          .frame(width: 21, height: 21).background(p.accent, in: .circle)
        Spacer()
        Button { Haptics.impact(.light); detail = verse } label: { Ionicon("book-outline", size: 18, color: p.secondary) }
          .buttonStyle(PressableStyle()).accessibilityLabel(t("surah.tafsir"))
        Button { Haptics.impact(.light); share = verse } label: { Ionicon("share-outline", size: 18, color: p.secondary) }
          .buttonStyle(PressableStyle()).accessibilityLabel(t("surah.shareVerse")).padding(.leading, 14)
      }.padding(.horizontal, 24).padding(.vertical, 12).background(active ? p.accent.opacity(0.1) : p.canvas)
      Rectangle().fill(p.line).frame(height: 1)
      VStack(alignment: .leading, spacing: 3.5) {
        if let text = verse.transcription, !text.isEmpty {
          Text(text).font(.system(size: 24 * scale)).lineSpacing(26 * scale).foregroundStyle(p.primary)
        }
        QuranArabicText(text: verse.verse_simplified, segments: settings.tajweed ? model.tajweed[verse.verse_number] : nil, color: p.arabic, accent: p.accent, size: 22 * scale)
          .padding(.vertical, 4)
        Rectangle().fill(p.line).frame(height: 1).padding(.vertical, 7)
        Text("\"\(verse.translation.text)\"").font(.system(size: 16 * scale, weight: .medium).italic()).lineSpacing(12 * scale)
          .foregroundStyle(active ? p.accent : p.secondary)
      }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16).padding(.vertical, 4)
    }
    .background(active ? p.accent.opacity(0.06) : p.surface, in: .rect(cornerRadius: 14))
    .clipShape(.rect(cornerRadius: 14))
    .overlay(RoundedRectangle(cornerRadius: 14).stroke(active ? p.accent : p.line, lineWidth: 1))
    .contentShape(.rect).onTapGesture {
      Haptics.impact(.light)
      if let index = model.verses.firstIndex(where: { $0.id == verse.id }) { QuranAudioPlayer.shared.play(index: index) }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel(t("surah.listenVerse", ["n": verse.verse_number]))
  }

  private func flowingText(_ settings: QuranReadingSettings, palette: QuranReadingPalette) -> some View {
    VStack(spacing: 12) {
      if search.isEmpty && surahID != 1 && surahID != 9 {
        QuranArabicText(text: QuranScripture.basmala, color: palette.accent, accent: palette.accent, size: 20 * settings.fontSize.scale)
      }
      displayed.reduce(Text("")) { result, verse in
        result + QuranArabicText.styled(text: verse.verse_simplified, segments: settings.tajweed ? model.tajweed[verse.verse_number] : nil,
          color: palette.arabic, accent: palette.accent, size: 26 * settings.fontSize.scale)
        + Text(" ﴿\(verse.verse_number)﴾ ").font(.system(size: 14 * settings.fontSize.scale)).foregroundColor(palette.accent)
      }.lineSpacing(30 * settings.fontSize.scale).frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.layoutDirection, .rightToLeft)
    }.padding(.horizontal, 24).padding(.vertical, 30)
      .background(palette.surface, in: .rect(cornerRadius: 14))
      .overlay(MushafDecorativeFrame(color: palette.accent))
  }
}

struct QuranAudioControls: View {
  @Environment(\.tokens) private var tokens
  @Bindable private var audio = QuranAudioPlayer.shared
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 14) {
        Button { Haptics.impact(.light); audio.toggle() } label: {
          Group {
            if audio.state == .loading { ProgressView().tint(.white) }
            else { Ionicon(audio.state == .playing ? "pause" : "play", size: 22, color: .white) }
          }.frame(width: 42, height: 42).background(tokens.isDark ? Accent.s500 : Accent.s600, in: .circle)
        }.buttonStyle(PressableStyle()).accessibilityLabel(t(audio.state == .playing ? "surah.pause" : "surah.play"))
        VStack(alignment: .leading, spacing: 7) {
          HStack(spacing: 5.25) {
            ForEach([("ar.alafasy", "Alafasy"), ("ar.abdullahbasfar", "Basfar")], id: \.0) { reciter in
              Button { Haptics.impact(.light); audio.chooseReciter(reciter.0) } label: {
                Text(reciter.1).font(.system(size: 12, weight: .bold)).foregroundStyle(audio.reciter == reciter.0 ? tokens.accent : tokens.textSecondary)
                  .padding(.horizontal, 8.75).padding(.vertical, 3.5).background(audio.reciter == reciter.0 ? tokens.accentSoft : tokens.fill, in: .rect(cornerRadius: 7))
                  .overlay(RoundedRectangle(cornerRadius: 7).stroke(audio.reciter == reciter.0 ? tokens.accent : tokens.line, lineWidth: 1))
              }.buttonStyle(PressableStyle())
            }
          }
          GeometryReader { geometry in
            ZStack(alignment: .leading) {
              Capsule().fill(tokens.fill)
              Capsule().fill(Accent.s500).frame(width: geometry.size.width * (audio.duration > 0 ? min(1, audio.position / audio.duration) : 0))
            }.frame(height: 5.25).frame(maxHeight: .infinity)
              .contentShape(.rect).gesture(DragGesture(minimumDistance: 0).onChanged { event in
                audio.seek(min(1, max(0, event.location.x / max(1, geometry.size.width))) * audio.duration)
              })
          }.frame(height: 18).environment(\.layoutDirection, .leftToRight)
          Text(audio.activeIndex >= 0 ? t("surah.nthVerse", ["n": audio.verses[audio.activeIndex].verse_number]) + (audio.duration > 0 ? " · \(time(audio.position)) / \(time(audio.duration))" : "") : t("quran.verseCount", ["count": audio.verses.count]))
            .font(.system(size: 12)).foregroundStyle(tokens.inkSubtle)
        }
      }
      if audio.failed { Text(t("surah.audioFailed")).font(.system(size: 13)).foregroundStyle(tokens.danger) }
    }.padding(14).background(tokens.surface, in: .rect(cornerRadius: 21))
      .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
  }
  private func time(_ seconds: Double) -> String { let s = max(0, Int(seconds)); return "\(s / 60):\(String(format: "%02d", s % 60))" }
}
