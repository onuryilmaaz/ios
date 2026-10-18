import SwiftUI

struct MuteBanner: View {
  @Environment(\.tokens) private var tokens

  var body: some View {
    TimelineView(.periodic(from: .now, by: 60)) { context in
      if let until = NotificationStore.shared.preferences.muteUntil, until > context.date {
        HStack(spacing: 10.5) {
          Ionicon("notifications-off-outline", size: 20, color: tokens.inkMuted)
            .frame(width: 35, height: 35).background(tokens.fill, in: .circle)
          VStack(alignment: .leading, spacing: 1.75) {
            Text(t("mute.title")).font(.system(size: 15, weight: .semibold)).foregroundStyle(tokens.textPrimary)
            Text(t("mute.remaining", ["time": muteRemaining(until, now: context.date)]))
              .font(.system(size: 13)).foregroundStyle(tokens.textSecondary)
          }.frame(maxWidth: .infinity, alignment: .leading)
          Button {
            Haptics.impact(.light)
            NotificationStore.shared.unmute()
            Toast.success(t("mute.enabled"), t("mute.enabledMessage"))
          } label: {
            Text(t("mute.on")).font(.system(size: 13, weight: .semibold)).foregroundStyle(tokens.accent)
              .padding(.horizontal, 14).padding(.vertical, 7).background(tokens.fill, in: .capsule)
          }
          .buttonStyle(PressableStyle()).accessibilityLabel(t("mute.turnOff"))
        }
        .padding(17.5)
        .background(tokens.surface, in: .rect(cornerRadius: 21))
        .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
        .padding(.horizontal, 14).padding(.bottom, 10.5)
      }
    }
  }
}

struct AdhanOverlay: View {
  @Environment(\.tokens) private var tokens

  var body: some View {
    if let prayer = AdhanPlayer.shared.activePrayer {
      ZStack {
        Rectangle().fill(.ultraThinMaterial).environment(\.colorScheme, .dark).ignoresSafeArea()
          .onTapGesture { stop() }
        VStack(spacing: 0) {
          Ionicon("moon", size: 32, color: Accent.s500)
            .frame(width: 56, height: 56).background(Accent.s500.opacity(0.2), in: .circle)
            .frame(width: 84, height: 84).background(Accent.s500.opacity(0.1), in: .circle)
            .overlay(Circle().stroke(Accent.s700, lineWidth: 2)).padding(.bottom, 21)
          Text(t("adhan.time")).font(.system(size: 13, weight: .medium)).foregroundStyle(Accent.s400).padding(.bottom, 3.5)
          Text(t("adhan.title", ["prayer": prayerLabel(prayer)])).font(.system(size: 21, weight: .semibold)).foregroundStyle(.white).padding(.bottom, 7)
          Text(t("adhan.takbir")).font(.system(size: 12.25)).foregroundStyle(.white.opacity(0.5)).padding(.bottom, 28)
          Button { stop() } label: {
            HStack(spacing: 7) {
              Ionicon("stop-circle-outline", size: 20, color: .white.opacity(0.9))
              Text(t("adhan.dismiss")).font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(.white.opacity(0.9)).frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(.white.opacity(0.1), in: .rect(cornerRadius: 14))
          }.buttonStyle(PressableStyle())
        }
        .padding(.horizontal, 28).padding(.vertical, 35).frame(maxWidth: 320)
        .background(Forest.s900.opacity(0.95), in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.1), lineWidth: 1))
        .padding(.horizontal, 21).accessibilityAddTraits(.isModal)
      }
    }
  }
  private func stop() { Haptics.impact(.medium); AdhanPlayer.shared.stop() }
}
