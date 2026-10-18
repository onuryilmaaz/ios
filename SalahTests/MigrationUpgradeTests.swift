import Foundation
import Testing
@testable import Salah

@MainActor
struct MigrationUpgradeTests {
  private final class Fixture {
    let directory: URL
    let suite = "salah-upgrade-\(UUID().uuidString)"
    let defaults: UserDefaults
    var storage: LegacyAsyncStorage { .init(directory: directory) }

    init() throws {
      directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
      defaults = UserDefaults(suiteName: suite)!
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    func manifest(_ values: [String: Any]) throws {
      try JSONSerialization.data(withJSONObject: values).write(to: directory.appendingPathComponent("manifest.json"))
    }
    func clean() {
      defaults.removePersistentDomain(forName: suite)
      try? FileManager.default.removeItem(at: directory)
    }
    func migrate() -> Bool { LegacyMigration.runIfNeeded(defaults: defaults, legacy: storage) }
  }

  @Test func upgradePreservesUserSettingsAndOfflineQueueExactlyOnce() throws {
    let fixture = try Fixture()
    defer { fixture.clean() }
    let user = #"{"id":"old-user","email":"fixture@example.invalid","roles":["user"],"gender":"kadin"}"#
    let queue = #"[{"id":"q_1","method":"post","url":"/prayer/track","body":{"prayer_time":"fajr","date":"2026-10-17"},"queuedAt":"2026-10-17T05:00:00.000Z"}]"#
    try fixture.manifest(["auth_user": user, "@salah_offline_queue": NSNull(), "@salah_onboarding_done": "true",
      "@salah_theme_mode": "dark", "@salah_language": "ar", "SELECTED_DISTRICT_ID": "9654"])
    try queue.write(to: fixture.storage.fileURL(for: "@salah_offline_queue"), atomically: true, encoding: .utf8)
    #expect(fixture.migrate())
    #expect(fixture.defaults.string(forKey: "rn.auth_user") == user)
    #expect(fixture.defaults.string(forKey: "rn.@salah_offline_queue") == queue)
    #expect(fixture.defaults.string(forKey: "rn.@salah_onboarding_done") == "true")
    #expect(fixture.defaults.string(forKey: "rn.@salah_theme_mode") == "dark")
    #expect(fixture.defaults.string(forKey: "rn.@salah_language") == "ar")
    #expect(fixture.defaults.string(forKey: "rn.SELECTED_DISTRICT_ID") == "9654")
    let restored = try JSONDecoder().decode([OfflineQueue.Item].self, from: Data(queue.utf8))
    #expect(restored.first?.body?["date"]?.stringValue == "2026-10-17")
    #expect(try JSONDecoder().decode(AuthUser.self, from: Data(user.utf8)).id == "old-user")
    fixture.defaults.removeObject(forKey: "rn.auth_user")
    #expect(fixture.migrate())
    #expect(fixture.defaults.string(forKey: "rn.auth_user") == nil)
    #expect(FileManager.default.fileExists(atPath: fixture.storage.fileURL(for: "@salah_offline_queue").path))
  }

  @Test func brokenManifestIsRetriedAfterRepair() throws {
    let fixture = try Fixture()
    defer { fixture.clean() }
    try "{".write(to: fixture.directory.appendingPathComponent("manifest.json"), atomically: true, encoding: .utf8)
    #expect(!fixture.migrate())
    #expect(fixture.defaults.object(forKey: "native.legacyMigratedAt") == nil)
    try fixture.manifest(["SELECTED_DISTRICT_ID": "9654"])
    #expect(fixture.migrate())
    #expect(fixture.defaults.string(forKey: "rn.SELECTED_DISTRICT_ID") == "9654")
  }

  @Test func missingExternalFileRetriesWithoutResurrectingDeletedUserOrOverwritingSettings() throws {
    let fixture = try Fixture()
    defer { fixture.clean() }
    try fixture.manifest(["auth_user": "old", "@salah_language": "tr", "@salah_offline_queue": NSNull()])
    #expect(!fixture.migrate())
    fixture.defaults.removeObject(forKey: "rn.auth_user")
    fixture.defaults.set("en", forKey: "rn.@salah_language")
    try "[]".write(to: fixture.storage.fileURL(for: "@salah_offline_queue"), atomically: true, encoding: .utf8)
    #expect(fixture.migrate())
    #expect(fixture.defaults.string(forKey: "rn.auth_user") == nil)
    #expect(fixture.defaults.string(forKey: "rn.@salah_language") == "en")
    #expect(fixture.defaults.string(forKey: "rn.@salah_offline_queue") == "[]")
  }

  @Test func existingNativeValuesAlwaysWin() throws {
    let fixture = try Fixture()
    defer { fixture.clean() }
    fixture.defaults.set("en", forKey: "rn.@salah_language")
    try fixture.manifest(["@salah_language": "tr"])
    #expect(fixture.migrate())
    #expect(fixture.defaults.string(forKey: "rn.@salah_language") == "en")
  }

  @Test func missingManifestInExistingDirectoryDoesNotFinishMigration() throws {
    let fixture = try Fixture()
    defer { fixture.clean() }
    #expect(!fixture.migrate())
    #expect(fixture.defaults.object(forKey: "native.legacyMigratedAt") == nil)
  }

  @Test func freshInstallWithoutRNStoreFinishesSafely() throws {
    let fixture = try Fixture()
    defer { fixture.clean() }
    #expect(LegacyMigration.runIfNeeded(defaults: fixture.defaults, legacy: nil))
    #expect(fixture.defaults.object(forKey: "native.legacyMigratedAt") != nil)
  }

  @Test func discoversCurrentAndOldExpoDirectoriesInPriorityOrder() throws {
    let fixture = try Fixture()
    defer { fixture.clean() }
    let support = fixture.directory.appendingPathComponent("support")
    let docs = fixture.directory.appendingPathComponent("docs")
    let old = docs.appendingPathComponent("RCTAsyncLocalStorage")
    try FileManager.default.createDirectory(at: old, withIntermediateDirectories: true)
    #expect(LegacyAsyncStorage.locate(support: support, documents: docs, bundleID: "com.test")?.directory.path == old.path)
    let current = support.appendingPathComponent("com.test/RCTAsyncLocalStorage_V1")
    try FileManager.default.createDirectory(at: current, withIntermediateDirectories: true)
    #expect(LegacyAsyncStorage.locate(support: support, documents: docs, bundleID: "com.test")?.directory.path == current.path)
  }
}

@MainActor
struct LegacyTokenMigrationTests {
  private typealias Credentials = LegacyTokenMigration.Credentials

  @Test func copiesAndVerifiesLegacyCredentialsBeforeCleanup() {
    let legacy = Credentials(access: "a", refresh: "r", stamp: 10)
    var written: Credentials?
    let result = LegacyTokenMigration.restore(sources: [legacy], current: .init()) { written = $0; return $0 }
    #expect(written == legacy)
    #expect(result.credentials == legacy)
    #expect(result.removableSources == [0])
  }

  @Test func failedKeychainWriteKeepsSourceAndReturnsOfflineFallback() {
    let legacy = Credentials(access: "a", refresh: "r", stamp: 10)
    let result = LegacyTokenMigration.restore(sources: [legacy], current: .init()) { _ in .init() }
    #expect(result.credentials == legacy)
    #expect(result.removableSources.isEmpty)
  }

  @Test func partiallyWrittenPairIsRetriedAndNeverDiscarded() {
    let legacy = Credentials(access: "a", refresh: "r", stamp: 10)
    let partial = Credentials(access: "a", stamp: 10)
    let failed = LegacyTokenMigration.restore(sources: [legacy], current: .init()) { _ in partial }
    #expect(failed.credentials == legacy)
    #expect(failed.removableSources.isEmpty)
    let retry = LegacyTokenMigration.restore(sources: [legacy], current: partial) { $0 }
    #expect(retry.credentials == legacy)
    #expect(retry.removableSources == [0])
  }

  @Test func newerWidgetCredentialsWinWithoutAnyWrite() {
    let legacy = Credentials(access: "old-a", refresh: "old-r", stamp: 10)
    let fresh = Credentials(access: "new-a", refresh: "new-r", stamp: 20)
    var wrote = false
    let result = LegacyTokenMigration.restore(sources: [legacy], current: fresh) { wrote = true; return $0 }
    #expect(!wrote)
    #expect(result.credentials == fresh)
    #expect(result.removableSources == [0])
  }

  @Test func logoutTimestampPreventsRestoringOldTokens() {
    let legacy = Credentials(access: "a", refresh: "r", stamp: 10)
    var wrote = false
    let result = LegacyTokenMigration.restore(sources: [legacy], current: .init(stamp: 20)) { wrote = true; return $0 }
    #expect(!wrote)
    #expect(!result.credentials.hasTokens)
    #expect(result.removableSources == [0])
  }

  @Test func newestOfAsyncStorageAndAppGroupWins() {
    let old = Credentials(access: "old-a", refresh: "old-r", stamp: 10)
    let fresh = Credentials(access: "new-a", refresh: "new-r", stamp: 20)
    let result = LegacyTokenMigration.restore(sources: [old, fresh], current: .init()) { $0 }
    #expect(result.credentials == fresh)
    #expect(result.removableSources == [0, 1])
  }

  @Test func unknownTimestampNeverOverwritesExistingKeychain() {
    let old = Credentials(access: "old", refresh: "old")
    let fresh = Credentials(access: "current", refresh: "current")
    var wrote = false
    let result = LegacyTokenMigration.restore(sources: [old], current: fresh) { wrote = true; return $0 }
    #expect(!wrote)
    #expect(result.credentials == fresh)
  }

  @Test func newerAccessOnlySourceDoesNotEraseValidRefreshToken() {
    let old = Credentials(access: "new-access", stamp: 20)
    let current = Credentials(access: "current-access", refresh: "current-refresh", stamp: 10)
    var wrote = false
    let result = LegacyTokenMigration.restore(sources: [old], current: current) { wrote = true; return $0 }
    #expect(!wrote)
    #expect(result.credentials == current)
    #expect(result.removableSources.isEmpty)
  }
}
