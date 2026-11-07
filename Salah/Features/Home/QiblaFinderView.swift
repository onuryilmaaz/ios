import SwiftUI

/// RN QiblaFinderScreen: yön hesabı, kadran ve 25°/10°/5° geri bildirimi. Görünüm seçilebilir temadan gelir.
struct QiblaFinderView: View {
  @Environment(\.tokens) private var tokens
  @Environment(\.dismiss) private var dismiss
  @Environment(\.scenePhase) private var scenePhase
  @State private var visible = false
  @State private var theme = QiblaTheme.saved
  private var store: QiblaStore { .shared }

  var body: some View {
    VStack(spacing: 0) {
      header
      switch store.state {
      case .locating:
        VStack(spacing: 14) {
          ProgressView().controlSize(.large).tint(theme.accent)
          Text(t("qibla.locating")).font(.system(size: 14)).foregroundStyle(theme.muted)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
      case .failure(let failure):
        VStack(spacing: 14) {
          Ionicon("warning-outline", size: 48, color: theme.accent)
          Text(t(failure.messageKey)).font(.system(size: 14)).foregroundStyle(theme.ink).multilineTextAlignment(.center)
          AppButton(title: t("common.retry"), variant: .secondary) {
            Haptics.impact(.light)
            store.stop()
            store.start()
          }.frame(maxWidth: 220)
        }.padding(21).frame(maxWidth: .infinity, maxHeight: .infinity)
      case .ready: compass
      }
    }
    .background(theme.background).toolbar(.hidden, for: .navigationBar)
    .statusBar(theme.isLight ? .dark : .light)
    .onAppear { visible = true; if scenePhase == .active { store.start() } }
    .onDisappear { visible = false; store.stop() }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active && visible { store.start() } else { store.stop() }
    }
  }

  private var header: some View {
    HStack {
      Button {
        Haptics.impact(.light)
        dismiss()
      } label: {
        Ionicon(dirIcon("chevron-back"), size: 20, color: theme.ink)
          .frame(width: 44, height: 44)
          .background(theme.isLight ? theme.surface : Color.white.opacity(0.1), in: .circle)
      }
      .buttonStyle(PressableStyle())
      .accessibilityLabel(t("common.back"))
      Spacer()
      Text(t("qibla.title")).font(.system(size: 17, weight: .semibold)).foregroundStyle(theme.ink)
      Spacer()
      Color.clear.frame(width: 44, height: 44)
    }
    .padding(.horizontal, 14)
    .padding(.top, 4)
  }

  private var compass: some View {
    GeometryReader { geometry in
      let size = min(geometry.size.width * 0.86, 400)
      let alignment = store.alignment
      ScrollView {
        VStack(spacing: 0) {
          VStack(spacing: 2) {
            Text(t("qibla.angle")).font(.system(size: 13, weight: .medium)).foregroundStyle(theme.muted)
            Text("\(Int(store.bearing.rounded()))°").font(.system(size: 60, weight: .light)).monospacedDigit().foregroundStyle(theme.accent)
          }.padding(.top, 8)
          Spacer(minLength: 14)
          QiblaDial(size: size, theme: theme, heading: store.heading, alignment: alignment)
          Spacer(minLength: 14)
          direction(alignment).padding(.horizontal, 21)
          picker.padding(.top, 14).padding(.bottom, 16)
        }.frame(maxWidth: .infinity, minHeight: geometry.size.height)
      }.scrollIndicators(.hidden)
    }
  }

  private func direction(_ alignment: QiblaMath.Alignment) -> some View {
    let aligned = alignment.aligned
    let ink = aligned ? theme.onAccent : theme.ink
    return HStack(spacing: 7) {
      Ionicon(aligned ? "checkmark-circle" : alignment.delta > 0 ? "arrow-redo-outline" : "arrow-undo-outline",
        size: aligned ? 18 : 17, color: ink)
      Text(t(aligned ? "qibla.aligned" : alignment.delta > 0 ? "qibla.turnRight" : "qibla.turnLeft", ["deg": Int(abs(alignment.delta).rounded())]))
        .font(.system(size: 15, weight: .bold)).monospacedDigit().foregroundStyle(ink)
        .multilineTextAlignment(.center)
    }.padding(.horizontal, 22).frame(minHeight: 52)
      .background(aligned ? theme.accent : theme.surface, in: .capsule)
      .overlay(Capsule().stroke(!aligned && theme.isLight ? theme.idleRim : .clear, lineWidth: 1))
      .accessibilityElement(children: .combine)
  }

  private var picker: some View {
    VStack(spacing: 4) {
      HStack(spacing: 6) {
        ForEach(QiblaTheme.all) { option in swatch(option) }
      }
      Text(t("qibla.themeLabel", ["name": t(theme.nameKey)])).font(.system(size: 13, weight: .medium)).foregroundStyle(theme.muted)
    }
  }

  private func swatch(_ option: QiblaTheme) -> some View {
    let selected = option == theme
    return Button {
      guard !selected else { return }
      Haptics.impact(.light)
      theme = option
      LocalStore.set(option.id, for: QiblaTheme.storageKey)
    } label: {
      ZStack {
        Circle().fill(option.background)
        Circle().fill(option.accent).frame(width: 12, height: 12)
        Circle().stroke(theme.idleRim, lineWidth: 1)
        if selected { Circle().stroke(theme.accent, lineWidth: 2).padding(-4) }
      }
      .frame(width: 30, height: 30)
      .frame(width: 44, height: 44)
      .contentShape(.circle)
    }
    .buttonStyle(PressableStyle())
    .accessibilityLabel(t(option.nameKey))
    .accessibilityAddTraits(selected ? .isSelected : [])
  }
}

private func dialPoint(_ radius: Double, _ degrees: Double) -> CGPoint {
  let radians = degrees * .pi / 180
  return CGPoint(x: sin(radians) * radius, y: -cos(radians) * radius)
}

/// Kadranla dönen süs: 320 birimlik, merkezi (0, 0) olan çizim.
private struct QiblaMotif: View {
  let theme: QiblaTheme

  var body: some View {
    Canvas { context, size in
      context.translateBy(x: size.width / 2, y: size.height / 2)
      context.scaleBy(x: size.width / 320, y: size.height / 320)
      switch theme.motif {
      case .star:
        var star = Path()
        for turn in 0..<2 {
          star.addLines((0..<4).map { dialPoint(92, Double($0) * 90 + Double(turn) * 45) })
          star.closeSubpath()
        }
        context.stroke(star, with: .color(theme.accent.opacity(0.55)), lineWidth: 1.5)
        context.stroke(spokes(count: 24, from: 146, to: 152), with: .color(theme.tick), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
      case .sky:
        var stars = Path()
        for index in 0..<24 where index * 15 % 90 != 0 {
          let big = index * 15 % 45 == 0
          addStar(&stars, center: dialPoint(big ? 136 : 142, Double(index) * 15), radius: big ? 6 : 3)
        }
        context.fill(stars, with: .color(.white.opacity(0.7)))
        context.fill(moon(day: 4, center: dialPoint(108, 0), radius: 9), with: .color(theme.accent))
      case .moons:
        context.fill(Path(ellipseIn: CGRect(x: -104, y: -104, width: 208, height: 208)), with: .color(theme.background))
        for (index, day) in [3, 7, 10, 13, 16, 20, 23, 26].enumerated() {
          let center = dialPoint(130, 22.5 + Double(index) * 45)
          context.fill(Path(ellipseIn: CGRect(x: center.x - 9, y: center.y - 9, width: 18, height: 18)), with: .color(theme.background))
          context.fill(moon(day: day, center: center, radius: 9), with: .color(theme.accent))
        }
      case .mihrab:
        context.stroke(spokes(count: 24, from: 146, to: 152), with: .color(theme.tick), style: StrokeStyle(lineWidth: 2, lineCap: .round))
      case .inlay:
        context.stroke(Path(ellipseIn: CGRect(x: -116, y: -116, width: 232, height: 232)), with: .color(theme.idleRim), lineWidth: 1)
        var fine = Path()
        for index in 0..<72 where index * 5 % 90 != 0 {
          let degrees = Double(index) * 5
          fine.move(to: dialPoint(index * 5 % 30 == 0 ? 142 : 147, degrees))
          fine.addLine(to: dialPoint(152, degrees))
        }
        context.stroke(fine, with: .color(theme.tick), style: StrokeStyle(lineWidth: 1, lineCap: .round))
        var pearls = Path()
        for index in 0..<16 {
          let degrees = Double(index) * 22.5
          pearls.addLines([dialPoint(121, degrees), dialPoint(116, degrees + 1.6), dialPoint(111, degrees), dialPoint(116, degrees - 1.6)])
          pearls.closeSubpath()
        }
        context.fill(pearls, with: .color(theme.accent))
      }
    }
    .accessibilityHidden(true)
  }

  private func spokes(count: Int, from: Double, to: Double) -> Path {
    var path = Path()
    let step = 360 / count
    for index in 0..<count where index * step % 90 != 0 {
      path.move(to: dialPoint(from, Double(index * step)))
      path.addLine(to: dialPoint(to, Double(index * step)))
    }
    return path
  }

  private func addStar(_ path: inout Path, center: CGPoint, radius: Double) {
    let inner = radius * 0.3
    path.addLines([
      CGPoint(x: center.x, y: center.y - radius), CGPoint(x: center.x + inner, y: center.y - inner),
      CGPoint(x: center.x + radius, y: center.y), CGPoint(x: center.x + inner, y: center.y + inner),
      CGPoint(x: center.x, y: center.y + radius), CGPoint(x: center.x - inner, y: center.y + inner),
      CGPoint(x: center.x - radius, y: center.y), CGPoint(x: center.x - inner, y: center.y - inner),
    ])
    path.closeSubpath()
  }

  private func moon(day: Int, center: CGPoint, radius: Double) -> Path {
    var path = Path()
    path.addLines(RamadanMoon.outline(day: day).map { CGPoint(x: center.x + $0.x * radius, y: center.y + $0.y * radius) })
    path.closeSubpath()
    return path
  }
}

/// Mihrap kemeri: telefonun baktığı yönü gösterir, kadranla dönmez.
private struct QiblaArch: View {
  let theme: QiblaTheme
  let aligned: Bool

  var body: some View {
    Canvas { context, size in
      context.scaleBy(x: size.width / 320, y: size.height / 320)
      var outer = Path()
      outer.move(to: CGPoint(x: 112, y: 112))
      outer.addLine(to: CGPoint(x: 112, y: 64))
      outer.addQuadCurve(to: CGPoint(x: 160, y: 12), control: CGPoint(x: 112, y: 28))
      outer.addQuadCurve(to: CGPoint(x: 208, y: 64), control: CGPoint(x: 208, y: 28))
      outer.addLine(to: CGPoint(x: 208, y: 112))
      outer.closeSubpath()
      context.fill(outer, with: .color(aligned ? Color(hex: 0x6E2A3A) : theme.background))
      context.stroke(outer, with: .color(theme.accent), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
      var inner = Path()
      inner.move(to: CGPoint(x: 122, y: 104))
      inner.addLine(to: CGPoint(x: 122, y: 68))
      inner.addQuadCurve(to: CGPoint(x: 160, y: 26), control: CGPoint(x: 122, y: 40))
      inner.addQuadCurve(to: CGPoint(x: 198, y: 68), control: CGPoint(x: 198, y: 40))
      inner.addLine(to: CGPoint(x: 198, y: 104))
      context.stroke(inner, with: .color(theme.accent.opacity(0.55)), lineWidth: 1)
    }
    .accessibilityHidden(true)
  }
}

private struct QiblaDial: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let size: Double
  let theme: QiblaTheme
  let heading: Double
  let alignment: QiblaMath.Alignment
  private var scale: Double { size / 320 }

  var body: some View {
    ZStack {
      Circle().fill(theme.surface)
      Circle().stroke(alignment.aligned ? theme.accent : theme.idleRim, lineWidth: 2)
      QiblaMotif(theme: theme).rotationEffect(.degrees(-heading))
      if theme.motif == .mihrab { QiblaArch(theme: theme, aligned: alignment.aligned) }
      ForEach(Array(["n", "e", "s", "w"].enumerated()), id: \.offset) { index, key in
        let point = dialPoint(theme.cardinalRadius * scale, Double(index) * 90 - heading)
        Text(t("qibla.\(key)")).font(.system(size: index == 0 ? 16 : 15, weight: index == 0 ? .bold : .semibold))
          .foregroundStyle(index == 0 ? theme.accent : theme.ink)
          .offset(x: point.x, y: point.y)
      }
      ZStack {
        Capsule().fill(theme.accent)
          .frame(width: 5, height: (theme.needle.to - theme.needle.from) * scale)
          .offset(y: -(theme.needle.from + theme.needle.to) / 2 * scale)
        kaaba
          .rotationEffect(.degrees(-alignment.delta))
          .offset(y: -theme.needle.kaaba * scale)
      }
      .rotationEffect(.degrees(alignment.delta))
      .offset(y: theme.centerOffset * scale)

      if alignment.aligned && !reduceMotion && DebugLaunch.qibla == nil {
        QiblaPulse(radius: theme.centerRadius * scale, color: theme.accent).offset(y: theme.centerOffset * scale)
      }
      center
        .scaleEffect(alignment.aligned && !reduceMotion ? 1.08 : 1)
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.6), value: alignment.aligned)
        .offset(y: theme.centerOffset * scale)
    }
    .frame(width: size, height: size)
    // Coğrafi sağ/sol ve kuzey/güney RTL'de aynalanmaz; metinler yine yerelleşir.
    .environment(\.layoutDirection, .leftToRight)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(t("qibla.title"))
    .accessibilityValue(t(alignment.aligned ? "qibla.aligned" : alignment.delta > 0 ? "qibla.turnRight" : "qibla.turnLeft", ["deg": Int(abs(alignment.delta).rounded())]))
  }

  private var kaaba: some View {
    ZStack(alignment: .top) {
      RoundedRectangle(cornerRadius: 5).fill(Forest.s950)
      Rectangle().fill(Gold.s300).frame(height: 3).padding(.top, 6)
    }
    .frame(width: 24, height: 24)
    .clipShape(.rect(cornerRadius: 5))
    .overlay(RoundedRectangle(cornerRadius: 5).stroke(theme.isLight ? .clear : theme.accent, lineWidth: 1))
  }

  private var center: some View {
    let radius = theme.centerRadius * scale
    let aligned = alignment.aligned
    return ZStack {
      Circle().fill(theme.background)
      if theme.isLight { Circle().stroke(theme.idleRim, lineWidth: 1) }
      Circle().trim(from: 0, to: alignment.closeness).stroke(theme.accent, style: StrokeStyle(lineWidth: theme.isLight ? 3 : 4, lineCap: .round))
        .rotationEffect(.degrees(-90)).padding(theme.isLight ? -6 : 0).opacity(alignment.closeness > 0 ? 1 : 0)
      Ionicon(aligned ? "checkmark" : "navigate", size: 30, color: theme.accent)
        .rotationEffect(.degrees(aligned ? 0 : alignment.delta - 45))
    }.frame(width: radius * 2, height: radius * 2)
  }
}

private struct QiblaPulse: View {
  let radius: Double
  let color: Color
  var body: some View {
    TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
      let progress = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.5) / 1.5
      ZStack {
        ForEach(0..<2) { index in
          let phase = (progress + Double(index) * 0.5).truncatingRemainder(dividingBy: 1)
          let eased = 1 - pow(1 - phase, 2)
          Circle().stroke(color, lineWidth: 2.5).frame(width: radius * 2, height: radius * 2)
            .scaleEffect(1 + eased * 1.4).opacity(0.6 * (1 - eased))
        }
      }
    }.allowsHitTesting(false).accessibilityHidden(true)
  }
}
