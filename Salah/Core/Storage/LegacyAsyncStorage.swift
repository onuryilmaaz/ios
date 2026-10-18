import CryptoKit
import Foundation

/// RN sürümünün AsyncStorage verisini salt okunur açar.
///
/// `@react-native-async-storage` (iOS) yerleşimi:
/// `Application Support/<bundleID>/RCTAsyncLocalStorage_V1/`
/// - `manifest.json`: anahtar → değer. 1024 karakterden uzun değerlerde `null`.
/// - Uzun değerler aynı klasörde, adı anahtarın MD5'i (küçük harf hex) olan dosyada.
///
/// Bundle ID mağaza sürümüyle aynı olduğundan güncelleme sonrası klasör yerinde durur.
struct LegacyAsyncStorage {
  let directory: URL

  static var `default`: LegacyAsyncStorage? {
    let fm = FileManager.default
    return locate(support: fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
      documents: fm.urls(for: .documentDirectory, in: .userDomainMask).first, bundleID: Bundle.main.bundleIdentifier)
  }

  static func locate(support: URL?, documents: URL?, bundleID: String?) -> Self? {
    var candidates: [URL] = []
    // Güncel konum önce; eski RN/Expo dizinleri yalnız yedektir.
    for name in ["RCTAsyncLocalStorage_V1", "RNCAsyncLocalStorage_V1", "RCTAsyncLocalStorage"] {
      if let support, let bundleID {
        candidates.append(support.appendingPathComponent(bundleID).appendingPathComponent(name))
      }
      if let documents { candidates.append(documents.appendingPathComponent(name)) }
    }
    let fm = FileManager.default
    let found = candidates.first { fm.fileExists(atPath: $0.appendingPathComponent("manifest.json").path) }
      ?? candidates.first { fm.fileExists(atPath: $0.path) }
    return found.map(LegacyAsyncStorage.init(directory:))
  }

  struct Contents {
    var entries: [String: String]
    var complete: Bool
  }

  /// Tüm kayıtlar. Okunamayan tek bir değer diğerlerini engellemez.
  func allEntries() -> [String: String] {
    (try? readContents().entries) ?? [:]
  }

  func readContents() throws -> Contents {
    let manifestURL = directory.appendingPathComponent("manifest.json")
    let data = try Data(contentsOf: manifestURL)
    guard let manifest = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw CocoaError(.fileReadCorruptFile)
    }

    var out: [String: String] = [:]
    var complete = true
    for (key, value) in manifest {
      if let inline = value as? String {
        out[key] = inline
      } else if value is NSNull, let external = try? String(contentsOf: fileURL(for: key), encoding: .utf8) {
        out[key] = external
      } else {
        complete = false
      }
    }
    return Contents(entries: out, complete: complete)
  }

  func fileURL(for key: String) -> URL {
    let digest = Insecure.MD5.hash(data: Data(key.utf8))
    let name = digest.map { String(format: "%02x", $0) }.joined()
    return directory.appendingPathComponent(name)
  }
}

/// RN → native ilk açılış taşıması. Bir kez çalışır; eski dosyalar silinmez.
enum LegacyMigration {
  private static let doneKey = "native.legacyMigratedAt"

  @discardableResult
  static func runIfNeeded(defaults: UserDefaults = .standard, legacy: LegacyAsyncStorage? = .default) -> Bool {
    guard defaults.object(forKey: doneKey) == nil else { return true }
    if let legacy {
      guard let contents = try? legacy.readContents() else { return false }
      // Kısmi taşıma tekrarlandığında kullanıcı sonradan sildiği bir kaydı geri
      // getirme. Eksik harici dosyalar sonraki açılışta yeniden denenir.
      let importedKey = "native.legacyImportedKeys"
      let imported = Set(defaults.stringArray(forKey: importedKey) ?? [])
      let entries = contents.entries.filter { !imported.contains($0.key) }
      guard LocalStore.importEntries(entries, defaults: defaults) else { return false }
      defaults.set(Array(imported.union(entries.keys)), forKey: importedKey)
      guard contents.complete else { return false }
      defaults.removeObject(forKey: importedKey)
    }
    defaults.set(Date().timeIntervalSince1970, forKey: doneKey)
    return true
  }
}
