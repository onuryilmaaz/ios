import Foundation
import Observation

/// Çevrimdışı Kur'an. Ses sure sure ve kâri başına indirilir: `Application Support/QuranAudio/<kâri>/<sure>/<ayet kimliği>.mp3`
/// (iCloud yedeğine girmez). Metin, sure açılınca kullanılan önbelleğe (`QuranService.surah`) toplu yazılır.
/// Çalar, dosya yerelde varsa onu kullanır (`localFile`).
@MainActor
@Observable
final class QuranDownloads {
  static let shared = QuranDownloads()
  private static let storageKey = "@salah_quran_downloads_v1"
  /// Aynı anda inen dosya sayısı.
  private static let parallel = 4

  /// Tamamlanan indirmeler: "<kâri>/<sure>".
  private(set) var completed: Set<String>
  /// Süren indirmeler: anahtar → 0...1.
  private(set) var progress: [String: Double] = [:]
  /// Metin indirmesi: 0...1, yoksa nil.
  private(set) var textProgress: Double?
  /// İndirilen ses boyutu (bayt); `refreshSize` ile güncellenir.
  private(set) var audioBytes: Int64 = 0

  @ObservationIgnored private var tasks: [String: Task<Void, Never>] = [:]
  @ObservationIgnored private var textTask: Task<Void, Never>?

  private init() {
    completed = Set(LocalStore.decode([String].self, Self.storageKey) ?? [])
  }

  static func key(surah: Int, reciter: String) -> String { "\(reciter)/\(surah)" }

  enum Status: Equatable { case none, downloading(Double), done }

  func status(surah: Int, reciter: String) -> Status {
    let key = Self.key(surah: surah, reciter: reciter)
    if let p = progress[key] { return .downloading(p) }
    return completed.contains(key) ? .done : .none
  }

  /// Bu surenin herhangi bir kâriyle inmiş sesi var mı (sure listesindeki işaret).
  func hasAudio(surah: Int) -> Bool { completed.contains { $0.hasSuffix("/\(surah)") } }

  // MARK: - Dosyalar

  nonisolated static var root: URL {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    return base.appendingPathComponent("QuranAudio", isDirectory: true)
  }

  nonisolated static func folder(surah: Int, reciter: String) -> URL {
    root.appendingPathComponent(reciter, isDirectory: true).appendingPathComponent("\(surah)", isDirectory: true)
  }

  /// Ayetin indirilmiş dosyası (yoksa nil).
  nonisolated static func localFile(surah: Int, globalVerseID: Int, reciter: String) -> URL? {
    let url = folder(surah: surah, reciter: reciter).appendingPathComponent("\(globalVerseID).mp3")
    return FileManager.default.fileExists(atPath: url.path) ? url : nil
  }

  // MARK: - Ses

  func download(surah: Int, reciter: String) {
    let key = Self.key(surah: surah, reciter: reciter)
    guard tasks[key] == nil, !DebugLaunch.isIsolated else { return }
    progress[key] = 0
    tasks[key] = Task {
      let ok = await self.run(surah: surah, reciter: reciter, key: key)
      self.tasks[key] = nil
      self.progress[key] = nil
      if ok {
        self.completed.insert(key)
        UsageStore.shared.record("quran.download")
        self.persist()
      } else if !Task.isCancelled {
        Toast.error(t("quranOffline.failedTitle"), t("quranOffline.failed"))
      }
      self.refreshSize()
    }
  }

  func cancel(surah: Int, reciter: String) {
    let key = Self.key(surah: surah, reciter: reciter)
    tasks[key]?.cancel()
  }

  func delete(surah: Int, reciter: String) {
    cancel(surah: surah, reciter: reciter)
    try? FileManager.default.removeItem(at: Self.folder(surah: surah, reciter: reciter))
    completed.remove(Self.key(surah: surah, reciter: reciter))
    persist()
    refreshSize()
  }

  func deleteAll() {
    tasks.values.forEach { $0.cancel() }
    try? FileManager.default.removeItem(at: Self.root)
    completed = []
    persist()
    refreshSize()
  }

  /// İndirilenlerin listesi (sure sırasıyla).
  var items: [(surah: Int, reciter: String)] {
    completed.compactMap { key -> (Int, String)? in
      let parts = key.split(separator: "/")
      guard parts.count == 2, let surah = Int(parts[1]) else { return nil }
      return (surah, String(parts[0]))
    }.sorted { ($0.0, $0.1) < ($1.0, $1.1) }
  }

  func refreshSize() {
    Task.detached(priority: .utility) {
      let size = Self.directorySize(Self.root)
      await MainActor.run { QuranDownloads.shared.audioBytes = size }
    }
  }

  private func run(surah: Int, reciter: String, key: String) async -> Bool {
    let verses = await QuranService.surah(surah)
    guard !verses.isEmpty, !Task.isCancelled else { return false }
    let folder = Self.folder(surah: surah, reciter: reciter)
    do {
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      var root = Self.root
      try? root.setResourceValues(values)
    } catch { return false }

    let pending = verses.filter { Self.localFile(surah: surah, globalVerseID: $0.id, reciter: reciter) == nil }
    let total = verses.count
    var done = total - pending.count
    progress[key] = Double(done) / Double(max(1, total))

    // Sıradaki dosyalar: (uzak adres, hedef).
    var queue = pending.compactMap { verse -> (URL, URL)? in
      QuranAudioSequence.url(globalVerseID: verse.id, reciter: reciter).map { ($0, folder.appendingPathComponent("\(verse.id).mp3")) }
    }[...]
    guard queue.count == pending.count else { return false }
    var failed = false
    await withTaskGroup(of: Bool.self) { group in
      for _ in 0..<Self.parallel {
        guard let (remote, target) = queue.popFirst() else { break }
        group.addTask { await Self.fetch(remote, to: target) }
      }
      for await ok in group {
        if !ok || Task.isCancelled {
          failed = true
          group.cancelAll()
          break
        }
        done += 1
        progress[key] = Double(done) / Double(max(1, total))
        if let (remote, target) = queue.popFirst() {
          group.addTask { await Self.fetch(remote, to: target) }
        }
      }
    }
    return !failed && !Task.isCancelled && done == total
  }

  /// Önce geçici dosyaya iner, tam inince yerine taşınır: yarım dosya çalara gitmez.
  nonisolated private static func fetch(_ remote: URL, to target: URL) async -> Bool {
    for attempt in 0..<2 {
      if Task.isCancelled { return false }
      do {
        let (temp, response) = try await URLSession.shared.download(from: remote)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
          try? FileManager.default.removeItem(at: temp)
          if attempt == 1 { return false }
          continue
        }
        try? FileManager.default.removeItem(at: target)
        try FileManager.default.moveItem(at: temp, to: target)
        return true
      } catch {
        if attempt == 1 { return false }
      }
    }
    return false
  }

  nonisolated private static func directorySize(_ url: URL) -> Int64 {
    guard let walker = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
    var total: Int64 = 0
    for case let file as URL in walker {
      total += Int64((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
    }
    return total
  }

  private func persist() {
    LocalStore.encode(completed.sorted(), for: Self.storageKey)
  }

  // MARK: - Metin

  /// 114 surenin metnini (seçili dilde meal ile) önbelleğe alır; zaten olanlar ağa çıkmaz.
  func downloadAllText() {
    guard textTask == nil, !DebugLaunch.isIsolated else { return }
    textProgress = 0
    textTask = Task {
      var ok = 0
      for id in 1...114 {
        if Task.isCancelled { break }
        if !(await QuranService.surah(id)).isEmpty { ok += 1 }
        textProgress = Double(id) / 114
      }
      textTask = nil
      textProgress = nil
      if Task.isCancelled { return }
      if ok == 114 { Toast.success(t("quranOffline.textDone")) } else { Toast.error(t("quranOffline.failedTitle"), t("quranOffline.failed")) }
    }
  }

  func cancelText() { textTask?.cancel() }

  /// Metni önbellekte olan sure sayısı.
  var cachedTextCount: Int {
    _ = textProgress
    return (1...114).filter { LocalStore.string("QURAN_SURAH_CACHE_v2_\($0)") != nil }.count
  }
}
