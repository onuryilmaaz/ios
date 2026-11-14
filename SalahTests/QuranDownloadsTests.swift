import Foundation
import Testing
@testable import Salah

@MainActor
struct QuranDownloadsTests {
  @Test func folderLayoutAndMissingFile() {
    let folder = QuranDownloads.folder(surah: 108, reciter: "ar.alafasy")
    #expect(folder.path.hasSuffix("QuranAudio/ar.alafasy/108"))
    #expect(QuranDownloads.localFile(surah: 108, globalVerseID: 999_999, reciter: "ar.alafasy") == nil)
  }

  @Test func keyFormat() {
    #expect(QuranDownloads.key(surah: 2, reciter: "ar.abdullahbasfar") == "ar.abdullahbasfar/2")
  }
}
