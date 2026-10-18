import Foundation

/// Ağdan bağımsız, iptal edilebilir açılış akışı. Bekleyen görev iptal olursa ekranı kapatmaz.
@MainActor
enum SplashSequence {
  enum Event: Equatable {
    case drawMark, revealMoon, revealLetter(Int), pulse, showBrand, fade, finish
  }

  static func run(
    reduceMotion: Bool,
    sleep: @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
    update: @MainActor (Event) -> Void
  ) async throws {
    let steps: [(Duration, Event)] = reduceMotion ? [
      (.zero, .showBrand), (.milliseconds(450), .fade), (.milliseconds(250), .finish)
    ] : [
      (.zero, .drawMark), (.milliseconds(120), .revealMoon),
      (.milliseconds(230), .revealLetter(1)), (.milliseconds(45), .revealLetter(2)),
      (.milliseconds(45), .revealLetter(3)), (.milliseconds(45), .revealLetter(4)),
      (.milliseconds(45), .revealLetter(5)), (.milliseconds(215), .pulse),
      (.milliseconds(320), .fade), (.milliseconds(300), .finish)
    ]
    for (delay, event) in steps {
      try Task.checkCancellation()
      if delay > .zero { try await sleep(delay) }
      try Task.checkCancellation()
      update(event)
    }
  }
}
