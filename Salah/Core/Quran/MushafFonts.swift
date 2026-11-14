import CoreText
import Foundation

/// CGFont değişmez; iş parçacıkları arasında güvenle taşınır.
extension CGFont: @retroactive @unchecked Sendable {}

/// Medine mushafı hattı: her sayfanın kendi yazı tipi var (QCF V2 düz, V4 renkli tecvidli; quran.com/QUL).
/// Sayfa açıldıkça indirilir ve `Application Support/Mushaf/fonts/<v2|v4>/p<sayfa>.ttf` altında kalır (yedeğe girmez).
/// Yazı tipi sisteme kaydedilmez; dosyadan `CGFont` olarak açılıp son birkaç sayfa bellekte tutulur.
enum MushafFonts {
  private static var loaded: [String: CGFont] = [:]
  private static var order: [String] = []
  private static var inflight: [String: Task<CGFont, Error>] = [:]
  /// Aynı dosya (açık ve koyu sürüm aynı anda istense de) bir kez iner.
  private static var downloads: [String: Task<Void, Error>] = [:]

  nonisolated static func folder(_ script: MushafScript) -> String { script == .tajweed ? "v4" : "v2" }

  nonisolated static func remote(_ script: MushafScript, page: Int) -> URL {
    let path = script == .tajweed ? "v4/colrv1/ttf" : "v2/ttf"
    return URL(string: "https://verses.quran.foundation/fonts/quran/hafs/\(path)/p\(page).ttf")!
  }

  nonisolated static func file(_ script: MushafScript, page: Int) -> URL {
    MushafService.root.appendingPathComponent("fonts/\(folder(script))/p\(page).ttf")
  }

  nonisolated static func hasFile(_ script: MushafScript, page: Int) -> Bool {
    FileManager.default.fileExists(atPath: file(script, page: page).path)
  }

  /// Sayfanın yazı tipi; yoksa indirir.
  static func font(_ script: MushafScript, page: Int, dark: Bool = false) async throws -> CGFont {
    let tinted = dark && script == .tajweed
    let key = "\(folder(script))/\(page)\(tinted ? "d" : "")"
    if let font = loaded[key] { return font }
    if let task = inflight[key] { return try await task.value }
    let task = Task<CGFont, Error> {
      if let font = open(file(script, page: page), dark: tinted) { return font }
      guard !DebugLaunch.isIsolated else { throw URLError(.notConnectedToInternet) }
      try await downloadOnce(script, page: page)
      guard let font = open(file(script, page: page), dark: tinted) else { throw URLError(.cannotDecodeContentData) }
      return font
    }
    inflight[key] = task
    defer { inflight[key] = nil }
    let font = try await task.value
    loaded[key] = font
    order.removeAll { $0 == key }
    order.append(key)
    if order.count > 10 { loaded[order.removeFirst()] = nil }
    return font
  }

  private static func downloadOnce(_ script: MushafScript, page: Int) async throws {
    let key = "\(folder(script))/\(page)"
    if let task = downloads[key] { return try await task.value }
    let task = Task<Void, Error> { try await download(script, page: page) }
    downloads[key] = task
    defer { downloads[key] = nil }
    try await task.value
  }

  /// Bellekteki yazı tipi (indirme beklemeden çizim için).
  static func cached(_ script: MushafScript, page: Int, dark: Bool = false) -> CGFont? {
    loaded["\(folder(script))/\(page)\(dark && script == .tajweed ? "d" : "")"]
  }

  nonisolated static func download(_ script: MushafScript, page: Int) async throws {
    var request = URLRequest(url: remote(script, page: page))
    request.timeoutInterval = 30
    let (temp, response) = try await URLSession.shared.download(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
    let target = file(script, page: page)
    let dir = target.deletingLastPathComponent()
    if !FileManager.default.fileExists(atPath: dir.path) {
      try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      var folder = MushafService.root
      try? folder.setResourceValues(values)
    }
    try? FileManager.default.removeItem(at: target)
    try FileManager.default.moveItem(at: temp, to: target)
    // Bozuk ya da yarım dosya kalmasın.
    guard open(target) != nil else {
      try? FileManager.default.removeItem(at: target)
      throw URLError(.cannotDecodeContentData)
    }
  }

  nonisolated private static func open(_ url: URL, dark: Bool = false) -> CGFont? {
    guard var data = try? Data(contentsOf: url) else { return nil }
    if dark, let tinted = darkPalette(data) { data = tinted }
    guard let provider = CGDataProvider(data: data as CFData) else { return nil }
    return CGFont(provider)
  }

  /// Tecvidli yazı tipinin koyu zemin sürümü: renk tablosunda (CPAL) 1. takım koyu zemin içindir (temel harfler beyaz).
  /// Sistem yalnız 0. takımı kullandığından, bellekteki kopyada 0. takım 1. takımın renklerini gösterecek şekilde yönlendirilir.
  nonisolated static func darkPalette(_ data: Data) -> Data? {
    var bytes = [UInt8](data)
    func u16(_ o: Int) -> Int { Int(bytes[o]) << 8 | Int(bytes[o + 1]) }
    func u32(_ o: Int) -> Int { u16(o) << 16 | u16(o + 2) }
    guard bytes.count > 12 else { return nil }
    let tables = u16(4)
    for i in 0..<tables {
      let entry = 12 + i * 16
      guard entry + 16 <= bytes.count else { return nil }
      guard bytes[entry] == 0x43, bytes[entry + 1] == 0x50, bytes[entry + 2] == 0x41, bytes[entry + 3] == 0x4C else { continue } // "CPAL"
      let offset = u32(entry + 8)
      guard offset + 14 <= bytes.count, u16(offset + 4) >= 2 else { return nil }
      // Başlık: sürüm, takım başına renk, takım sayısı, renk kaydı sayısı, renk dizisi ofseti (4), sonra takım başlangıçları.
      bytes[offset + 12] = bytes[offset + 14]
      bytes[offset + 13] = bytes[offset + 15]
      return Data(bytes)
    }
    return nil
  }

  /// Satır genişliği (verilen boyutta): sayfa yazı boyutunu en geniş satıra göre ayarlamak için.
  nonisolated static func width(_ text: String, font: CTFont) -> CGFloat {
    let attributed = NSAttributedString(string: text, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])
    return CTLineGetTypographicBounds(CTLineCreateWithAttributedString(attributed), nil, nil, nil)
  }
}
