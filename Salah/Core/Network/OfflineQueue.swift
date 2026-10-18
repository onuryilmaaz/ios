import Foundation
import Network

/// Çevrimdışı mutation kuyruğu. RN'deki services/offlineQueue.service.ts ile
/// aynı anahtar ve kayıt biçimi (`@salah_offline_queue`): RN'de bekleyen
/// kayıtlar güncellemeden sonra buradan gönderilir.
///
/// FIFO oynatılır; "işaretle → geri al" gibi ardışık işlemler sırayla gitmeli.
@Observable
final class OfflineQueue {
  static let shared = OfflineQueue(
    read: { LocalStore.decode([Item].self, key) ?? [] },
    write: { LocalStore.encode($0, for: key) },
    send: { item in
      try await APIClient.shared.send(item.method.uppercased(), item.url, body: item.body)
    },
    canFlush: { !DebugLaunch.isIsolated && AuthStore.shared.isAuthenticated }
  )

  struct Item: Codable, Equatable {
    var id: String
    var method: String
    var url: String
    var body: JSONValue?
    var clientRef: String?
    var queuedAt: String
  }

  private static let key = "@salah_offline_queue"
  private static let maxSize = 300

  private(set) var pendingCount = 0
  private(set) var isFlushing = false
  /// Başarılı gönderim sonrası (store'lar sunucudan tazelenir).
  @ObservationIgnored var onFlushed: ((Int) -> Void)?

  @ObservationIgnored private let readItems: @MainActor () -> [Item]
  @ObservationIgnored private let writeItems: @MainActor ([Item]) -> Void
  @ObservationIgnored private let send: @MainActor (Item) async throws -> Void
  @ObservationIgnored private let canFlush: @MainActor () -> Bool

  /// Testlerde yalnız bellekte depo ve sahte gönderici kullanılır.
  init(
    read: @escaping @MainActor () -> [Item],
    write: @escaping @MainActor ([Item]) -> Void,
    send: @escaping @MainActor (Item) async throws -> Void,
    canFlush: @escaping @MainActor () -> Bool = { true }
  ) {
    readItems = read
    writeItems = write
    self.send = send
    self.canFlush = canFlush
    pendingCount = read().count
  }

  func enqueue(method: String, url: String, body: JSONValue?, clientRef: String? = nil) {
    let item = Item(
      id: "q_\(Int(Date().timeIntervalSince1970 * 1000))_\(String(UUID().uuidString.prefix(6)).lowercased())",
      method: method,
      url: url,
      body: body,
      clientRef: clientRef,
      queuedAt: ISO8601DateFormatter.withFractionalSeconds.string(from: Date())
    )
    write(Array((read() + [item]).suffix(Self.maxSize)))
  }

  /// Kuyrukta HÂLÂ bekleyen kayıtların clientRef'leri: hangi iyimser (offline)
  /// kaydın gerçekten sunucuya gitmediğini bilmenin tek güvenilir yolu.
  func pendingClientRefs() -> Set<String> {
    Set(read().compactMap(\.clientRef))
  }

  /// Sunucuya hiç gitmemiş offline kaydı iptal eder.
  func remove(clientRef: String) {
    write(read().filter { $0.clientRef != clientRef })
  }

  /// Henüz gönderilmemiş isteğin gövdesini günceller (offline kayıt düzenleme).
  @discardableResult
  func update(clientRef: String, _ transform: (JSONValue?) -> JSONValue?) -> Bool {
    var queue = read()
    guard let i = queue.firstIndex(where: { $0.clientRef == clientRef }) else { return false }
    queue[i].body = transform(queue[i].body)
    write(queue)
    return true
  }

  /// - Başarılı → düşer. Kalıcı 4xx → düşer, devam.
  /// - Oturum/izin, timeout, hız sınırı, 5xx ve ağ hatası → kayıt korunur.
  @discardableResult
  func flush() async -> Int {
    guard canFlush() else { return 0 }
    guard !isFlushing else { return 0 }
    guard !read().isEmpty else { return 0 }
    isFlushing = true
    defer { isFlushing = false }

    var synced = 0
    while canFlush(), let item = read().first {
      do {
        try await send(item)
        synced += 1
      } catch {
        if error.isNetworkError { break }
        // Refresh servisi 503 döndüğünde asıl istek hâlâ 401 olabilir.
        // Yetki, zaman aşımı ve hız sınırı hataları da yeniden denenmelidir.
        guard let status = (error as? APIError)?.status, (400..<500).contains(status),
          ![401, 403, 408, 429].contains(status) else { break }
      }
      // await sırasında ekleme/silme/düzenleme yapılmış olabilir. Yalnız
      // gönderilen kaydı güncel depodan çıkar; eski kopya yenileri ezmesin.
      write(read().filter { $0.id != item.id })
    }
    if synced > 0 { onFlushed?(synced) }
    return synced
  }

  private func read() -> [Item] {
    readItems()
  }

  private func write(_ items: [Item]) {
    writeItems(items)
    pendingCount = items.count
  }
}

/// Bağlantı gelince kuyruğu boşaltır.
@Observable
final class NetworkMonitor {
  static let shared = NetworkMonitor()

  private(set) var isOnline = true
  @ObservationIgnored private let monitor = NWPathMonitor()

  private init() {
    monitor.pathUpdateHandler = { path in
      let online = path.status == .satisfied
      Task { @MainActor in
        let cameOnline = online && !NetworkMonitor.shared.isOnline
        NetworkMonitor.shared.isOnline = online
        if cameOnline { await OfflineQueue.shared.flush() }
      }
    }
    monitor.start(queue: DispatchQueue(label: "salah.network"))
  }
}

extension ISO8601DateFormatter {
  nonisolated(unsafe) static let withFractionalSeconds: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
  }()
}
