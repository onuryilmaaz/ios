import SwiftUI

/// Günün okuması: günün ayeti, hadisi, duası ve esması (aynı gün aynı içerik). Panelde o güne ayet ya da hadis atanmışsa o gösterilir.
/// `embedded`: ana sayfa yığınında açıldığında Mushaf/sure bağlantıları kapalıdır (Kur'an sekmesi yığınına ait).
struct DailyReadingView: View {
  @Environment(\.tokens) private var tokens
  var embedded = false

  @State private var hadith: HadithService.Result?
  @State private var hadithFailed = false
  @State private var hadithLoading = true

  private var date: String { localDateString() }
  private var language: String { Localizer.shared.language.rawValue }
  private var panel: AppControlLogic.Content.Daily? { AppControlStore.shared.dailyItem(for: date) }

  var body: some View {
    VStack(spacing: 0) {
      StandardHeader(title: t("daily.title")) { EmptyView() }
      ScrollView {
        VStack(spacing: 10.5) {
          verseSection
          hadithSection
          duaSection
          esmaSection
        }.padding(.horizontal, 14).padding(.top, 10.5).padding(.bottom, 24)
      }.scrollIndicators(.hidden)
    }.background(tokens.canvas).toolbar(.hidden, for: .navigationBar)
      .task(id: language + date) { await loadHadith() }
  }

  // MARK: Bölümler

  @ViewBuilder
  private var verseSection: some View {
    if let panel, panel.kind != "hadith" {
      DailyTextCard(label: t("home.inspiration.verse"), icon: "book", arabic: panel.arabic, text: AppControlLogic.text(panel.text, language: language),
                    source: AppControlLogic.text(panel.source, language: language))
    } else if let ref = DailyReading.verse(date: date) {
      heading(t("home.inspiration.verse"), icon: "book")
      TopicVerseCard(ref: ref, links: !embedded).id("\(language)-\(ref.id)")
    }
  }

  @ViewBuilder
  private var hadithSection: some View {
    if let panel, panel.kind == "hadith" {
      DailyTextCard(label: t("home.inspiration.hadith"), icon: "chatbubble-ellipses", arabic: panel.arabic,
                    text: AppControlLogic.text(panel.text, language: language), source: AppControlLogic.text(panel.source, language: language))
    } else if let hadith {
      DailyTextCard(label: t("home.inspiration.hadith"), icon: "chatbubble-ellipses", arabic: "", text: hadith.text, source: hadith.bookName, collapsible: true)
    } else {
      heading(t("home.inspiration.hadith"), icon: "chatbubble-ellipses")
      Card {
        if hadithLoading {
          RoundedRectangle(cornerRadius: 4).fill(tokens.fill).frame(height: 14).accessibilityHidden(true)
        } else if hadithFailed {
          QuranEmptyView(icon: "cloud-offline-outline", title: t("topics.loadFailed"))
          AppButton(title: t("common.retry"), variant: .secondary) { Task { await loadHadith() } }
        }
      }
    }
  }

  @ViewBuilder
  private var duaSection: some View {
    if let dua = DailyReading.dua(date: date) {
      DailyTextCard(
        label: t("daily.dua"), icon: "hand-left", arabic: dua.arabic, text: dua.turkish.isEmpty ? dua.title : dua.turkish,
        source: [dua.title, dua.source].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "), collapsible: true)
    }
  }

  @ViewBuilder
  private var esmaSection: some View {
    if let esma = DailyReading.esma(date: date) {
      let isRTL = Localizer.shared.language.isRTL
      DailyTextCard(label: t("daily.esma"), icon: "sparkles", arabic: esma.arabic, arabicLarge: true, text: esma.meaning,
                    source: isRTL ? t("esma.title") : esma.name)
    }
  }

  private func heading(_ title: String, icon: String) -> some View {
    HStack(spacing: 7) {
      Ionicon(icon, size: 15, color: tokens.gold)
      Text(title).font(.system(size: 17, weight: .semibold)).foregroundStyle(tokens.textPrimary).accessibilityAddTraits(.isHeader)
      Spacer(minLength: 0)
    }.padding(.horizontal, 3.5).padding(.top, 7)
  }

  private func loadHadith() async {
    hadithLoading = true
    hadithFailed = false
    let result = await DailyReading.hadith(date: date)
    guard !Task.isCancelled else { return }
    hadith = result
    hadithFailed = result == nil
    hadithLoading = false
  }
}

/// Başlık, (isteğe bağlı) Arapça, anlam, kaynak ve paylaş düğmesi olan metin kartı.
struct DailyTextCard: View {
  @Environment(\.tokens) private var tokens
  let label: String
  let icon: String
  var arabic = ""
  var arabicLarge = false
  let text: String
  let source: String
  var collapsible = false
  @State private var expanded = false
  @State private var sharing = false

  var body: some View {
    Card {
      HStack(spacing: 7) {
        Ionicon(icon, size: 15, color: tokens.gold)
        Text(label).font(.system(size: 17, weight: .semibold)).foregroundStyle(tokens.textPrimary)
          .frame(maxWidth: .infinity, alignment: .leading).accessibilityAddTraits(.isHeader)
        Button { Haptics.impact(.light); sharing = true } label: {
          Ionicon("share-outline", size: 17, color: tokens.inkMuted).frame(width: 31.5, height: 31.5).background(tokens.fill, in: .circle)
        }.buttonStyle(PressableStyle()).accessibilityLabel(t("common.share"))
      }.padding(.bottom, 10.5)
      if !arabic.isEmpty {
        Text(arabicLarge ? arabic : QuranFont.text(arabic))
          .font(arabicLarge ? .system(size: 30) : .custom(QuranFont.name, size: 24))
          .lineSpacing(12)
          .foregroundStyle(tokens.isDark ? Forest.s100 : Forest.s900)
          .multilineTextAlignment(.leading)
          .frame(maxWidth: .infinity, alignment: .leading)
          .environment(\.layoutDirection, .rightToLeft)
          .padding(.bottom, 14)
      }
      Text(text).font(.system(size: 16)).lineSpacing(6).foregroundStyle(tokens.isDark ? Forest.s300 : Forest.s700)
        .lineLimit(collapsible && !expanded ? 6 : nil)
      if collapsible && text.count > 260 {
        Button { Haptics.impact(.light); expanded.toggle() } label: {
          Text(t(expanded ? "home.inspiration.showLess" : "home.inspiration.readMore")).font(.system(size: 15, weight: .medium))
            .foregroundStyle(tokens.isDark ? Accent.s400 : Accent.s700)
        }.buttonStyle(PressableStyle()).padding(.top, 7)
      }
      if !source.isEmpty { Text(source).font(.system(size: 13)).foregroundStyle(tokens.textSecondary).padding(.top, 14) }
    }
    .fullScreenCover(isPresented: $sharing) {
      ShareCardSheet(arabic: arabic.isEmpty ? nil : arabic, arabicLarge: arabicLarge, text: text, source: source, label: label)
        .environment(\.tokens, tokens)
    }
  }
}
