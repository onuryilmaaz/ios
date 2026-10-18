import SwiftUI

enum QuranRoute: Hashable { case surah(Int, Int?) }
@Observable
final class QuranNavigation {
  static let shared = QuranNavigation()
  struct Page: Identifiable { var id: Int }
  var path: [QuranRoute] = []
  var mushaf: Page?
}

struct SurahBrowserView: View {
  @Environment(\.tokens) private var tokens
  @Bindable private var nav = QuranNavigation.shared
  @State private var surahs: [Surah] = []
  @State private var loading = true
  @State private var query = ""
  @State private var debugOpened = false

  var body: some View {
    NavigationStack(path: $nav.path) {
      VStack(spacing: 0) {
        StandardHeader(title: t("quran.title"), showBackButton: false) {
          ProfileButton()
        }
        QuranSearchField(text: $query, placeholder: t("quran.search"), clearLabel: t("quran.clearSearch"))
          .padding(.horizontal, 14).padding(.top, 10.5).padding(.bottom, 7)
        ScrollView {
          LazyVStack(spacing: 0) {
            if query.isEmpty && !loading { continueCards }
            if loading {
              ForEach(0..<10) { _ in
                HStack(spacing: 14) {
                  RoundedRectangle(cornerRadius: 4).fill(tokens.fill).frame(width: 20, height: 14)
                  VStack(alignment: .leading, spacing: 7) {
                    RoundedRectangle(cornerRadius: 4).fill(tokens.fill).frame(width: 140, height: 14)
                    RoundedRectangle(cornerRadius: 4).fill(tokens.fill).frame(width: 65, height: 12)
                  }
                  Spacer()
                  RoundedRectangle(cornerRadius: 4).fill(tokens.fill).frame(width: 56, height: 20)
                }.padding(.vertical, 14)
              }
            } else {
              let filtered = QuranSearch.surahs(surahs, query: query)
              if filtered.isEmpty {
                QuranEmptyView(icon: "search-outline", title: t("quran.notFound"), message: t("quran.notFoundHint"))
                if surahs.isEmpty { AppButton(title: t("common.retry"), variant: .secondary) { Task { await load() } } }
              }
              ForEach(filtered) { surah in
                Button { open(surah.id) } label: {
                  HStack(spacing: 0) {
                    Text("\(surah.id)").font(.system(size: 15)).monospacedDigit().foregroundStyle(tokens.inkSubtle).frame(width: 31.5, alignment: .leading)
                    VStack(alignment: .leading, spacing: 1.75) {
                      Text(surahName(surah)).font(.system(size: 14, weight: .medium)).foregroundStyle(tokens.textPrimary)
                      Text(t("quran.verseCount", ["count": surah.verse_count])).font(.system(size: 13)).foregroundStyle(tokens.textSecondary)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    Text(surah.name_arabic ?? "").font(.system(size: 17.5)).foregroundStyle(tokens.isDark ? Forest.s300 : Forest.s700).padding(.trailing, 10.5)
                    Ionicon(dirIcon("chevron-forward"), size: 16, color: tokens.inkSubtle)
                  }.padding(.vertical, 12.25).contentShape(.rect)
                }
                .buttonStyle(PressableStyle(pressedOpacity: 0.6))
                .accessibilityLabel(t("quran.surahA11y", ["id": surah.id, "name": surahName(surah), "count": surah.verse_count]))
                Rectangle().fill(tokens.line).frame(height: 1).padding(.leading, 31.5)
              }
            }
          }.padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 24)
        }.scrollIndicators(.hidden)
      }
      .background(tokens.canvas).toolbar(.hidden, for: .navigationBar)
      .navigationDestination(for: QuranRoute.self) { route in
        switch route { case .surah(let id, let focus): SurahDetailView(surahID: id, focusVerse: focus) }
      }
      .task { await load(); openDebug() }
    }
    .fullScreenCover(item: $nav.mushaf) { page in
      MushafReaderView(initialPage: page.id).environment(\.tokens, tokens)
    }
    .onChange(of: nav.path) {
      if nav.path.isEmpty { QuranAudioPlayer.shared.stop() }
    }
  }

  private var continueCards: some View {
    let store = QuranReadingStore.shared
    return VStack(spacing: 10.5) {
      Button {
        Haptics.impact(.light)
        nav.mushaf = .init(id: store.mushafMark?.page ?? store.mushafPage ?? 1)
      } label: {
        HStack(spacing: 10.5) {
          Ionicon("book", size: 21, color: tokens.gold).frame(width: 42, height: 42)
            .background(tokens.isDark ? Gold.s700.opacity(0.2) : Gold.s50, in: .circle)
          VStack(alignment: .leading, spacing: 1.75) {
            Text(t("mushaf.title")).font(.system(size: 17, weight: .semibold)).foregroundStyle(tokens.textPrimary)
            Text(mushafSubtitle).font(.system(size: 13)).foregroundStyle(tokens.textSecondary)
          }.frame(maxWidth: .infinity, alignment: .leading)
          Ionicon(dirIcon("chevron-forward"), size: 18, color: tokens.inkSubtle)
        }.padding(17.5).background(tokens.surface, in: .rect(cornerRadius: 21))
          .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
      }.buttonStyle(PressableStyle())
      if let last = store.lastRead {
        Button { open(last.surahId, verse: last.verseNumber) } label: {
          HStack(spacing: 10.5) {
            Ionicon("book-outline", size: 21, color: .white).frame(width: 42, height: 42).background(.white.opacity(0.15), in: .circle)
            VStack(alignment: .leading, spacing: 1.75) {
              Text(t("quran.continue")).font(.system(size: 13, weight: .medium)).foregroundStyle(Gold.s300)
              Text(t("quran.continueVerse", ["name": surahs.first(where: { $0.id == last.surahId }).map { surahName($0) } ?? last.surahName, "verse": last.verseNumber]))
                .font(.system(size: 17, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
            }.frame(maxWidth: .infinity, alignment: .leading)
            Ionicon(dirIcon("chevron-forward"), size: 18, color: .white.opacity(0.7))
          }.padding(17.5).background(tokens.isDark ? Accent.s900 : Accent.s800, in: .rect(cornerRadius: 21))
        }.buttonStyle(PressableStyle())
      }
    }.padding(.bottom, 14)
  }
  private var mushafSubtitle: String {
    let store = QuranReadingStore.shared
    if let mark = store.mushafMark { return t("mushaf.markedAt", ["page": mark.page, "line": mark.line + 1]) }
    if let page = store.mushafPage { return t("mushaf.continuePage", ["page": page]) }
    return t("mushaf.subtitle")
  }
  private func open(_ id: Int, verse: Int? = nil) { Haptics.impact(.light); nav.path.append(.surah(id, verse)) }
  private func load() async { loading = true; surahs = await QuranService.surahs(); loading = false }
  private func openDebug() {
    guard !debugOpened, let mode = DebugLaunch.quran else { return }
    debugOpened = true
    if ["detail", "flow", "verse", "share"].contains(mode) { nav.path = [.surah(1, nil)] }
    if mode == "mushaf" { nav.mushaf = .init(id: DebugLaunch.mushafPage ?? 1) }
  }
}

struct QuranSearchField: View {
  @Environment(\.tokens) private var tokens
  @Binding var text: String
  var placeholder: String
  var clearLabel: String
  var body: some View {
    HStack(spacing: 7) {
      Ionicon("search", size: 17, color: tokens.inkSubtle)
      TextField(placeholder, text: $text).font(.system(size: 14)).foregroundStyle(tokens.textPrimary).tint(tokens.accent)
        .textInputAutocapitalization(.never).autocorrectionDisabled().submitLabel(.search)
      if !text.isEmpty {
        Button { Haptics.impact(.light); text = "" } label: { Ionicon("close-circle", size: 17, color: tokens.inkSubtle) }
          .buttonStyle(PressableStyle()).accessibilityLabel(clearLabel)
      }
    }.padding(.horizontal, 12.25).frame(height: 38.5).background(tokens.surface, in: .rect(cornerRadius: 21))
      .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
  }
}

struct QuranEmptyView: View {
  @Environment(\.tokens) private var tokens
  var icon: String
  var title: String
  var message: String = ""
  var body: some View {
    VStack(spacing: 8) {
      Ionicon(icon, size: 32, color: tokens.inkSubtle)
      Text(title).font(.system(size: 17, weight: .semibold)).foregroundStyle(tokens.textPrimary)
      if !message.isEmpty { Text(message).font(.system(size: 14)).foregroundStyle(tokens.textSecondary).multilineTextAlignment(.center) }
    }.frame(maxWidth: .infinity).padding(.vertical, 32)
  }
}
