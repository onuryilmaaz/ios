import SwiftUI

/// RN: navigation/HomeNavigator.tsx `HomeHeader` (56 pt, koyu zümrüt zemin).
struct HomeHeader: View {
  @Environment(\.tokens) private var tokens
  var onQibla: () -> Void = {}
  var onProfile: () -> Void = {}

  var body: some View {
    HStack {
      Button(action: onQibla) {
        Ionicon("compass-outline", size: 21, color: .white.opacity(0.9))
          .frame(width: 35, height: 35)
          .background(.white.opacity(0.1), in: .circle)
      }
      .buttonStyle(PressableStyle())
      .accessibilityLabel(t("common.qibla"))
      .tourAnchor("home.qibla")

      Spacer()

      // Logo değişmez: Bungee, amber-500, hafif altın parıltı.
      Text(verbatim: "SALAH")
        // text-3xl tracking-widest: NativeWind rem 14 → 26,25 pt, 0,1 em.
        .font(.custom("Bungee-Regular", fixedSize: 26.25))
        .tracking(2.625)
        .foregroundStyle(Amber.s500)
        .shadow(color: Color(red: 246 / 255, green: 195 / 255, blue: 88 / 255, opacity: 0.4), radius: 4)
        .environment(\.layoutDirection, .leftToRight)

      Spacer()

      Button(action: onProfile) {
        ProfileAvatar()
          .frame(width: 35, height: 35)
          .background(.white.opacity(0.1), in: .circle)
          .clipShape(.circle)
          .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
      }
      .buttonStyle(PressableStyle())
      .accessibilityLabel(t("common.profile"))
      .tourAnchor("home.profile")
    }
    .padding(.horizontal, 16)
    .frame(height: 56)
    .background(tokens.hero)
  }
}

private struct ProfileAvatar: View {
  var body: some View { UserAvatar(iconColor: .white.opacity(0.9)) }
}
