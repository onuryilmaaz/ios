import SwiftUI

/// Ayet (ya da ayet aralığı) için "dinle / durdur" düğmesi. Tek çalar: başka bir ayet çalarken bu durur.
/// Ses mevcut `QuranAudioPlayer` ve seçili kâriyle; indirilmiş ayet çevrimdışı çalar. Hata: ağ yoksa Toast.
struct VerseListenButton: View {
  @Environment(\.tokens) private var tokens
  let refs: [TopicRef]
  /// Düğmenin yanında metin de göster ("Dinle" / "Durdur").
  var showsTitle = false
  var playKey = "listen.play"
  var stopKey = "listen.stop"
  @State private var ids: [Int] = []
  private let audio = QuranAudioPlayer.shared

  private var active: Bool { !ids.isEmpty && audio.state != .idle && audio.verses.map(\.id) == ids }

  var body: some View {
    Button { Haptics.impact(.light); toggle() } label: {
      HStack(spacing: 5) {
        if active, audio.state == .loading { ProgressView().controlSize(.small).tint(tokens.accent) }
        else { Ionicon(active ? "stop" : "volume-high", size: 16, color: active ? tokens.accent : tokens.inkMuted) }
        if showsTitle { Text(t(active ? stopKey : playKey)).font(.system(size: 13, weight: .semibold)).foregroundStyle(active ? tokens.accent : tokens.inkMuted) }
      }
      .frame(minWidth: 31.5, minHeight: 31.5).padding(.horizontal, showsTitle ? 10.5 : 0)
      .background(active ? tokens.accent.opacity(0.12) : tokens.fill, in: .capsule)
    }
    .buttonStyle(PressableStyle()).accessibilityLabel(t(active ? stopKey : playKey))
    .task(id: refs.map(\.id).joined(separator: ",")) { ids = await VerseAudio.verses(refs).map(\.id) }
    .onChange(of: audio.failed) { _, failed in
      if failed, !ids.isEmpty, audio.verses.map(\.id) == ids { Toast.error(t("surah.audioFailed")) }
    }
  }

  private func toggle() {
    if active { audio.stop(); return }
    Task {
      let verses = await VerseAudio.verses(refs)
      guard !verses.isEmpty else { Toast.error(t("surah.audioFailed")); return }
      audio.configure(verses)
      audio.repeatMode = .off
      audio.play(index: 0)
    }
  }
}

/// Ekrandan çıkınca ayet sesini durdurur.
extension View {
  func stopsVerseAudioOnDisappear() -> some View {
    onDisappear { QuranAudioPlayer.shared.stop() }
  }
}
