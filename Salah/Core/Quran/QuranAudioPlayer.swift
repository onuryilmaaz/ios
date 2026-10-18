import AVFoundation

/// Ayet sesleri global ayet kimliğiyle okunur; arama listesi sırayı değiştirmez.
@Observable
final class QuranAudioPlayer {
  static let shared = QuranAudioPlayer()
  enum State { case idle, loading, playing, paused }
  private(set) var state = State.idle
  private(set) var activeIndex = -1
  private(set) var position: Double = 0
  private(set) var duration: Double = 0
  private(set) var failed = false
  private(set) var reciter = "ar.alafasy"
  private(set) var verses: [Verse] = []
  var repeatMode = QuranRepeatMode.off
  @ObservationIgnored private var player: AVPlayer?
  @ObservationIgnored private var statusObservation: NSKeyValueObservation?
  @ObservationIgnored private var endObserver: NSObjectProtocol?
  @ObservationIgnored private var timeObserver: Any?
  @ObservationIgnored private var generation = 0

  func configure(_ verses: [Verse]) {
    if self.verses.map(\.id) != verses.map(\.id) { stop() }
    self.verses = verses
  }
  func chooseReciter(_ id: String) {
    guard ["ar.alafasy", "ar.abdullahbasfar"].contains(id), reciter != id else { return }
    stop()
    reciter = id
  }
  func toggle() {
    switch state {
    case .idle: play(index: 0)
    case .loading: break
    case .playing: player?.pause(); state = .paused
    case .paused: player?.play(); state = .playing
    }
  }
  func play(index: Int) {
    guard verses.indices.contains(index), let url = QuranAudioSequence.url(globalVerseID: verses[index].id, reciter: reciter) else { stop(); return }
    stop()
    guard !DebugLaunch.isIsolated else { return }
    // Ezan ve Kur'an aynı ses oturumunda üst üste çalmasın.
    AdhanPlayer.shared.stop()
    activeIndex = index
    state = .loading
    let version = generation
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, mode: .default)
      try session.setActive(true)
    } catch { failed = true; state = .idle; return }
    let item = AVPlayerItem(url: url)
    let audio = AVPlayer(playerItem: item)
    player = audio
    statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
      let status = item.status.rawValue
      Task { @MainActor in
        guard let self, self.generation == version else { return }
        if status == AVPlayerItem.Status.readyToPlay.rawValue {
          self.duration = self.player?.currentItem?.duration.seconds.finiteOrZero ?? 0
          self.player?.play()
          self.state = .playing
        } else if status == AVPlayerItem.Status.failed.rawValue {
          self.stop()
          self.failed = true
        }
      }
    }
    timeObserver = audio.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main) { [weak self] time in
      let seconds = time.seconds
      Task { @MainActor in
        guard let self, self.generation == version else { return }
        self.position = seconds.finiteOrZero
        self.duration = self.player?.currentItem?.duration.seconds.finiteOrZero ?? 0
      }
    }
    endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
      Task { @MainActor in
        guard let self, self.generation == version else { return }
        if let next = QuranAudioSequence.next(index: self.activeIndex, count: self.verses.count, repeatMode: self.repeatMode) { self.play(index: next) }
        else { self.stop() }
      }
    }
  }
  func seek(_ seconds: Double) {
    guard seconds.isFinite, duration > 0 else { return }
    position = min(duration, max(0, seconds))
    player?.seek(to: CMTime(seconds: position, preferredTimescale: 600))
  }
  func stop() {
    generation += 1
    player?.pause()
    if let timeObserver { player?.removeTimeObserver(timeObserver) }
    timeObserver = nil
    statusObservation = nil
    if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
    endObserver = nil
    player = nil
    activeIndex = -1
    position = 0
    duration = 0
    state = .idle
    failed = false
  }
}

private extension Double {
  var finiteOrZero: Double { isFinite ? max(0, self) : 0 }
}
