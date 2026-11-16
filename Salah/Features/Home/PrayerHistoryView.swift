import SwiftUI

/// Son 14 günün namaz kayıtlarını düzeltme. RN: screens/user/PrayerHistoryEditScreen.tsx
struct PrayerHistoryView: View {
  @Environment(\.tokens) private var tokens
  @State private var selected = Calendar.current.startOfDay(for: Date())
  @State private var done: Set<String> = []

  private var days: [Date] {
    let today = Calendar.current.startOfDay(for: Date())
    return (0..<14).compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: today) }
  }

  var body: some View {
    VStack(spacing: 0) {
      StandardHeader(title: t("history.title"))
      dateStrip
      ScrollView {
        VStack(spacing: 16) {
          header
          VStack(alignment: .leading, spacing: 0) {
            Text(t("history.fivePrayers"))
              .font(.system(size: 13, weight: .medium))
              .foregroundStyle(tokens.textSecondary)
              .padding(.leading, 3.5)
              .padding(.bottom, 7)
            DayPrayerList(day: selected, done: $done)
          }
          if KazaStore.shared.available { kazaLink }
          info.padding(.bottom, 84)
        }
        .padding(16)
        .padding(.bottom, 24)
      }
      .scrollIndicators(.hidden)
    }
    .background(tokens.canvas)
    .toolbar(.hidden, for: .navigationBar)
  }

  private var dateStrip: some View {
    ScrollView(.horizontal) {
      HStack(spacing: 7) {
        let weekdays = Localizer.shared.list("common.weekdaysShort")
        ForEach(days, id: \.self) { d in
          let isSelected = d == selected
          let isToday = Calendar.current.isDateInToday(d)
          // common.weekdaysShort Pazartesi'den başlar; weekday Pazar=1.
          let idx = (Calendar.current.component(.weekday, from: d) + 5) % 7
          Button {
            Haptics.impact(.light)
            selected = d
          } label: {
            VStack(spacing: 1.75) {
              Text(weekdays.indices.contains(idx) ? weekdays[idx] : "")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isSelected ? Accent.s100 : tokens.textSecondary)
              Text("\(Calendar.current.component(.day, from: d))")
                .font(.system(size: 15.75, weight: .semibold))
                .foregroundStyle(isSelected ? .white : tokens.textPrimary)
                .tabularNumbers()
              Circle()
                .fill(isToday && !isSelected ? Accent.s500 : .clear)
                .frame(width: 3.5, height: 3.5)
            }
            .frame(width: 49)
            .padding(.vertical, 8.75)
            .background(isSelected ? (tokens.isDark ? Accent.s500 : Accent.s600) : (tokens.isDark ? Forest.s900 : Forest.s100), in: .rect(cornerRadius: 14))
          }
          .buttonStyle(PressableStyle())
          .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
      }
      .padding(.horizontal, 16)
    }
    .scrollIndicators(.hidden)
    .padding(.vertical, 7)
    .background(tokens.surface)
    .overlay(alignment: .bottom) { Rectangle().fill(tokens.line).frame(height: 1) }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(t(Calendar.current.isDateInToday(selected) ? "history.today" : "history.pastDay"))
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(tokens.isDark ? Accent.s400 : Accent.s600)
      Text(selected.formatted(.dateTime.day().month(.wide).year().locale(Localizer.shared.locale)))
        .font(.system(size: 17.5, weight: .semibold))
        .foregroundStyle(tokens.textPrimary)
        .padding(.top, 3.5)
      Text(t("history.count", ["count": done.count]))
        .font(.system(size: 10.5))
        .foregroundStyle(tokens.textSecondary)
        .tabularNumbers()
        .padding(.top, 1.75)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(17.5)
    .background(tokens.surface, in: .rect(cornerRadius: 21))
    .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
  }

  private var kazaLink: some View {
    NavigationLink(value: HomeRoute.kaza) {
      HStack(spacing: 10.5) {
        Ionicon("hourglass-outline", size: 18, color: tokens.gold)
          .frame(width: 35, height: 35)
          .background(tokens.isDark ? Gold.s700.opacity(0.25) : Gold.s100, in: .circle)
        Text(t("kaza.historyLink")).font(.system(size: 15, weight: .medium)).foregroundStyle(tokens.textPrimary)
          .frame(maxWidth: .infinity, alignment: .leading)
        Ionicon(dirIcon("chevron-forward"), size: 16, color: tokens.inkSubtle)
      }
      .padding(14)
      .background(tokens.surface, in: .rect(cornerRadius: 21))
      .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
    }
    .buttonStyle(PressableStyle())
    .simultaneousGesture(TapGesture().onEnded { Haptics.impact(.light) })
  }

  private var info: some View {
    HStack(alignment: .top, spacing: 7) {
      Ionicon("information-circle", size: 16, color: Amber.s500).padding(.top, 2)
      Text(t("history.info"))
        .font(.system(size: 12))
        .lineSpacing(8)
        .foregroundStyle(tokens.isDark ? Amber.s300 : Amber.s700)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(14)
    .background(tokens.isDark ? Amber.s500.opacity(0.1) : Amber.s50, in: .rect(cornerRadius: 14))
  }

}
