import SwiftUI

/// Hatim planı: bitiş tarihi seçilir, günlük sayfa hedefi hesaplanır; isteğe bağlı günlük hatırlatma.
struct HatimPlanView: View {
  @Environment(\.tokens) private var tokens
  @Environment(\.dismiss) private var dismiss
  private enum Preset: Hashable { case ramadan, days(Int), custom }

  @State private var preset: Preset = .days(30)
  @State private var custom = Calendar.current.date(byAdding: .day, value: 45, to: Date()) ?? Date()
  @State private var reminderOn = false
  @State private var reminderTime = Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: Date()) ?? Date()

  private var store: HatimPlanStore { .shared }
  private var ramadanEnd: Date? {
    let window = RamadanSchedule.window(ReligiousCalendarService.cached())
    return window.last >= Calendar.current.startOfDay(for: Date()) ? window.last : nil
  }
  private var target: Date {
    let today = Calendar.current.startOfDay(for: Date())
    switch preset {
    case .ramadan: return ramadanEnd ?? today
    case .days(let n): return Calendar.current.date(byAdding: .day, value: n - 1, to: today) ?? today
    case .custom: return custom
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      StandardHeader(title: t("hatim.plan.title"))
      if AuthStore.shared.isAuthenticated {
        ScrollView {
          VStack(alignment: .leading, spacing: 14) {
            if store.plan != nil { current }
            setup
          }
          .padding(14)
          .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
      } else {
        signIn
      }
    }
    .background(tokens.canvas)
    .toolbar(.hidden, for: .navigationBar)
    .task {
      if InsightsStore.shared.quran == nil { await InsightsStore.shared.fetchAll() }
      if let plan = store.plan { apply(plan) }
    }
  }

  private var signIn: some View {
    VStack(spacing: 0) {
      Spacer()
      Ionicon("book-outline", size: 44, color: tokens.inkSubtle)
      Text(t("hatim.plan.signIn")).font(.system(size: 15)).foregroundStyle(tokens.textSecondary)
        .multilineTextAlignment(.center).padding(.top, 16).padding(.horizontal, 32)
      AppButton(title: t("hatim.plan.signInButton")) {
        Haptics.impact(.light)
        AuthFlow.shared.present()
      }
      .frame(width: 200).padding(.top, 20)
      Spacer()
    }
  }

  @ViewBuilder private var current: some View {
    Card {
      Text(t("hatim.card.title")).font(.system(size: 17, weight: .semibold)).foregroundStyle(tokens.textPrimary)
      if let p = store.progress() {
        Text(p.finished ? t("hatim.card.finished") : p.overdue ? t("hatim.card.overdue")
          : t("hatim.plan.status", ["pages": p.remaining, "days": p.daysLeft, "daily": p.dailyTarget]))
          .font(.system(size: 14)).lineSpacing(3).foregroundStyle(tokens.textSecondary).tabularNumbers().padding(.top, 5.25)
      }
      AppButton(title: t("hatim.plan.delete"), variant: .outline) {
        Haptics.impact(.light)
        AppAlert.confirm(
          t("hatim.plan.deleteTitle"), t("hatim.plan.deleteBody"), confirmText: t("hatim.plan.delete"),
          cancelText: t("common.cancel"), destructive: true
        ) { store.set(nil) }
      }
      .padding(.top, 14)
    }
  }

  private var setup: some View {
    let q = InsightsStore.shared.quran
    let remaining = q.map { max(0, $0.pagesPerHatim - $0.currentPages) } ?? 604
    let days = max(1, (Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: target)).day ?? 0) + 1)
    return Card {
      Text(t("hatim.plan.subtitle")).font(.system(size: 15)).lineSpacing(3).foregroundStyle(tokens.textSecondary)
      VStack(spacing: 7) {
        if ramadanEnd != nil { option(.ramadan, t("hatim.plan.ramadanEnd")) }
        ForEach([30, 60, 90], id: \.self) { option(.days($0), t("hatim.plan.days", ["count": $0])) }
        option(.custom, t("hatim.plan.custom"))
        if preset == .custom {
          DatePicker(t("hatim.plan.custom"), selection: $custom, in: Date()..., displayedComponents: .date)
            .labelsHidden().environment(\.locale, Localizer.shared.locale).tint(tokens.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      .padding(.top, 14)

      // Bugün okunan da hedefe dahil: kayıtlı planla aynı sonuç.
      Text(t("hatim.plan.daily", ["pages": HatimPlan.dailyPages(pages: remaining + store.todayRead, daysLeft: days)]))
        .font(.system(size: 28, weight: .bold)).foregroundStyle(tokens.textPrimary).tabularNumbers().padding(.top, 17.5)
      Text(t("hatim.plan.remaining", ["pages": remaining, "days": days]))
        .font(.system(size: 13)).foregroundStyle(tokens.textSecondary).tabularNumbers().padding(.top, 1.75)

      reminder.padding(.top, 17.5)

      AppButton(title: t(store.plan == nil ? "hatim.plan.start" : "hatim.plan.update")) {
        Haptics.notify(.success)
        save(completed: q?.completedHatims ?? 0)
        Toast.success(t("hatim.plan.saved"))
        dismiss()
      }
      .padding(.top, 17.5)
    }
  }

  @ViewBuilder private var reminder: some View {
    let enabled = NotificationStore.shared.preferences.enabled
    HStack(spacing: 10.5) {
      VStack(alignment: .leading, spacing: 1.75) {
        Text(t("hatim.plan.reminder")).font(.system(size: 15, weight: .medium)).foregroundStyle(tokens.textPrimary)
        if !enabled {
          Text(t("hatim.plan.reminderNeeds")).font(.system(size: 13)).foregroundStyle(tokens.textSecondary)
        }
      }
      Spacer(minLength: 0)
      if reminderOn && enabled {
        DatePicker("", selection: $reminderTime, displayedComponents: .hourAndMinute)
          .labelsHidden().environment(\.locale, Localizer.shared.locale)
      }
      Toggle("", isOn: Binding(get: { reminderOn && enabled }, set: { reminderOn = $0 })).labelsHidden().tint(tokens.accent).disabled(!enabled)
    }
    .accessibilityElement(children: .contain)
  }

  private func option(_ value: Preset, _ label: String) -> some View {
    let on = preset == value
    return Button {
      Haptics.selection()
      preset = value
    } label: {
      HStack {
        Text(label).font(.system(size: 15, weight: on ? .semibold : .regular)).foregroundStyle(tokens.textPrimary)
        Spacer()
        Ionicon(on ? "checkmark-circle" : "ellipse-outline", size: 20, color: on ? tokens.accent : tokens.inkSubtle)
      }
      .padding(.horizontal, 14).padding(.vertical, 10.5)
      .background(on ? tokens.fill : .clear, in: .rect(cornerRadius: 14))
      .overlay(RoundedRectangle(cornerRadius: 14).stroke(tokens.line, lineWidth: 1))
    }
    .buttonStyle(PressableStyle())
  }

  private func apply(_ plan: HatimPlan) {
    if let date = HatimPlan.parse(plan.targetDate, calendar: .current) {
      preset = .custom
      custom = date
    }
    reminderOn = plan.reminderHour != nil
    if let hour = plan.reminderHour, let minute = plan.reminderMinute,
      let time = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) {
      reminderTime = time
    }
  }

  private func save(completed: Int) {
    let c = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
    let on = reminderOn && NotificationStore.shared.preferences.enabled
    store.set(.init(
      targetDate: localDateString(target),
      // Var olan planı güncellemek hatim sayacını sıfırlamasın.
      startHatims: store.plan?.startHatims ?? completed,
      reminderHour: on ? c.hour : nil, reminderMinute: on ? c.minute : nil))
  }
}
