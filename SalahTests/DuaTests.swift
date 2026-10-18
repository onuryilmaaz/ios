import Foundation
import Testing
@testable import Salah

/// RN'deki src/utils/__tests__/markdown.test.ts ile aynı girdiler.
@MainActor
struct MarkdownTests {
  @Test func blocksHeadingParagraphListItems() {
    let md = "## Abdest\nAbdest şöyle alınır:\n\n1. **Niyet:** Kalben\n2) Eller\n- Not\n* Diğer"
    #expect(Markdown.blocks(md) == [
      .heading("Abdest"),
      .paragraph("Abdest şöyle alınır:"),
      .number(marker: "1.", text: "**Niyet:** Kalben"),
      .number(marker: "2.", text: "Eller"),
      .bullet("Not"),
      .bullet("Diğer"),
    ])
  }

  @Test func blankLineSeparatesParagraphsAndLinesJoin() {
    #expect(Markdown.blocks("a\nb\n\nc") == [.paragraph("a b"), .paragraph("c")])
  }

  @Test func inlineBoldAndItalic() {
    #expect(Markdown.inline("**Yüzü Yıkamak:** üç kez *dikkatle* _yap_") == [
      .init(text: "Yüzü Yıkamak:", bold: true),
      .init(text: " üç kez "),
      .init(text: "dikkatle", italic: true),
      .init(text: " "),
      .init(text: "yap", italic: true),
    ])
  }

  @Test func unmatchedMarkersStayText() {
    #expect(Markdown.inline("5 * 3 = 15") == [.init(text: "5 * 3 = 15")])
    #expect(Markdown.inline("snake_case_name") == [.init(text: "snake_case_name")])
  }

  @Test func stripRemovesMarkers() {
    #expect(Markdown.strip("1. **Niyet:** Kalben\n- *Not*") == "1. Niyet: Kalben\n• Not")
  }
}

@MainActor
struct DuaLibraryTests {
  @Test func loadsAllCategoriesAndDuas() {
    #expect(DuaLibrary.categories.count == 7)
    #expect(DuaLibrary.allDuas.count == 19)
    #expect(Set(DuaLibrary.allDuas.map(\.id)).count == 19)
  }

  /// Her durumun önerdiği dualar veride bulunmalı (kırık id olmamalı).
  @Test func situationDuaIdsResolve() {
    for s in DuaLibrary.situations {
      #expect(DuaLibrary.duas(ids: s.duaIds).count == s.duaIds.count, "\(s.key)")
    }
  }

  @Test func keywordMatchPicksHighestScore() {
    #expect(DuaLibrary.matchSituation("Çok stres ve kaygı var")?.key == "kaygi")
    #expect(DuaLibrary.matchSituation("yarın uçak ile yolculuk")?.key == "yolculuk")
    #expect(DuaLibrary.matchSituation("merhaba") == nil)
  }

  @Test func duasKeepRequestedOrder() {
    #expect(DuaLibrary.duas(ids: ["genel-2", "genel-1"]).map(\.id) == ["genel-2", "genel-1"])
  }
}

@MainActor
struct EsmaTests {
  @Test func ninetyNineNamesInEveryLanguage() {
    #expect(EsmaLibrary.names.count == 99)
    #expect(EsmaLibrary.names.map(\.id) == Array(1...99))
  }

  /// RN `normalize` ile aynı: şapka/Türkçe karakter ve kesme işareti duyarsız.
  @Test(arguments: [("rahman", 1), ("Er Rahmân", 0), ("errahman", 1), ("merhamet", 2), ("99", 1)])
  func searchMatchesLikeRN(query: String, minCount: Int) {
    #expect(EsmaLibrary.filter(EsmaLibrary.names, query: query).count >= minCount)
  }

  @Test func normalizeStripsMarksAndApostrophes() {
    #expect(EsmaLibrary.normalize("El-Kuddûs") == "elkuddus")
    #expect(EsmaLibrary.normalize("Mü'min Şâkir") == "mumin sakir")
  }
}
