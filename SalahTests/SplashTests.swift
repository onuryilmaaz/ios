import Foundation
import Testing
@testable import Salah

@MainActor
struct SplashTests {
  @Test(arguments: [false, true])
  func finishesWithoutNetworkOrRealTime(reduceMotion: Bool) async throws {
    var events: [SplashSequence.Event] = []
    var elapsed: Duration = .zero
    try await SplashSequence.run(reduceMotion: reduceMotion, sleep: { elapsed += $0 }) {
      events.append($0)
    }
    #expect(events.suffix(2) == [.fade, .finish])
    #expect(events.filter { $0 == .finish }.count == 1)
    #expect(elapsed == (reduceMotion ? .milliseconds(700) : .milliseconds(1365)))
    if reduceMotion {
      // Hareketi Azalt: döndürme, yaylanma ve halka animasyonu yok; marka hemen görünür.
      #expect(events == [.showBrand, .fade, .finish])
    } else {
      #expect(events.compactMap { event -> Int? in
        if case .revealLetter(let index) = event { return index }
        return nil
      } == [1, 2, 3, 4, 5])
    }
  }

  @Test func cancelledBeforeStartingDoesNotChangeScreen() async {
    var events: [SplashSequence.Event] = []
    let task = Task { @MainActor in
      try await SplashSequence.run(reduceMotion: false, sleep: { _ in }) { events.append($0) }
    }
    task.cancel()
    _ = await task.result
    #expect(events.isEmpty)
  }

  @Test(arguments: [false, true])
  func cancellationDuringSleepCannotFinish(reduceMotion: Bool) async {
    var events: [SplashSequence.Event] = []
    let task = Task { @MainActor in
      try await SplashSequence.run(reduceMotion: reduceMotion, sleep: { _ in
        // Bekleyici iptali yutsa bile akış, sonraki UI güncellemesinden önce kontrol eder.
        withUnsafeCurrentTask { $0?.cancel() }
      }) { events.append($0) }
    }
    let result = await task.result
    if case .failure(let error) = result {
      #expect(error is CancellationError)
    } else {
      Issue.record("İptal edilen splash tamamlanmamalı")
    }
    #expect(events == [reduceMotion ? .showBrand : .drawMark])
  }

  @Test func interruptedWaitDoesNotDismissNextScreen() async {
    struct Interrupted: Error {}
    var events: [SplashSequence.Event] = []
    do {
      try await SplashSequence.run(reduceMotion: false, sleep: { _ in throw Interrupted() }) {
        events.append($0)
      }
      Issue.record("Bekleme hatası iletilmeli")
    } catch {
      #expect(error is Interrupted)
    }
    #expect(!events.contains(.finish))
  }
}
