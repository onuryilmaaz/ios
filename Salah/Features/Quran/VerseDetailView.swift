import SwiftUI

struct VerseDetailView: View {
  @Environment(\.tokens) private var tokens
  @Environment(\.dismiss) private var dismiss
  var surahID: Int
  var name: String
  var verse: Verse
  @State private var wordsTab = false
  @State private var authorID = ""
  @State private var translation: VerseTranslation?
  @State private var words: [VerseWord] = []
  @State private var loading = true
  @State private var selectedWord: Int?
  @State private var arabic = ""

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text(t("quran.surahWithName", ["name": name])).font(.system(size: 12, weight: .medium)).foregroundStyle(tokens.accent)
          Text(t("surah.nthVerse", ["n": verse.verse_number])).font(.system(size: 15.75, weight: .semibold)).foregroundStyle(tokens.textPrimary)
        }
        Spacer()
        CircleIconButton(icon: "close", size: 36, iconSize: 20, accessibilityLabel: t("common.close")) { Haptics.impact(.light); dismiss() }
      }.padding(.horizontal, 17.5).padding(.vertical, 10.5)
      RowDivider(leading: 0)
      HStack(spacing: 7) {
        tab("book-outline", "verse.tabMeaning", selected: !wordsTab) { wordsTab = false }
        tab("language-outline", "verse.tabWords", selected: wordsTab) { wordsTab = true }
      }.padding(.horizontal, 17.5).padding(.top, 10.5)
      ScrollView {
        VStack(alignment: .leading, spacing: 14) {
          QuranArabicText(text: arabic.isEmpty ? verse.verse_simplified : arabic, color: tokens.textPrimary, accent: tokens.accent, size: 24)
            .padding(.horizontal, 17.5).padding(.vertical, 14).background(tokens.fill, in: .rect(cornerRadius: 14))
          if !wordsTab && QuranService.authors.count > 1 {
            ScrollView(.horizontal) {
              HStack(spacing: 7) {
                ForEach(QuranService.authors) { author in
                  Button { Haptics.impact(.light); authorID = author.id } label: {
                    Text(author.short).font(.system(size: 10.5, weight: .bold)).foregroundStyle(authorID == author.id ? tokens.accent : tokens.textSecondary)
                      .padding(.horizontal, 10.5).padding(.vertical, 7).background(authorID == author.id ? tokens.accentSoft : tokens.surface, in: .rect(cornerRadius: 10.5))
                      .overlay(RoundedRectangle(cornerRadius: 10.5).stroke(authorID == author.id ? tokens.accent : tokens.line, lineWidth: 1))
                  }.buttonStyle(PressableStyle())
                }
              }
            }.scrollIndicators(.hidden)
          }
          if loading { ProgressView().tint(tokens.accent).frame(maxWidth: .infinity).padding(.vertical, 35) }
          else if wordsTab { wordsContent }
          else if let translation {
            VStack(alignment: .leading, spacing: 4) {
              Text(translation.authorName).font(.system(size: 12, weight: .medium)).foregroundStyle(tokens.inkSubtle)
              Text(translation.text).font(.system(size: 14)).lineSpacing(8).foregroundStyle(tokens.textPrimary)
              if !translation.footnotes.isEmpty {
                Text(t("verse.footnotes")).font(.system(size: 12, weight: .medium)).foregroundStyle(tokens.accent).padding(.top, 17.5)
                ForEach(translation.footnotes) { footnote in
                  HStack(alignment: .top, spacing: 7) {
                    Text("\(footnote.number)").font(.system(size: 12, weight: .semibold)).foregroundStyle(tokens.onAccent)
                      .frame(width: 17.5, height: 17.5).background(tokens.accent, in: .circle)
                    Text(footnote.text).font(.system(size: 13)).lineSpacing(8).foregroundStyle(tokens.textSecondary)
                  }.padding(10.5).background(tokens.fill, in: .rect(cornerRadius: 14))
                }
              }
            }
          } else { Text(t("verse.loadFailed")).font(.system(size: 12.25)).foregroundStyle(tokens.textSecondary).padding(.vertical, 28) }
        }.padding(17.5).padding(.bottom, 20)
      }.scrollIndicators(.hidden)
    }
    .background(tokens.canvas)
    .presentationDetents([.fraction(0.9), .large]).presentationDragIndicator(.visible)
    .task(id: Localizer.shared.language) { authorID = QuranService.authors.first?.id ?? "diyanet" }
    .task(id: "\(authorID)-\(wordsTab)") {
      guard !authorID.isEmpty else { return }
      loading = true
      if wordsTab {
        #if DEBUG
        if DebugLaunch.quran != nil { words = QuranPreview.words(verse: verse.verse_number); loading = false; return }
        #endif
        let result = await QuranService.words(surah: surahID, verse: verse.verse_number)
        if !Task.isCancelled { words = result; loading = false }
      } else {
        let result = await QuranService.translation(surah: surahID, verse: verse.verse_number, author: authorID)
        if !Task.isCancelled { translation = result; loading = false }
      }
    }
    .task {
      if let full = await QuranService.verse(surahId: surahID, verseNumber: verse.verse_number), !Task.isCancelled { arabic = full.verse_simplified }
    }
  }

  private func tab(_ icon: String, _ key: String, selected: Bool, action: @escaping () -> Void) -> some View {
    Button { Haptics.impact(.light); selectedWord = nil; action() } label: {
      HStack(spacing: 5.25) {
        Ionicon(icon, size: 15, color: selected ? tokens.accent : tokens.inkSubtle)
        Text(t(key)).font(.system(size: 10.5, weight: .semibold)).foregroundStyle(selected ? tokens.accent : tokens.textSecondary)
      }.frame(maxWidth: .infinity).padding(.vertical, 8.75).background(selected ? tokens.accentSoft : tokens.fill, in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? tokens.accent : tokens.line, lineWidth: 1))
    }.buttonStyle(PressableStyle()).accessibilityAddTraits(selected ? .isSelected : [])
  }
  private var wordsContent: some View {
    VStack(alignment: .leading, spacing: 16) {
      if words.isEmpty { Text(t("verse.noWords")).font(.system(size: 12.25)).foregroundStyle(tokens.inkSubtle) }
      else {
        FlowLayout {
          ForEach(Array(words.enumerated()), id: \.offset) { index, word in
            Button { Haptics.impact(.light); selectedWord = selectedWord == index ? nil : index } label: {
              VStack(spacing: 2) {
                Text(QuranFont.text(word.arabic)).font(.custom(QuranFont.name, size: 21)).foregroundStyle(tokens.textPrimary)
                if let text = word.transliteration { Text(text).font(.system(size: 12, weight: .bold)).foregroundStyle(tokens.accent) }
              }.padding(.horizontal, 10.5).padding(.vertical, 7).background(selectedWord == index ? tokens.accentSoft : tokens.surface, in: .rect(cornerRadius: 21))
                .overlay(RoundedRectangle(cornerRadius: 21).stroke(selectedWord == index ? tokens.accent : tokens.line, lineWidth: 1))
            }.buttonStyle(PressableStyle())
          }
        }
        if let index = selectedWord, words.indices.contains(index) {
          VStack(alignment: .leading, spacing: 3.5) {
            QuranArabicText(text: words[index].arabic, color: tokens.textPrimary, accent: tokens.accent, size: 26.25)
            Text(words[index].transliteration ?? "").font(.system(size: 12.25, weight: .bold).italic()).foregroundStyle(tokens.accent)
            Text(words[index].meaning ?? "").font(.system(size: 12.25)).foregroundStyle(tokens.textSecondary)
          }.padding(14).background(tokens.accentSoft, in: .rect(cornerRadius: 14))
        }
        Text(t("verse.wordsNote")).font(.system(size: 12)).foregroundStyle(tokens.inkSubtle).multilineTextAlignment(.center)
      }
    }
  }
}
