import SwiftUI

/// RN QiblaFinderScreen: yön hesabı, kadran ve 25°/10°/5° geri bildirimi.
struct QiblaFinderView: View {
  @Environment(\.tokens) private var tokens
  @Environment(\.scenePhase) private var scenePhase
  @State private var visible = false
  private var store: QiblaStore { .shared }

  var body: some View {
    VStack(spacing: 0) {
      StandardHeader(title: t("qibla.title"))
      switch store.state {
      case .locating:
        VStack(spacing: 14) {
          ProgressView().controlSize(.large).tint(tokens.accent)
          Text(t("qibla.locating")).font(.system(size: 14)).foregroundStyle(tokens.textSecondary)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
      case .failure(let failure):
        VStack(spacing: 14) {
          Ionicon("warning-outline", size: 48, color: tokens.danger)
          Text(t(failure.messageKey)).font(.system(size: 14)).foregroundStyle(tokens.textPrimary).multilineTextAlignment(.center)
          AppButton(title: t("common.retry"), variant: .secondary) {
            Haptics.impact(.light)
            store.stop()
            store.start()
          }.frame(maxWidth: 220)
        }.padding(21).frame(maxWidth: .infinity, maxHeight: .infinity)
      case .ready: compass
      }
    }
    .background(tokens.canvas).toolbar(.hidden, for: .navigationBar)
    .onAppear { visible = true; if scenePhase == .active { store.start() } }
    .onDisappear { visible = false; store.stop() }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active && visible { store.start() } else { store.stop() }
    }
  }

  private var compass: some View {
    GeometryReader { geometry in
      let size = min(geometry.size.width * 0.82, 400)
      let alignment = store.alignment
      ScrollView {
        VStack(spacing: 0) {
          VStack(spacing: 3.5) {
            Text(t("qibla.angle")).font(.system(size: 13, weight: .medium)).foregroundStyle(tokens.isDark ? Forest.s500 : Forest.s400)
            Text("\(Int(store.bearing.rounded()))°").font(.system(size: 64, weight: .semibold)).monospacedDigit()
              .foregroundStyle(tokens.isDark ? Accent.s400 : alignment.aligned ? Accent.s500 : Accent.s700)
          }.padding(.top, 21)
          Spacer(minLength: 24)
          QiblaDial(size: size, bearing: store.bearing, heading: store.heading, alignment: alignment)
          Spacer(minLength: 24)
          direction(alignment).padding(.horizontal, 21).padding(.bottom, 24)
        }.frame(maxWidth: .infinity, minHeight: geometry.size.height)
      }.scrollIndicators(.hidden)
    }
  }

  private func direction(_ alignment: QiblaMath.Alignment) -> some View {
    let aligned = alignment.aligned
    return HStack(spacing: 7) {
      Ionicon(aligned ? "checkmark-circle" : alignment.delta > 0 ? "arrow-redo-outline" : "arrow-undo-outline",
        size: aligned ? 18 : 17, color: aligned ? tokens.accent : tokens.inkMuted)
      Text(t(aligned ? "qibla.aligned" : alignment.delta > 0 ? "qibla.turnRight" : "qibla.turnLeft", ["deg": Int(abs(alignment.delta).rounded())]))
        .font(.system(size: 15, weight: .bold)).monospacedDigit().foregroundStyle(aligned ? tokens.accent : tokens.isDark ? Forest.s300 : Forest.s700)
        .multilineTextAlignment(.center)
    }.frame(maxWidth: aligned ? nil : .infinity).padding(.horizontal, 21).padding(.vertical, 14)
      .background(aligned ? tokens.isDark ? Accent.s400.opacity(0.1) : Accent.s50 : tokens.surface, in: .capsule)
      .overlay(Capsule().stroke(aligned ? .clear : tokens.line, lineWidth: 1))
      .accessibilityElement(children: .combine)
  }
}

private struct QiblaDial: View {
  @Environment(\.tokens) private var tokens
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let size: Double
  let bearing: Double
  let heading: Double
  let alignment: QiblaMath.Alignment
  private var centerRadius: Double { size * 0.19 }
  private var needleLength: Double { size / 2 - centerRadius - 64 }
  private var needleColor: Color { alignment.aligned ? Gold.s500 : tokens.accent }

  var body: some View {
    ZStack {
      Circle().fill(tokens.surface)
      Circle().stroke(alignment.aligned ? Gold.s500 : tokens.line, lineWidth: 2)
      ForEach([30, 60, 120, 150, 210, 240, 300, 330], id: \.self) { angle in
        Capsule().fill(tokens.isDark ? Color.white.opacity(0.15) : Forest.s300).frame(width: 2, height: 14)
          .offset(y: -(size / 2 - 24)).rotationEffect(.degrees(Double(angle) - heading))
      }
      ForEach(Array(["n", "e", "s", "w"].enumerated()), id: \.offset) { index, key in
        let angle = (Double(index) * 90 - heading) * .pi / 180
        Text(t("qibla.\(key)")).font(.system(size: 15.75, weight: .semibold))
          .foregroundStyle(tokens.isDark ? Forest.s500 : Forest.s400)
          .offset(x: sin(angle) * (size / 2 - 34), y: -cos(angle) * (size / 2 - 34))
      }
      ZStack {
        Capsule().fill(needleColor).frame(width: 6, height: needleLength)
          .offset(y: -(centerRadius + needleLength / 2))
        VStack(spacing: 3.5) {
          ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 5).fill(Forest.s950)
            Rectangle().fill(Gold.s300).frame(height: 3).padding(.top, 7)
          }.frame(width: 24.5, height: 24.5).clipShape(.rect(cornerRadius: 5))
          Text(t("qibla.kaaba")).font(.system(size: 12, weight: .semibold)).foregroundStyle(tokens.isDark ? Gold.s300 : Gold.s700)
        }
        .rotationEffect(.degrees(-alignment.delta))
        .offset(y: -(centerRadius + needleLength + 26))
      }.rotationEffect(.degrees(alignment.delta))

      if alignment.aligned && !reduceMotion && DebugLaunch.qibla == nil {
        QiblaPulse(radius: centerRadius)
      }
      center.scaleEffect(alignment.aligned && !reduceMotion ? 1.12 : 1)
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.6), value: alignment.aligned)
    }
    .frame(width: size, height: size)
    // Coğrafi sağ/sol ve kuzey/güney RTL'de aynalanmaz; metinler yine yerelleşir.
    .environment(\.layoutDirection, .leftToRight)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(t("qibla.title"))
    .accessibilityValue(t(alignment.aligned ? "qibla.aligned" : alignment.delta > 0 ? "qibla.turnRight" : "qibla.turnLeft", ["deg": Int(abs(alignment.delta).rounded())]))
  }

  private var center: some View {
    ZStack {
      Circle().fill(tokens.canvas)
      Circle().stroke(tokens.line, lineWidth: 1)
      Circle().trim(from: 0, to: alignment.closeness).stroke(Gold.s500, style: StrokeStyle(lineWidth: 4, lineCap: .round))
        .rotationEffect(.degrees(-90)).padding(-9).opacity(alignment.closeness > 0 ? 1 : 0)
      Ionicon(alignment.aligned ? "checkmark" : "navigate", size: 30, color: needleColor)
        .rotationEffect(.degrees(alignment.aligned ? 0 : alignment.delta - 45))
    }.frame(width: centerRadius * 2, height: centerRadius * 2)
  }
}

private struct QiblaPulse: View {
  let radius: Double
  var body: some View {
    TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
      let progress = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.5) / 1.5
      ZStack {
        ForEach(0..<2) { index in
          let phase = (progress + Double(index) * 0.5).truncatingRemainder(dividingBy: 1)
          let eased = 1 - pow(1 - phase, 2)
          Circle().stroke(Gold.s500, lineWidth: 2.5).frame(width: radius * 2, height: radius * 2)
            .scaleEffect(1 + eased * 1.4).opacity(0.6 * (1 - eased))
        }
      }
    }.allowsHitTesting(false).accessibilityHidden(true)
  }
}
