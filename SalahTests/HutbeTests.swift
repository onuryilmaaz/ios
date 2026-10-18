import Foundation
import Testing
@testable import Salah

/// RN'deki src/modules/hutbe/__tests__/hutbe.parse.test.ts ile aynı fixture ve beklentiler.
@MainActor
struct HutbeParserTests {
  final class Marker {}

  func fixture(_ name: String) throws -> String {
    let bundle = Bundle(for: Marker.self)
    let url = try #require(bundle.url(forResource: name, withExtension: nil, subdirectory: "fixtures"))
    return try String(contentsOf: url, encoding: .utf8)
  }

  @Test func sectionsFollowHeadingsInPdfOrder() throws {
    let tr = HutbeParser.text(try fixture("teblig-sorumlulugumuz.tr.txt"))
    #expect(tr.sections.map(\.heading) == [
      "Muhterem Müslümanlar!", "Aziz Müminler!", "Kıymetli Müslümanlar!",
      "Değerli Müminler!", "Kardeşlerim!", "Aziz Müslümanlar!",
    ])
    #expect(tr.sections[0].text.hasPrefix("Medineliler Allah Resûlü"))
    #expect(tr.sections[5].text.hasSuffix("kişinin yüzünü ak etsin.”"))
  }

  @Test func dropsArabicDateTitleAndSignature() throws {
    let all = HutbeParser.text(try fixture("teblig-sorumlulugumuz.tr.txt")).sections.map(\.text).joined(separator: " ")
    #expect(all.range(of: "[\u{0600}-\u{06FF}]", options: .regularExpression) == nil)
    #expect(!all.contains("Tarih:"))
    #expect(!all.contains("TEBLİĞ SORUMLULUĞUMUZ"))
    #expect(!all.contains("Genel Müdürlüğü"))
  }

  @Test func stripsInlineFootnoteNumbers() throws {
    let all = HutbeParser.text(try fixture("teblig-sorumlulugumuz.tr.txt")).sections.map(\.text).joined(separator: " ")
    #expect(all.contains("vesile oldu. Öyle ki"))
    #expect(all.contains("ev kalmadı."))
    #expect(all.contains("daha hayırlıdır” sözünü"))
  }

  @Test func footnotesSeparateAndJoined() throws {
    let tr = HutbeParser.text(try fixture("teblig-sorumlulugumuz.tr.txt"))
    #expect(tr.footnotes.count == 6)
    #expect(tr.footnotes[3] == "4 Buhârî, Cihâd, 143; Hâkim, Müstedrek, 3/598; İbnü’l-Mübarek, Zühd, I, 484.")
  }

  @Test func englishHutbeAndLineEndHyphen() throws {
    let en = HutbeParser.text(try fixture("mosque-social-life.en.txt"))
    #expect(en.sections[0].heading == "Dear Muslims!")
    #expect(en.sections.map(\.text).joined(separator: " ").contains("health and well-being for"))
    #expect(en.footnotes == ["1 Tawbah, 9/71.", "2 Muslim, Salat, 122."])
  }

  let html = """
    <script>var WPQ1ListData = { "Row" :
    [{"ID": "339","Tarih": "25.09.2026","Title": "Tebli\\u011f Sorumlulu\\u011fumuz",
    "PDF": "\\u002fDocuments\\u002fTebli%C4%9F%20Sorumlulu%C4%9Fumuz.pdf",
    "Ses": "\\u002fDocuments\\u002fSesli%20Hutbe%20(Tebli\\u011f%20Sorumlulu\\u011fumuz).mp3"}
    ,{"ID": "340","Tarih": "2.10.2026","Title": "Cami ve Sosyal Hayat",
    "PDF": "\\u002fDocuments\\u002fCami%20ve%20Sosyal%20Hayat.pdf"}
    ,{"ID": "12","Tarih": "02.10.2026","Title": "عنوان",
    "PDF": "/Documents/عنوان.pdf"}
    ],"FirstRow" : 1 };</script>
    """

  @Test func listSortsNewestFirstWithAbsoluteURLs() {
    let list = HutbeParser.list(html)
    #expect(list.map(\.id) == ["340", "12", "339"])
    #expect(list[0].pdfUrl == "https://dinhizmetleri.diyanet.gov.tr/Documents/Cami%20ve%20Sosyal%20Hayat.pdf")
    #expect(list[0].audioUrl == nil)
    #expect(list[2].title == "Tebliğ Sorumluluğumuz")
    #expect(list[2].audioUrl?.contains("/Documents/Sesli%20Hutbe%20(Tebli") == true)
    #expect(Calendar.current.component(.day, from: list[0].date) == 2)
  }

  @Test func rawArabicPathIsEncoded() {
    let ar = HutbeParser.list(html).first { $0.id == "12" }
    #expect(ar?.pdfUrl == "https://dinhizmetleri.diyanet.gov.tr/Documents/%D8%B9%D9%86%D9%88%D8%A7%D9%86.pdf")
  }

  @Test func readsPlainTableWhenNoJSON() throws {
    let list = HutbeParser.list(try fixture("list-table.tr.html"))
    #expect(list.count > 5)
    #expect(list[0].id == "340")
    #expect(list[0].title == "Cami ve Sosyal Hayat")
    #expect(Calendar.current.component(.month, from: list[0].date) == 10)
    #expect(list[0].pdfUrl == "https://dinhizmetleri.diyanet.gov.tr/Documents/Cami%20ve%20Sosyal%20Hayat.pdf")
    #expect(list[1].audioUrl == "https://dinhizmetleri.diyanet.gov.tr/Documents/Sesli%20Hutbe%20(Tebli%C4%9F%20Sorumlulu%C4%9Fumuz).mp3")
  }

  @Test func emptyWhenNoData() {
    #expect(HutbeParser.list("<html></html>").isEmpty)
  }
}
