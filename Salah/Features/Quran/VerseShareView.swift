import SwiftUI

enum QuranShareText {
  static func fit(_ input: String, max: Int = 600) -> String {
    let clean = input.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
    guard clean.utf16.count > max else { return clean }
    let ns = clean as NSString
    let cut = ns.substring(to: max) as NSString
    let sentence = [". ", "! ", "? "].map { cut.range(of: $0, options: .backwards).location }.filter { $0 != NSNotFound }.max()
    if let sentence, sentence > max / 2 { return cut.substring(to: sentence + 1) + " …" }
    let space = cut.range(of: " ", options: .backwards).location
    return cut.substring(to: space == NSNotFound ? max : space) + " …"
  }
}

struct VerseShareView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.tokens) private var tokens
  var verse: Verse
  var surahName: String
  @State private var shareItems: ShareItems?
  struct ShareItems: Identifiable { let id = UUID(); var values: [Any] }
  private var source: String { t("surah.shareTitle", ["name": surahName, "verse": verse.verse_number]) }

  var body: some View {
    GeometryReader { geometry in
      ScrollView {
        VStack(spacing: 20) {
          card
          HStack(spacing: 12) {
            AppButton(title: t("common.close"), variant: .secondary) { Haptics.impact(.light); dismiss() }
            AppButton(title: t("share.shareImage")) { share(width: geometry.size.width - 40) }
          }
        }.padding(.horizontal, 20).padding(.vertical, 48).frame(minHeight: geometry.size.height)
      }.scrollIndicators(.hidden)
    }.background(Color.black.opacity(0.75)).presentationBackground(.clear)
      .sheet(item: $shareItems) { item in ShareSheet(items: item.values) }
  }

  private var card: some View {
    let body = QuranShareText.fit(verse.translation.text)
    let count = body.utf16.count + verse.verse_simplified.utf16.count
    let textSize: Double = count <= 300 ? 16 : count <= 450 ? 15 : 14
    return VStack(spacing: 0) {
      Text("SALAH").font(.custom("Bungee-Regular", size: 22)).foregroundStyle(Amber.s500)
        .frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 24)
      Text(QuranFont.text(verse.verse_simplified)).font(.custom(QuranFont.name, size: verse.verse_simplified.count > 180 ? 22 : 28))
        .lineSpacing(28).foregroundStyle(Forest.s50).multilineTextAlignment(.center).environment(\.layoutDirection, .rightToLeft)
      HStack(spacing: 8) {
        Rectangle().frame(width: 40, height: 1)
        Rectangle().frame(width: 6, height: 6).rotationEffect(.degrees(45))
        Rectangle().frame(width: 40, height: 1)
      }.foregroundStyle(Gold.s300).padding(.vertical, 20)
      Text(body).font(.system(size: textSize)).lineSpacing(11).foregroundStyle(Forest.s100)
        .multilineTextAlignment(body.count > 220 ? .leading : .center)
      Text(source).font(.system(size: 13, weight: .medium)).foregroundStyle(Gold.s300).multilineTextAlignment(.center).padding(.top, 20)
    }.padding(.horizontal, 24).padding(.top, 28).padding(.bottom, 24).frame(maxWidth: .infinity)
      .background(Accent.s900, in: .rect(cornerRadius: 21))
  }

  private func share(width: CGFloat) {
    Haptics.notify(.success)
    let renderer = ImageRenderer(content: card.frame(width: width).environment(\.tokens, tokens)
      .environment(\.locale, Localizer.shared.locale).environment(\.layoutDirection, Localizer.shared.layoutDirection))
    renderer.scale = 3
    if let image = renderer.uiImage { shareItems = .init(values: [image]) }
    else { shareItems = .init(values: ["\(verse.translation.text)\n\n\(source)\n\n#SalahApp"]) }
  }
}
