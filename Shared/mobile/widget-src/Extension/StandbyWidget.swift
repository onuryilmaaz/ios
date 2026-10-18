import SwiftUI
import WidgetKit

// MARK: - Entry & Provider

struct StandbyEntry: TimelineEntry {
  let date: Date
  let data: WidgetData?
  let tracker: TrackerData?

  var window: PrayerWindowState? {
    computePrayerWindow(data: data, completed: tracker?.completedPrayers ?? [], at: date)
  }
}

struct StandbyProvider: TimelineProvider {
  func placeholder(in _: Context) -> StandbyEntry {
    StandbyEntry(date: Date(), data: nil, tracker: nil)
  }
  func getSnapshot(in _: Context, completion: @escaping (StandbyEntry) -> Void) {
    completion(StandbyEntry(date: Date(), data: WidgetData.load(), tracker: TrackerData.load()))
  }
  func getTimeline(in _: Context, completion: @escaping (Timeline<StandbyEntry>) -> Void) {
    let now = Date()
    let entry = StandbyEntry(date: now, data: WidgetData.load(), tracker: TrackerData.load())
    let nextChange = entry.window?.endDate
      ?? Calendar.current.date(byAdding: .minute, value: 15, to: now)!
    completion(Timeline(
      entries: [entry],
      policy: .after(nextChange),
    ))
  }
}

// MARK: - Standby System Small (big clock-style)

// iOS 16 fallback: containerBackground iOS 17+ only
extension View {
  @ViewBuilder
  func standbyBackground() -> some View {
    if #available(iOS 17.0, *) {
      self.containerBackground(for: .widget) {
        SalahTheme.hero.canvas
      }
    } else {
      self.background(
        SalahTheme.hero.canvas
      )
    }
  }

  @ViewBuilder
  func standbyAccessoryBackground() -> some View {
    if #available(iOS 17.0, *) {
      self.containerBackground(for: .widget) { Color.clear }
    } else {
      ZStack {
        AccessoryWidgetBackground()
        self
      }
    }
  }
}

struct StandbySystemSmallView: View {
  let entry: StandbyEntry

  private var state: PrayerWindowState? { entry.window }

  var body: some View {
    Group {
      if let s = state {
        VStack(alignment: .leading, spacing: 0) {
          HStack(spacing: 5) {
            Image(systemName: prayerIcon(s.key))
              .font(.system(size: 11, weight: .semibold))
            Text(s.headline)
              .font(.system(size: 12, weight: .semibold))
              .lineLimit(1)
              .minimumScaleFactor(0.8)
          }
          .foregroundColor(prayerAccent(s.key, .dark))

          Spacer(minLength: 4)

          Text(s.endDate, style: .timer)
            .font(.widgetHero(48))
            .foregroundColor(.white)
            .minimumScaleFactor(0.4)
            .lineLimit(1)
            .monospacedDigit()

          Spacer(minLength: 4)

          HStack {
            Text(s.footnote)
              .font(.system(size: 13, weight: .semibold).monospacedDigit())
              .foregroundColor(.white.opacity(0.85))
            Spacer()
            Text("›  " + WL.prayer(s.nextPrayer))
              .font(.system(size: 11, weight: .semibold))
              .foregroundColor(.white.opacity(0.55))
          }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      } else {
        Text(WL.t("window.waiting"))
          .font(.system(size: 13, weight: .semibold))
          .foregroundColor(.white.opacity(0.6))
          .padding(14)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .standbyBackground()
  }
}

// MARK: - Standby Accessory (Lock screen rectangular, also visible in Standby)

struct StandbyAccessoryRectView: View {
  let entry: StandbyEntry
  private var state: PrayerWindowState? { entry.window }

  var body: some View {
    Group {
      if let s = state {
        VStack(alignment: .leading, spacing: 1) {
          HStack(spacing: 4) {
            Image(systemName: prayerIcon(s.key))
              .font(.system(size: 10, weight: .semibold))
            Text(s.headline)
              .font(.system(size: 13, weight: .semibold))
              .lineLimit(1)
              .minimumScaleFactor(0.8)
          }
          HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(s.endDate, style: .timer)
              .font(.system(size: 22, weight: .medium).monospacedDigit())
              .minimumScaleFactor(0.5)
              .lineLimit(1)
            Spacer(minLength: 0)
            Text(s.endTime)
              .font(.system(size: 13, weight: .semibold).monospacedDigit())
              .opacity(0.7)
              .fixedSize()
          }
        }
      } else {
        Text(WL.t("window.none"))
          .font(.system(size: 12, weight: .semibold))
      }
    }
    .standbyAccessoryBackground()
  }
}

// MARK: - Entry View

struct StandbyWidgetEntryView: View {
  @Environment(\.widgetFamily) var family
  let entry: StandbyEntry
  var body: some View {
    switch family {
    case .accessoryRectangular:
      StandbyAccessoryRectView(entry: entry)
    default:
      StandbySystemSmallView(entry: entry)
    }
  }
}

// MARK: - Widget Definition

struct StandbyPrayerWidget: Widget {
  let kind = "SalahStandbyPrayerWidget"
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: StandbyProvider()) { entry in
      StandbyWidgetEntryView(entry: entry)
        .premiumGated(isWidgetPremiumActive())
        .widgetURL(URL(string: isWidgetPremiumActive() ? "salah://home" : "salah://paywall"))
    }
    .configurationDisplayName("Salah · Standby")
    .description(WL.t("standby.desc"))
    .supportedFamilies([.systemSmall, .accessoryRectangular])
  }
}
