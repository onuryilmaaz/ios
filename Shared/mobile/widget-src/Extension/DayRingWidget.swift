import SwiftUI
import WidgetKit

// Gün çemberi: uygulamadaki DayRingCard ile aynı geometri ve renkler
// (mobile/src/components/home/dayRing.geometry.ts). Gece yarısı altta, öğle
// üstte; sabah solda, akşam sağda.

struct DayRingEntry: TimelineEntry {
  let date: Date
  let data: WidgetData?
  let tracker: TrackerData?

  var window: PrayerWindowState? {
    computePrayerWindow(data: data, completed: tracker?.completedPrayers ?? [], at: date)
  }
}

struct DayRingProvider: TimelineProvider {
  func placeholder(in _: Context) -> DayRingEntry {
    DayRingEntry(date: Date(), data: nil, tracker: nil)
  }
  func getSnapshot(in _: Context, completion: @escaping (DayRingEntry) -> Void) {
    completion(DayRingEntry(date: Date(), data: WidgetData.load(), tracker: TrackerData.load()))
  }
  /// Güneş/ay işareti çember üzerinde yürüsün diye 15 dakikada bir kare.
  func getTimeline(in _: Context, completion: @escaping (Timeline<DayRingEntry>) -> Void) {
    let data = WidgetData.load()
    let tracker = TrackerData.load()
    let now = Date()
    let start = now.addingTimeInterval(-now.timeIntervalSince1970.truncatingRemainder(dividingBy: 900))
    let entries = (0..<48).map { i in
      DayRingEntry(date: i == 0 ? now : start.addingTimeInterval(Double(i) * 900), data: data, tracker: tracker)
    }
    completion(Timeline(entries: entries, policy: .atEnd))
  }
}

// MARK: - Geometri

private let dayMinutes = 24.0 * 60

private func minutes(_ hhmm: String) -> Double? {
  let p = hhmm.split(separator: ":").compactMap { Double($0) }
  return p.count >= 2 ? p[0] * 60 + p[1] : nil
}

private func minutes(of date: Date) -> Double {
  let c = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
  return Double(c.hour ?? 0) * 60 + Double(c.minute ?? 0) + Double(c.second ?? 0) / 60
}

private func ringPoint(_ min: Double, _ center: CGPoint, _ r: CGFloat) -> CGPoint {
  let theta = min / dayMinutes * 2 * .pi
  return CGPoint(x: center.x - r * CGFloat(sin(theta)), y: center.y + r * CGFloat(cos(theta)))
}

/// `from` → `to` saat yönünde yay (gece yarısını aşabilir), 3 dakikalık adımlarla.
private func arc(_ from: Double, _ to: Double, _ center: CGPoint, _ r: CGFloat, gap: Double = 0) -> Path {
  var span = (to - from).truncatingRemainder(dividingBy: dayMinutes)
  if span <= 0 { span += dayMinutes }
  let g = min(gap, span / 4)
  let a = from + g, b = from + span - g
  var path = Path()
  path.move(to: ringPoint(a, center, r))
  var m = a
  while m < b {
    m = min(m + 3, b)
    path.addLine(to: ringPoint(m, center, r))
  }
  return path
}

private enum Segment: String, CaseIterable {
  case imsak, gunes, ogle, ikindi, aksam, night

  func color(_ dark: Bool) -> Color {
    let hex: (light: UInt32, dark: UInt32) = {
      switch self {
      case .night: return (0xc7d0ca, 0x2d3933)
      case .imsak: return (0x7fbea2, 0x195c46)
      case .gunes: return (0xf7ebcd, 0x7c581c)
      case .ogle: return (0xefd596, 0xa07221)
      case .ikindi: return (0xe6bd62, 0xc48f2b)
      case .aksam: return (0x2e8a6a, 0x2e8a6a)
      }
    }()
    let v = dark ? hex.dark : hex.light
    return Color(
      red: Double((v >> 16) & 0xff) / 255, green: Double((v >> 8) & 0xff) / 255,
      blue: Double(v & 0xff) / 255)
  }
}

private struct RingData {
  let segments: [(Segment, Double, Double)]
  /// Kerahat vakitleri: güneşten 45 dk sonrasına, öğleden 10 dk öncesi, akşamdan 30 dk öncesi.
  let forbidden: [(Double, Double)]
  let sunrise: Double
  let sunset: Double

  init?(_ d: WidgetData) {
    guard let i = minutes(d.imsak), let g = minutes(d.gunes), let o = minutes(d.ogle),
          let k = minutes(d.ikindi), let a = minutes(d.aksam), let y = minutes(d.yatsi) else { return nil }
    segments = [(.imsak, i, g), (.gunes, g, o), (.ogle, o, k), (.ikindi, k, a), (.aksam, a, y), (.night, y, i)]
    forbidden = [(g, g + 45), (o - 10, o), (a - 30, a)]
    sunrise = g
    sunset = a
  }

  func segment(at m: Double) -> Segment? {
    for (s, from, to) in segments {
      let inside = from <= to ? (m >= from && m < to) : (m >= from || m < to)
      if inside { return s }
    }
    return nil
  }
}

// MARK: - Çember

private struct RingView: View {
  let ring: RingData
  let now: Date
  let theme: SalahTheme
  let lineWidth: CGFloat

  var body: some View {
    GeometryReader { geo in
      let size = min(geo.size.width, geo.size.height)
      let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
      let r = size / 2 - lineWidth / 2 - 4
      let nowMin = minutes(of: now)
      let current = ring.segment(at: nowMin)
      let marker = ringPoint(nowMin, center, r)
      let isDay = nowMin >= ring.sunrise && nowMin < ring.sunset

      ZStack {
        ForEach(ring.segments.indices, id: \.self) { idx in
          let (seg, from, to) = ring.segments[idx]
          arc(from, to, center, r, gap: 2)
            .stroke(
              seg.color(theme.isDark),
              style: StrokeStyle(lineWidth: seg == current ? lineWidth + 4 : lineWidth, lineCap: .butt))
        }
        ForEach(ring.forbidden.indices, id: \.self) { idx in
          let (from, to) = ring.forbidden[idx]
          arc(from, to, center, r - lineWidth / 2 - 5)
            .stroke(Color(red: 0.863, green: 0.149, blue: 0.149), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        }
        Circle()
          .fill(theme.canvas)
          .overlay(Circle().stroke(Color(red: 0.769, green: 0.561, blue: 0.169), lineWidth: 1.5))
          .frame(width: lineWidth + 8, height: lineWidth + 8)
          .overlay(
            Image(systemName: isDay ? "sun.max.fill" : "moon.fill")
              .font(.system(size: lineWidth * 0.55, weight: .semibold))
              .foregroundColor(Color(red: 0.769, green: 0.561, blue: 0.169)))
          .position(marker)
      }
    }
  }
}

private struct Countdown: View {
  let window: PrayerWindowState
  let theme: SalahTheme
  let size: CGFloat
  var centered = true

  var body: some View {
    VStack(alignment: centered ? .center : .leading, spacing: 1) {
      Text(window.headline)
        .font(.system(size: size * 0.42, weight: .medium))
        .foregroundColor(theme.textSecondary)
        .lineLimit(2)
        .multilineTextAlignment(centered ? .center : .leading)
        .minimumScaleFactor(0.8)
      Text(timerInterval: Date()...max(Date(), window.endDate), countsDown: true)
        .font(.system(size: size, weight: .semibold))
        .monospacedDigit()
        .foregroundColor(theme.textPrimary)
        .multilineTextAlignment(centered ? .center : .leading)
        .minimumScaleFactor(0.7)
        .lineLimit(1)
    }
  }
}

// MARK: - Görünümler

private struct DayRingSmallView: View {
  let entry: DayRingEntry
  let theme: SalahTheme

  var body: some View {
    if let data = entry.data, let ring = RingData(data), let w = entry.window {
      ZStack {
        RingView(ring: ring, now: entry.date, theme: theme, lineWidth: 11)
        Countdown(window: w, theme: theme, size: 20)
          .frame(maxWidth: 86)
      }
      .padding(8)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("\(w.headline) \(w.endTime)")
    } else {
      Image(systemName: "circle.dashed").font(.title).foregroundColor(theme.textTertiary)
    }
  }
}

private struct DayRingMediumView: View {
  let entry: DayRingEntry
  let theme: SalahTheme

  var body: some View {
    if let data = entry.data, let ring = RingData(data), let w = entry.window {
      HStack(spacing: 16) {
        RingView(ring: ring, now: entry.date, theme: theme, lineWidth: 12)
          .aspectRatio(1, contentMode: .fit)
        VStack(alignment: .leading, spacing: 8) {
          Countdown(window: w, theme: theme, size: 30, centered: false)
          Text(w.footnote)
            .font(.caption.weight(.medium))
            .foregroundColor(theme.textSecondary)
          Spacer(minLength: 0)
          HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
              .fill(Color(red: 0.863, green: 0.149, blue: 0.149))
              .frame(width: 14, height: 3)
            Text(WL.t("ring.forbidden"))
              .font(.caption2)
              .foregroundColor(theme.textTertiary)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
      }
      .padding(14)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("\(w.headline) \(w.endTime). \(w.footnote)")
    } else {
      Image(systemName: "circle.dashed").font(.title).foregroundColor(theme.textTertiary)
    }
  }
}

/// Büyük: çemberin etrafında vakit adları ve saatleri, ortada geri sayım.
private struct DayRingLargeView: View {
  let entry: DayRingEntry
  let theme: SalahTheme

  private static let labelKeys = ["imsak", "gunes", "ogle", "ikindi", "aksam", "yatsi"]

  var body: some View {
    if let data = entry.data, let ring = RingData(data), let w = entry.window {
      let times = [data.imsak, data.gunes, data.ogle, data.ikindi, data.aksam, data.yatsi]
      let current = ring.segment(at: minutes(of: entry.date))
      VStack(spacing: 10) {
        GeometryReader { geo in
          // Etiketler için çemberin çevresinde pay bırak.
          let side = min(geo.size.width, geo.size.height)
          let ringSize = side - 76
          let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
          ZStack {
            RingView(ring: ring, now: entry.date, theme: theme, lineWidth: 16)
              .frame(width: ringSize, height: ringSize)
              .position(center)
            Countdown(window: w, theme: theme, size: 34)
              .frame(maxWidth: ringSize * 0.62)
              .position(center)
            ForEach(Self.labelKeys.indices, id: \.self) { i in
              if let m = minutes(times[i]) {
                let active = current?.rawValue == Self.labelKeys[i]
                  || (current == .night && Self.labelKeys[i] == "yatsi")
                VStack(spacing: 0) {
                  Text(WL.prayer(Self.labelKeys[i]))
                    .font(.system(size: 11, weight: .semibold))
                  Text(times[i])
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                }
                .foregroundColor(active ? Color.gold(theme) : theme.textSecondary)
                .fixedSize()
                .position(ringPoint(m, center, ringSize / 2 + 24))
              }
            }
          }
        }

        HStack(spacing: 6) {
          Text(w.footnote)
            .font(.caption.weight(.medium))
            .foregroundColor(theme.textSecondary)
          Spacer(minLength: 0)
          RoundedRectangle(cornerRadius: 2)
            .fill(Color(red: 0.863, green: 0.149, blue: 0.149))
            .frame(width: 14, height: 3)
          Text(WL.t("ring.forbidden"))
            .font(.caption2)
            .foregroundColor(theme.textTertiary)
        }
      }
      .padding(16)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("\(w.headline) \(w.endTime). \(w.footnote)")
    } else {
      Image(systemName: "circle.dashed").font(.title).foregroundColor(theme.textTertiary)
    }
  }
}

struct DayRingWidgetEntryView: View {
  @Environment(\.widgetFamily) private var family
  let entry: DayRingEntry
  let theme: SalahTheme

  var body: some View {
    switch family {
    case .systemMedium: DayRingMediumView(entry: entry, theme: theme)
    case .systemLarge: DayRingLargeView(entry: entry, theme: theme)
    default: DayRingSmallView(entry: entry, theme: theme)
    }
  }
}

struct DayRingWidget: Widget {
  let kind = "SalahDayRingWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: DayRingProvider()) { entry in
      // Vakit widget'ı gibi koyu zümrüt kahraman yüzeyi.
      HeroThemed { theme in
        DayRingWidgetEntryView(entry: entry, theme: theme)
      }
      .widgetURL(URL(string: "salah://home"))
    }
    .configurationDisplayName(WL.t("ring.name"))
    .description(WL.t("ring.desc"))
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
  }
}
