import Lottie
import SwiftUI

/// Sahne animasyonu (onboarding, boş durumlar, izin kartları): kendi çizimimiz Lottie animasyonu (`scripts/gen-onboarding-lottie.py`). Sayfa açılınca giriş
/// (0-30. kare, öğeler sırayla belirir) bir kez oynar, sonra 30-150 döngüde; sayfadan çıkılıp dönülünce giriş yeniden oynar.
/// Dolgu ve çizgiler rol adlarıyla (accent, deep, mid, soft, gold, paper) temadan boyanır; uygulama rengi
/// ve koyu tema değişince animasyon da değişir. "Hareketi azalt" açıksa durağan kare gösterilir.
struct SceneAnimation: View {
  @Environment(\.tokens) private var tokens
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let scene: String
  /// Sayfa görünürken oynar; kaydırılan sayfalar durur.
  var active = true
  @State private var introDone = false

  /// Giriş bitişi ve son kare (betikteki INTRO ve OP).
  static let introEnd: AnimationFrameTime = 30
  static let end: AnimationFrameTime = 150

  private var mode: LottiePlaybackMode {
    if reduceMotion || !active { return .paused(at: .progress(Self.restFrame[scene] ?? 0.5)) }
    return introDone
      ? .playing(.fromFrame(Self.introEnd, toFrame: Self.end, loopMode: .loop))
      : .playing(.fromFrame(0, toFrame: Self.end, loopMode: .playOnce))
  }

  var body: some View {
    LottieView(animation: .named("onboarding_\(scene)", subdirectory: "lottie"))
      .configuration(LottieConfiguration(renderingEngine: .mainThread))
      .playbackMode(mode)
      .animationDidFinish { completed in if completed { introDone = true } }
      .valueProvider(color(tokens.accent), for: keypath("accent"))
      .valueProvider(color(tokens.isDark ? Accent.s200 : Accent.s800), for: keypath("deep"))
      .valueProvider(color(tokens.isDark ? Accent.s700 : Accent.s200), for: keypath("mid"))
      .valueProvider(color(tokens.accentSoft), for: keypath("soft"))
      .valueProvider(color(tokens.isDark ? Gold.s300 : Gold.s500), for: keypath("gold"))
      .valueProvider(color(tokens.surface), for: keypath("paper"))
      .id("\(scene)-\(tokens.isDark)-\(String(describing: AppColorStore.shared.current))-\(AppColorStore.shared.customHex)")
      .accessibilityHidden(true)
      .onChange(of: active) { _, now in if !now { introDone = false } }
  }

  /// Durağan gösterimde sahnenin en dolu anı.
  private static let restFrame: [String: Double] = [
    "welcome": 0.5, "times": 0.55, "quran": 0.4, "tracker": 0.6, "tools": 0.75, "prayerLock": 0.55, "location": 0.4, "notifications": 0.45,
  ]

  private func keypath(_ role: String) -> AnimationKeypath { AnimationKeypath(keypath: "**.\(role).Color") }

  private func color(_ c: Color) -> ColorValueProvider {
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    UIColor(c).getRed(&r, green: &g, blue: &b, alpha: &a)
    return ColorValueProvider(LottieColor(r: Double(r), g: Double(g), b: Double(b), a: Double(a)))
  }
}
