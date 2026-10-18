import SwiftUI

/// Namaz serisi ve son 7 gün. RN: components/home/StreakCard.tsx
struct StreakCard: View {
  @Environment(\.tokens) private var tokens
  @State private var sharing = false

  var body: some View {
    let store = GamificationStore.shared
    let streak = store.stats?.current_streak ?? 0
    // RN: highest_streak || streak (0 ise o anki seri).
    let longest = (store.stats?.highest_streak).flatMap { $0 > 0 ? $0 : nil } ?? streak
    let days = WeekDay.build(daily: store.weeklyStats?["daily"], dayNames: Localizer.shared.list("common.weekdaysShort"))

    VStack(spacing: 0) {
      HStack {
        HStack(spacing: 10.5) {
          Ionicon("flame", size: 24, color: tokens.gold)
            .frame(width: 42, height: 42)
            .background(tokens.isDark ? Gold.s700.opacity(0.25) : Gold.s100, in: .circle)
          VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 3.5) {
              Text("\(streak)")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(tokens.textPrimary)
                .tabularNumbers()
              Text(t("home.streak.days"))
                .font(.system(size: 15))
                .foregroundStyle(tokens.isDark ? Forest.s300 : Forest.s600)
            }
            Text(t("home.streak.label"))
              .font(.system(size: 13))
              .foregroundStyle(tokens.textSecondary)
          }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(t("home.streak.a11y", ["streak": streak, "longest": longest]))
        Spacer()
        VStack(alignment: .trailing, spacing: 0) {
          if streak > 0 {
            Button {
              Haptics.impact(.light)
              sharing = true
            } label: {
              Ionicon("share-outline", size: 15, color: tokens.gold)
                .frame(width: 28, height: 28)
                .background(tokens.isDark ? Gold.s700.opacity(0.25) : Gold.s100, in: .circle)
                .contentShape(.rect.inset(by: -8))
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel(t("shareCards.streak.shareA11y"))
            .padding(.bottom, 5.25)
          }
          Text(t("home.streak.longest"))
            .font(.system(size: 12))
            .foregroundStyle(tokens.textSecondary)
          Text("\(longest)")
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(tokens.isDark ? Gold.s300 : Gold.s700)
            .tabularNumbers()
        }
      }
      .accessibilityElement(children: .contain)

      HStack {
        ForEach(Array(days.enumerated()), id: \.offset) { i, day in
          if i > 0 { Spacer(minLength: 0) }
          dayView(day)
        }
      }
      .padding(.top, 17.5)
    }
    .padding(17.5)
    .background(tokens.isDark ? Color(hex: 0x28230f) : Gold.s50, in: .rect(cornerRadius: 21))
    .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.isDark ? Color(hex: 0x3d3418) : Gold.s100, lineWidth: 1))
    .padding(.horizontal, 14)
    .padding(.bottom, 10.5)
    .fullScreenCover(isPresented: $sharing) {
      StreakShareSheet(streak: streak, longest: longest, week: days)
        .environment(\.tokens, tokens)
    }
    .task {
      async let a: Void = store.fetchStats()
      async let b: Void = store.fetchWeeklyStats()
      _ = await (a, b)
    }
  }

  private func dayView(_ day: WeekDay) -> some View {
    VStack(spacing: 5.25) {
      ZStack {
        if day.full {
          Circle().fill(Gold.s400)
          Ionicon("checkmark", size: 17, color: .white)
        } else if day.partial {
          Circle().fill(tokens.isDark ? Gold.s700.opacity(0.3) : Gold.s100)
          Text("\(day.count)")
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(tokens.isDark ? Gold.s300 : Gold.s700)
        } else if day.isToday {
          Circle().strokeBorder(tokens.isDark ? Gold.s600 : Gold.s300, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        } else {
          Circle().fill(tokens.isDark ? Color.white.opacity(0.05) : Color.white.opacity(0.7))
        }
      }
      .frame(width: 31.5, height: 31.5)
      Text(day.label)
        .font(.system(size: 12, weight: day.isToday ? .semibold : .regular))
        .foregroundStyle(day.isToday ? tokens.textPrimary : tokens.textSecondary)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(t("home.streak.dayA11y", ["day": day.label, "count": day.count]))
  }
}
