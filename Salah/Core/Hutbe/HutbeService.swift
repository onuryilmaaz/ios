import AVFoundation
import Foundation
import PDFKit

/// Diyanet Cuma hutbeleri: liste, metin ve önbellek. RN: modules/hutbe/hutbe.service.ts
/// (aynı sayfalar, aynı önbellek anahtarları ve biçimi).
enum HutbeService {
  enum Lang: String, Sendable { case tr, en, ar }

  static var lang: Lang { Lang(rawValue: Localizer.shared.language.rawValue) ?? .tr }

  /// Diyanet Din Hizmetleri hutbe sayfaları (dil başına).
  static func pageURL(_ lang: Lang) -> String {
    switch lang {
    case .tr: "\(HutbeParser.base)/kategoriler/yayinlarimiz/hutbeler/t%C3%BCrk%C3%A7e"
    case .en: "\(HutbeParser.base)/kategoriler/yayinlarimiz/hutbeler/english-(ingilizce)"
    case .ar:
      // JS `encodeURIComponent('عربي')` (Arapça harfler de kodlanır).
      "\(HutbeParser.base)/kategoriler/yayinlarimiz/hutbeler/\("عربي".addingPercentEncoding(withAllowedCharacters: uriComponentAllowed) ?? "")-(arap%C3%A7a)"
    }
  }

  private static let uriComponentAllowed = CharacterSet(
    charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.!~*'()")

  /// Arapça PDF'ten metin bozuk çıkıyor: o dilde PDF açılır.
  static func canReadInApp(_ lang: Lang) -> Bool { lang != .ar }

  private struct CachedList: Codable {
    var fetchedAt: Double
    var items: [HutbeParser.Item]
  }

  private static func listKey(_ lang: Lang) -> String { "HUTBE_LIST_V1_\(lang.rawValue)" }
  private static func textKey(_ lang: Lang, _ id: String) -> String { "HUTBE_TEXT_V1_\(lang.rawValue)_\(id)" }
  /// Hutbe haftada bir değişir; liste 6 saatten tazeyse ağa çıkılmaz.
  private static let freshMs: Double = 6 * 3600 * 1000
  private static let browserUA =
    "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

  private static var nowMs: Double { Date().timeIntervalSince1970 * 1000 }

  /// Önbellekteki liste (anında göstermek için).
  static func cachedList(_ lang: Lang) -> [HutbeParser.Item]? {
    LocalStore.decode(CachedList.self, listKey(lang))?.items
  }

  /// Liste (yeniden eskiye, en fazla 12). Önbellek tazeyse ağa çıkmaz; ağ hatasında
  /// bayat önbelleğe düşer, o da yoksa hata fırlatır.
  static func list(_ lang: Lang, force: Bool = false) async throws -> [HutbeParser.Item] {
    let cached = LocalStore.decode(CachedList.self, listKey(lang))
    if !force, let cached, nowMs - cached.fetchedAt < freshMs { return cached.items }
    do {
      guard !DebugLaunch.isIsolated else { throw URLError(.notConnectedToInternet) }
      let items = HutbeParser.list(try await fetchHTML(pageURL(lang)))
      guard !items.isEmpty else { throw URLError(.cannotParseResponse) }
      let top = Array(items.prefix(12))
      LocalStore.encode(CachedList(fetchedAt: nowMs, items: top), for: listKey(lang))
      return top
    } catch {
      if let items = cached?.items, !items.isEmpty { return items }
      throw error
    }
  }

  /// Metin (bölümler + dipnotlar). Bir kez çekilip saklanır; hutbe değişmez.
  static func text(_ lang: Lang, item: HutbeParser.Item) async throws -> HutbeParser.Parsed {
    if let cached = LocalStore.decode(HutbeParser.Parsed.self, textKey(lang, item.id)), !cached.sections.isEmpty { return cached }
    guard canReadInApp(lang), let raw = item.pdfUrl, let url = URL(string: raw), !DebugLaunch.isIsolated else {
      throw URLError(.resourceUnavailable)
    }
    var request = URLRequest(url: url)
    request.timeoutInterval = 30
    let (data, response) = try await URLSession.shared.data(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 200, let document = PDFDocument(data: data) else {
      throw URLError(.cannotDecodeContentData)
    }
    let parsed = HutbeParser.text(readingOrderText(document))
    guard !parsed.sections.isEmpty else { throw URLError(.zeroByteResource) }
    LocalStore.encode(parsed, for: textKey(lang, item.id))
    return parsed
  }

  private static func fetchHTML(_ url: String) async throws -> String {
    var request = URLRequest(url: URL(string: url)!)
    request.timeoutInterval = 15
    // Sunucu tarayıcı olmayan isteklere listeyi JSON'suz veriyor; tarayıcı gibi görün.
    request.setValue(browserUA, forHTTPHeaderField: "User-Agent")
    request.setValue("text/html", forHTTPHeaderField: "Accept")
    let (data, response) = try await URLSession.shared.data(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
    return String(decoding: data, as: UTF8.self)
  }

  /// Hutbe PDF'leri iki sütunludur; PDFKit'in düz metni sütunları karıştırır. Satırlar
  /// sütunlarına ayrılıp her sütun yukarıdan aşağı okunur: önce sol, sonra sağ.
  /// RN: widget-src/SalahHutbeModule.swift (aynı algoritma).
  static func readingOrderText(_ document: PDFDocument) -> String {
    var out: [String] = []
    for index in 0..<document.pageCount {
      guard let page = document.page(at: index) else { continue }
      let box = page.bounds(for: .mediaBox)
      guard let selection = page.selection(for: box) else { continue }
      var left: [(CGRect, String)] = []
      var right: [(CGRect, String)] = []
      for line in selection.selectionsByLine() {
        guard let text = line.string?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { continue }
        let rect = line.bounds(for: page)
        if rect.minX < box.midX - 10 { left.append((rect, text)) } else { right.append((rect, text)) }
      }
      for column in [left, right] {
        // PDF koordinatında y yukarı doğru artar; aynı satırdaki parçalar soldan sağa.
        let ordered = column.sorted { a, b in abs(a.0.midY - b.0.midY) > 3 ? a.0.midY > b.0.midY : a.0.minX < b.0.minX }
        out.append(contentsOf: ordered.map(\.1))
      }
    }
    return out.joined(separator: "\n")
  }
}

/// Sesli hutbe: oynat/duraklat, 15 sn ileri/geri, ilerleme. RN: HutbeScreen `AudioBar` (expo-audio).
@Observable
final class HutbeAudio {
  private(set) var playing = false
  private(set) var buffering = false
  private(set) var position: Double = 0
  private(set) var duration: Double = 0

  @ObservationIgnored private var player: AVPlayer?
  @ObservationIgnored private var timeObserver: Any?
  @ObservationIgnored private var endObserver: NSObjectProtocol?
  @ObservationIgnored private var url: URL?

  func load(_ raw: String) {
    stop()
    url = URL(string: raw)
    position = 0
    duration = 0
  }

  func toggle() {
    if playing {
      player?.pause()
      playing = false
      return
    }
    guard let url, !DebugLaunch.isIsolated else { return }
    // Kur'an ve ezan sesiyle üst üste çalmasın.
    QuranAudioPlayer.shared.stop()
    AdhanPlayer.shared.stop()
    try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
    try? AVAudioSession.sharedInstance().setActive(true)
    if player == nil {
      let audio = AVPlayer(url: url)
      player = audio
      buffering = true
      timeObserver = audio.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] time in
        Task { @MainActor in
          guard let self else { return }
          self.position = time.seconds.isFinite ? time.seconds : 0
          let d = self.player?.currentItem?.duration.seconds ?? 0
          self.duration = d.isFinite ? d : 0
          self.buffering = self.player?.timeControlStatus == .waitingToPlayAtSpecifiedRate
        }
      }
      endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: audio.currentItem, queue: .main) { [weak self] _ in
        Task { @MainActor in self?.playing = false }
      }
    } else if duration > 0, position >= duration - 1 {
      player?.seek(to: .zero)
    }
    player?.play()
    playing = true
  }

  func skip(_ delta: Double) {
    guard let player else { return }
    let to = max(0, min(duration, position + delta))
    position = to
    player.seek(to: CMTime(seconds: to, preferredTimescale: 600))
  }

  func stop() {
    player?.pause()
    if let timeObserver { player?.removeTimeObserver(timeObserver) }
    if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
    timeObserver = nil
    endObserver = nil
    player = nil
    playing = false
    buffering = false
  }
}
