import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - State Helpers

private typealias LAState = SitePongActivityAttributes.ContentState

/// Vakit ilerleme yüzdesi (0 = yeni girdi, 1 = çıktı). Vaktin gerçek giriş/çıkış
/// anına göre hesaplanır; giriş bilinmiyorsa (sıradaki vakte sayılırken) nil.
private func prayerProgress(_ state: LAState) -> Double? {
  guard state.startTimeMs > 0, state.endTimeMs > state.startTimeMs else { return nil }
  let now = Date().timeIntervalSince1970 * 1000
  return min(1.0, max(0, (now - state.startTimeMs) / (state.endTimeMs - state.startTimeMs)))
}

/// Sayaç bittiğinde hangi vaktin GİRDİĞİ: sıradaki vakte sayıyorsak o vakit,
/// o anki vaktin çıkışına sayıyorsak ondan sonraki vakit. Sabah'tan sonra gelen
/// Güneş bir namaz vakti değildir → nil (görünüm "Vakit çıktı" der).
private func enteredPrayer(_ state: LAState) -> String? {
  if state.mode == "upcoming" { return state.prayerName }
  guard !state.nextPrayer.isEmpty, prayerKeyFromName(state.nextPrayer) != "gunes" else { return nil }
  return state.nextPrayer
}

/// State stale mı yoksa bitmiş mi? Bu durumda timer rendering güvenli değil.
private func isExpired(endTimeMs: Double) -> Bool {
  endTimeMs <= 0 || Date(timeIntervalSince1970: endTimeMs / 1000) <= Date()
}

private func hhmm(_ ms: Double) -> String {
  let c = Calendar.current.dateComponents([.hour, .minute], from: Date(timeIntervalSince1970: ms / 1000))
  return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
}

/// Görünümün ihtiyaç duyduğu her şey tek yerde (kilit ekranı ve ada aynı modeli kullanır).
private struct LAModel {
  let state: LAState
  let expired: Bool

  init(_ state: LAState, isStale: Bool) {
    self.state = state
    expired = isStale || isExpired(endTimeMs: state.endTimeMs)
  }

  /// Sayaç bittiyse yeni vakit girmiştir — görünüm onu anlatır
  /// ("Öğle vakti çıktı" değil "İkindi vakti girdi").
  var enteredName: String? { expired ? enteredPrayer(state) : nil }
  var entered: Bool { enteredName != nil }
  var isUpcoming: Bool { state.mode == "upcoming" && !expired }
  var name: String { enteredName ?? state.prayerName }
  var key: String { prayerKeyFromName(name) }
  var tint: Color { prayerAccent(key, .dark) }
  var icon: String { expired && !entered ? "checkmark" : prayerIcon(key) }
  var endDate: Date { Date(timeIntervalSince1970: state.endTimeMs / 1000) }
  var endTime: String { hhmm(state.endTimeMs) }
  var progress: Double? { entered ? 1 : prayerProgress(state) }

  /// Sayacın üstündeki tek cümle (uygulama ve widget'larla aynı):
  /// "İkindi vaktinin çıkmasına" / "Öğle vaktine".
  var displayName: String { WL.prayer(name) }
  var headline: String {
    isUpcoming ? WL.t("window.until", displayName) : WL.t("window.untilEnd", displayName)
  }
  var expiredTitle: String { entered ? WL.t("window.entered") : WL.t("window.over") }

  /// Sağ üst bilgi: o anki vakitte "İkindi 16:17" (çıkış = sıradakinin girişi),
  /// sıradaki vakte sayarken "Giriş 16:17".
  var trailingLabel: String { isUpcoming ? WL.t("window.startsLabel") : WL.prayer(state.nextPrayer) }
}

// MARK: - Pieces

/// Uygulamadaki ana sayfa üst alanıyla aynı koyu zümrüt.
private let bannerBackground = SalahTheme.hero.canvas

private struct Ring: View {
  let progress: Double
  let tint: Color
  var lineWidth: CGFloat = 2.5

  var body: some View {
    ZStack {
      Circle().stroke(Color.white.opacity(0.15), lineWidth: lineWidth)
      Circle()
        .trim(from: 0, to: max(0.02, CGFloat(progress)))
        .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        .rotationEffect(.degrees(-90))
    }
  }
}

private struct Countdown: View {
  let model: LAModel
  let size: CGFloat

  var body: some View {
    if model.expired {
      Text(model.expiredTitle)
        .font(.system(size: size * 0.72, weight: .semibold, design: .default))
        .foregroundColor(.white)
    } else {
      Text(timerInterval: Date()...max(Date(), model.endDate), pauseTime: nil, countsDown: true)
        .font(.widgetHero(size))
        .foregroundColor(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
  }
}

// MARK: - Lock Screen Banner

struct SalahLockScreenView: View {
  let state: SitePongActivityAttributes.ContentState
  let isStale: Bool

  var body: some View {
    let m = LAModel(state, isStale: isStale)
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .center, spacing: 12) {
        PrayerBadge(key: m.key, theme: .dark, size: 40)

        VStack(alignment: .leading, spacing: 2) {
          Text(m.expired ? m.displayName : m.headline)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.white.opacity(0.72))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
          Countdown(model: m, size: 32)
        }

        Spacer(minLength: 8)

        if !m.expired {
          VStack(alignment: .trailing, spacing: 2) {
            Text(m.trailingLabel)
              .font(.system(size: 12, weight: .medium))
              .foregroundColor(.white.opacity(0.6))
              .lineLimit(1)
            Text(m.endTime)
              .font(.system(size: 17, weight: .semibold, design: .default))
              .monospacedDigit()
              .foregroundColor(.white)
          }
        }
      }

      if !m.expired, let p = m.progress {
        ProgressCapsule(progress: p, tint: m.tint, track: Color.white.opacity(0.14), height: 3)
      }
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 16)
    .frame(maxWidth: .infinity)
  }
}

// MARK: - Live Activity Widget

struct SitePongLiveActivityWidgetLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: SitePongActivityAttributes.self) { context in
      SalahLockScreenView(state: context.state, isStale: context.isStale)
        .activityBackgroundTint(bannerBackground)
        .activitySystemActionForegroundColor(.white)

    } dynamicIsland: { context in
      let m = LAModel(context.state, isStale: context.isStale)

      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          HStack(spacing: 8) {
            PrayerBadge(key: m.key, theme: .dark, size: 30)
            Text(m.displayName)
              .font(.system(size: 16, weight: .semibold))
              .foregroundColor(.white)
              .lineLimit(1)
          }
          .padding(.leading, 4)
        }

        DynamicIslandExpandedRegion(.trailing) {
          if !m.expired {
            VStack(alignment: .trailing, spacing: 0) {
              Text(m.trailingLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.55))
              Text(m.endTime)
                .font(.system(size: 15, weight: .semibold, design: .default))
                .monospacedDigit()
                .foregroundColor(.white)
            }
            .padding(.trailing, 4)
          }
        }

        DynamicIslandExpandedRegion(.bottom) {
          VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 0) {
              if !m.expired {
                Text(m.headline)
                  .font(.system(size: 12, weight: .medium))
                  .foregroundColor(.white.opacity(0.6))
                  .lineLimit(1)
              }
              Countdown(model: m, size: 34)
            }
            if !m.expired, let p = m.progress {
              ProgressCapsule(progress: p, tint: m.tint, track: Color.white.opacity(0.14), height: 3)
            }
          }
          .padding(.horizontal, 6)
          .padding(.bottom, 4)
        }

      } compactLeading: {
        Image(systemName: m.icon)
          .font(.system(size: 13, weight: .semibold))
          .foregroundColor(m.tint)

      } compactTrailing: {
        // Ada dar kalsın diye sayaç yerine ince ilerleme halkası; kalan süre
        // genişletilmiş görünümde ve kilit ekranında.
        Ring(progress: m.progress ?? 0, tint: m.tint, lineWidth: 2.2)
          .frame(width: 17, height: 17)
          .padding(.trailing, 2)

      } minimal: {
        ZStack {
          Ring(progress: m.progress ?? 0, tint: m.tint, lineWidth: 2)
          Image(systemName: m.icon)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(m.tint)
        }
      }
      .keylineTint(m.tint)
    }
  }
}
