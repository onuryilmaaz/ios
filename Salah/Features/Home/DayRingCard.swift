import SwiftUI

/// Günü 24 saatlik bir çember olarak gösterir: vakit dilimleri, kerahat vakitleri
/// (kırmızı iç yaylar), şu an (güneş/ay) ve sıradaki vakte kalan süre.
/// RN: components/home/DayRingCard.tsx + dayRing.geometry.ts
struct DayRingCard: View {
  @Environment(\.tokens) private var tokens
  let times: PrayerTimes

  private let size: CGFloat = 300
  private let radius: CGFloat = 104
  private let stroke: CGFloat = 18
  private var labelRadius: CGFloat { radius + 30 }

  var body: some View {
    let completed = GamificationStore.shared.stats?.today_prayers ?? []
    Card {
      Text(t("dayRing.title"))
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(tokens.textPrimary)
      Text(t("dayRing.subtitle"))
        .font(.system(size: 13))
        .foregroundStyle(tokens.textSecondary)
        .padding(.top, 1.75)

      TimelineView(.periodic(from: .now, by: 30)) { context in
        ring(now: context.date, completed: completed)
      }
      .frame(maxWidth: .infinity)
      .padding(.top, 7)

      HStack(spacing: 5.25) {
        Capsule().fill(Color(hex: 0xdc2626)).frame(width: 14, height: 3)
        Text(t("dayRing.forbidden"))
          .font(.system(size: 12))
          .foregroundStyle(tokens.textSecondary)
      }
      .frame(maxWidth: .infinity)
      .padding(.top, 3.5)
    }
    .padding(.horizontal, 14)
    .padding(.bottom, 10.5)
  }

  private func ring(now: Date, completed: [String]) -> some View {
    let window = PrayerWindow.compute(times, completed: completed, now: now)
    let left = window.end.timeIntervalSince(now)
    let headline = t(window.mode == .current ? "home.hero.untilEnd" : "home.hero.untilStart", ["prayer": prayerLabel(window.prayerName)])
    let nowMin = DayRing.minutes(of: now)
    let isDay = nowMin >= DayRing.minutes(times.gunes) && nowMin < DayRing.minutes(times.aksam)
    let center = CGPoint(x: size / 2, y: size / 2)
    let marker = DayRing.point(at: nowMin, center: center, radius: radius)

    return ZStack {
      Canvas { ctx, _ in
        let segments = DayRing.segments(times)
        let current = DayRing.segment(at: nowMin, in: segments)
        for seg in segments {
          ctx.stroke(
            DayRing.arc(from: seg.from, to: seg.to, center: center, radius: radius, gap: 2),
            with: .color(tokens.isDark ? seg.dark : seg.light),
            style: StrokeStyle(lineWidth: current?.key == seg.key ? stroke + 6 : stroke, lineCap: .butt)
          )
        }
        for w in ForbiddenWindow.windows(times, on: now) {
          ctx.stroke(
            DayRing.arc(from: DayRing.minutes(of: w.start), to: DayRing.minutes(of: w.end), center: center, radius: radius - stroke / 2 - 7),
            with: .color(Color(hex: 0xdc2626)),
            style: StrokeStyle(lineWidth: 3, lineCap: .round)
          )
        }
        for key in ["imsak", "gunes", "ogle", "ikindi", "aksam", "yatsi"] {
          let p = DayRing.point(at: DayRing.minutes(times[key] ?? "00:00"), center: center, radius: labelRadius)
          ctx.draw(
            Text(prayerLabel(key)).font(.system(size: 11, weight: .semibold)).foregroundStyle(tokens.isDark ? Forest.s400 : Forest.s600),
            at: p
          )
        }
        let dot = Path(ellipseIn: CGRect(x: marker.x - 13, y: marker.y - 13, width: 26, height: 26))
        ctx.fill(dot, with: .color(tokens.isDark ? Forest.s900 : .white))
        ctx.stroke(dot, with: .color(Gold.s500), lineWidth: 2)
      }
      .frame(width: size, height: size)

      Ionicon(isDay ? "sunny" : "moon", size: 14, color: Gold.s500)
        .position(marker)

      VStack(spacing: 0) {
        Text(headline)
          .font(.system(size: 13))
          .foregroundStyle(tokens.textSecondary)
          .multilineTextAlignment(.center)
          .frame(maxWidth: 150)
        Text(Self.formatLeft(left))
          .font(.system(size: 34, weight: .semibold))
          .foregroundStyle(tokens.textPrimary)
          .tabularNumbers()
          .padding(.top, 3.5)
        Text(t(left >= 3600 ? "dayRing.hours" : "dayRing.minutes"))
          .font(.system(size: 12))
          .foregroundStyle(tokens.textSecondary)
      }
    }
    .frame(width: size, height: size)
    // Çizim mutlak koordinatlı; RTL'de aynalanmaz (RN'deki SVG gibi).
    .environment(\.layoutDirection, .leftToRight)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(headline) \(Self.formatLeft(left))")
  }

  private static func formatLeft(_ interval: TimeInterval) -> String {
    let total = max(0, Int(interval / 60))
    let h = total / 60
    let m = total % 60
    return h > 0 ? "\(h):\(String(format: "%02d", m))" : "\(m)"
  }
}

/// Gün çemberi geometrisi: gece yarısı altta, öğle üstte; sabah solda, akşam sağda.
enum DayRing {
  static let dayMinutes: Double = 24 * 60

  struct Segment {
    let key: String
    let from: Double
    let to: Double
    let light: Color
    let dark: Color
  }

  static func minutes(_ hhmm: String) -> Double {
    let p = hhmm.split(separator: ":").compactMap { Double($0) }
    return (p.first ?? 0) * 60 + (p.count > 1 ? p[1] : 0)
  }

  static func minutes(of date: Date) -> Double {
    let c = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
    return Double(c.hour ?? 0) * 60 + Double(c.minute ?? 0) + Double(c.second ?? 0) / 60
  }

  /// Günün dakikası → çember üzerindeki nokta (y aşağı).
  static func point(at min: Double, center: CGPoint, radius: CGFloat) -> CGPoint {
    let theta = min / dayMinutes * 2 * .pi
    return CGPoint(x: center.x - radius * sin(theta), y: center.y + radius * cos(theta))
  }

  /// `from`'dan `to`'ya saat yönünde yay (gece yarısını geçebilir); uçlardan `gap` dakika kısaltılır.
  static func arc(from: Double, to: Double, center: CGPoint, radius: CGFloat, gap: Double = 0) -> Path {
    var span = (to - from).truncatingRemainder(dividingBy: dayMinutes)
    if span < 0 { span += dayMinutes }
    if span == 0 { span = dayMinutes }
    let trim = min(gap, span / 4)
    let start = from + trim
    let end = from + span - trim
    var path = Path()
    let steps = max(2, Int((end - start) / 4))
    for i in 0...steps {
      let p = point(at: start + (end - start) * Double(i) / Double(steps), center: center, radius: radius)
      if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
    }
    return path
  }

  /// Vakit dilimleri (palet: gece forest, şafak/akşam zümrüt, gündüz altın).
  static func segments(_ t: PrayerTimes) -> [Segment] {
    [
      Segment(key: "imsak", from: minutes(t.imsak), to: minutes(t.gunes), light: Accent.s300, dark: Accent.s700),
      Segment(key: "gunes", from: minutes(t.gunes), to: minutes(t.ogle), light: Gold.s100, dark: Gold.s700),
      Segment(key: "ogle", from: minutes(t.ogle), to: minutes(t.ikindi), light: Gold.s200, dark: Gold.s600),
      Segment(key: "ikindi", from: minutes(t.ikindi), to: minutes(t.aksam), light: Gold.s300, dark: Gold.s500),
      Segment(key: "aksam", from: minutes(t.aksam), to: minutes(t.yatsi), light: Accent.s500, dark: Accent.s500),
      Segment(key: "night", from: minutes(t.yatsi), to: minutes(t.imsak), light: Forest.s300, dark: Forest.s800),
    ]
  }

  static func segment(at min: Double, in segments: [Segment]) -> Segment? {
    segments.first { s in
      s.from <= s.to ? (min >= s.from && min < s.to) : (min >= s.from || min < s.to)
    }
  }
}
