import ActivityKit
import AlarmKit
import SwiftUI
import WidgetKit

/// AlarmKit'in ertele (geri sayım) durumu için Live Activity. Alarm çalarkenki
/// tam ekran arayüzü sistemindir; bu görünüm yalnız "Ertele"den sonra kilit
/// ekranında ve Dynamic Island'da kalan süreyi gösterir.
@available(iOS 26.0, *)
struct SalahAlarmLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: AlarmAttributes<SalahAlarmMetadata>.self) { context in
      HStack(spacing: 12) {
        Image(systemName: "alarm.fill")
          .font(.system(size: 20, weight: .semibold))
          .foregroundStyle(context.attributes.tintColor)
        Text(title(context.attributes))
          .font(.system(size: 16, weight: .semibold))
          .lineLimit(1)
        Spacer()
        remaining(context.state)
          .font(.system(size: 28, weight: .semibold))
          .monospacedDigit()
          .multilineTextAlignment(.trailing)
          .frame(maxWidth: 110, alignment: .trailing)
      }
      .padding(16)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Image(systemName: "alarm.fill")
            .foregroundStyle(context.attributes.tintColor)
        }
        DynamicIslandExpandedRegion(.center) {
          Text(title(context.attributes)).lineLimit(1)
        }
        DynamicIslandExpandedRegion(.trailing) {
          remaining(context.state).monospacedDigit()
        }
      } compactLeading: {
        Image(systemName: "alarm.fill")
          .foregroundStyle(context.attributes.tintColor)
      } compactTrailing: {
        remaining(context.state)
          .monospacedDigit()
          .frame(maxWidth: 52)
      } minimal: {
        Image(systemName: "alarm.fill")
          .foregroundStyle(context.attributes.tintColor)
      }
    }
  }

  private func title(_ attrs: AlarmAttributes<SalahAlarmMetadata>) -> LocalizedStringResource {
    attrs.presentation.countdown?.title ?? attrs.presentation.alert.title
  }

  @ViewBuilder
  private func remaining(_ state: AlarmPresentationState) -> some View {
    switch state.mode {
    case .countdown(let countdown):
      Text(timerInterval: Date.now...max(Date.now, countdown.fireDate), countsDown: true)
    case .paused(let paused):
      let left = max(0, paused.totalCountdownDuration - paused.previouslyElapsedDuration)
      Text(Duration.seconds(left).formatted(.time(pattern: .minuteSecond)))
    case .alert(let alert):
      Text(String(format: "%02d:%02d", alert.time.hour, alert.time.minute))
    @unknown default:
      EmptyView()
    }
  }
}
