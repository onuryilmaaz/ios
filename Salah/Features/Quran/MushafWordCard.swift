import AVFoundation
import SwiftUI

/// Mushafta dokunulan kelime.
struct MushafWordSelection: Identifiable {
  let word: MushafWord
  let page: Int
  var id: String { "\(page)|\(word.verse)|\(word.text)|\(word.audio ?? "")" }
}

/// Kelime sesi (quran.com kelime kelime kayıtları). Ayet çaları durdurulmaz; kısa bir kayıt.
@MainActor
final class MushafWordAudio {
  static let shared = MushafWordAudio()
  private var player: AVPlayer?

  func play(_ path: String) {
    guard let url = URL(string: "https://audio.qurancdn.com/\(path)") else { return }
    try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
    try? AVAudioSession.sharedInstance().setActive(true)
    player = AVPlayer(url: url)
    player?.play()
  }

  func stop() {
    player?.pause()
    player = nil
  }
}

/// Kelime meali kartı: Arapça kelime, okunuşu, anlamı, dinle ve ayeti aç.
struct MushafWordCard: View {
  @Environment(\.tokens) private var tokens
  let selection: MushafWordSelection
  let script: MushafScript
  let openVerse: () -> Void
  @State private var font: CGFont?

  private var verseLabel: String {
    let parts = selection.word.verse.split(separator: ":")
    return t("mushaf.wordVerse", ["surah": parts.first.map(String.init) ?? "", "verse": parts.last.map(String.init) ?? ""])
  }

  var body: some View {
    VStack(spacing: 14) {
      Text(t("mushaf.wordTitle")).font(.system(size: 13, weight: .medium)).foregroundStyle(tokens.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
      Group {
        if let font, let code = selection.word.code {
          Text(code).font(Font(CTFontCreateWithGraphicsFont(font, 46, nil, nil)))
        } else {
          Text(QuranFont.text(selection.word.text)).font(.custom(QuranFont.name, size: 40))
        }
      }
      .foregroundStyle(tokens.textPrimary).frame(height: 70).environment(\.layoutDirection, .rightToLeft)
      if let translit = selection.word.translit, !translit.isEmpty {
        Text(translit).font(.system(size: 15).italic()).foregroundStyle(tokens.textSecondary)
      }
      Text(selection.word.meaning ?? "").font(.system(size: 20, weight: .semibold)).foregroundStyle(tokens.textPrimary)
        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
      HStack(spacing: 10.5) {
        if let audio = selection.word.audio {
          AppButton(title: t("mushaf.wordListen"), variant: .secondary) {
            Haptics.impact(.light)
            MushafWordAudio.shared.play(audio)
          }
        }
        AppButton(title: verseLabel) {
          Haptics.impact(.light)
          openVerse()
        }
      }
      Spacer(minLength: 0)
    }
    .padding(17.5)
    .frame(maxWidth: .infinity)
    .background(tokens.surface)
    .task {
      guard script != .text else { return }
      font = try? await MushafFonts.font(script, page: selection.page, dark: tokens.isDark)
    }
  }
}
