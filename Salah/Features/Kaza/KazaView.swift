import SwiftUI

/// Kaza borcu: vakit başına sayaç (- / +), toplam ve bitiş tahmini, vitir seçimi, hesaplayıcı.
struct KazaView: View {
  @Environment(\.tokens) private var tokens
  @State private var calculator = false

  var body: some View {
    let store = KazaStore.shared
    VStack(spacing: 0) {
      StandardHeader(title: t("kaza.title"))
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          summary(store)
          counters(store)
          witrRow(store)
          AppButton(title: t("kaza.calculate"), variant: .secondary) {
            Haptics.impact(.light)
            calculator = true
          }
          info
        }
        .padding(16).padding(.bottom, 84)
      }
      .scrollIndicators(.hidden)
      .refreshable { await store.fetch() }
    }
    .background(tokens.canvas)
    .toolbar(.hidden, for: .navigationBar)
    .task { await store.fetch() }
    .sheet(isPresented: $calculator) {
      KazaCalculatorView().environment(\.tokens, tokens).presentationDetents([.large]).presentationDragIndicator(.visible)
    }
  }

  private func summary(_ store: KazaStore) -> some View {
    let total = store.total
    let finish = KazaPlan.finishDate(store.debt.counts, witr: store.debt.witr, perDay: store.perDay, from: Date())
    return VStack(alignment: .leading, spacing: 0) {
      Text(t("kaza.total")).font(.system(size: 13, weight: .medium)).foregroundStyle(Gold.s300)
      Text("\(total)").font(.system(size: 34, weight: .bold)).foregroundStyle(.white).tabularNumbers().padding(.top, 3.5)
      if let finish {
        HStack(spacing: 10.5) {
          Text(t("kaza.finish", ["perDay": store.perDay, "date": finish.formatted(.dateTime.day().month(.wide).year().locale(Localizer.shared.locale))]))
            .font(.system(size: 13)).foregroundStyle(.white.opacity(0.85)).frame(maxWidth: .infinity, alignment: .leading)
          stepper(store)
        }.padding(.top, 10.5)
      } else {
        Text(t(store.loaded || total == 0 ? "kaza.empty" : "common.loading")).font(.system(size: 13)).foregroundStyle(.white.opacity(0.85)).padding(.top, 7)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(17.5)
    .background(Accent.s800, in: .rect(cornerRadius: 24))
  }

  /// Günlük kaza sayısı (bitiş tahmini için).
  private func stepper(_ store: KazaStore) -> some View {
    HStack(spacing: 7) {
      circle("remove", label: t("kaza.perDayLess"), enabled: store.perDay > 1) { store.perDay -= 1 }
      circle("add", label: t("kaza.perDayMore"), enabled: store.perDay < 20) { store.perDay += 1 }
    }
  }

  private func circle(_ icon: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
    Button { Haptics.impact(.light); action() } label: {
      Ionicon(icon, size: 16, color: .white).frame(width: 30, height: 30).background(.white.opacity(0.15), in: .circle)
    }.buttonStyle(PressableStyle()).disabled(!enabled).opacity(enabled ? 1 : 0.4).accessibilityLabel(label)
  }

  private func counters(_ store: KazaStore) -> some View {
    GroupedCard {
      let prayers = KazaPlan.visiblePrayers(witr: store.debt.witr)
      ForEach(Array(prayers.enumerated()), id: \.element) { i, id in
        if i > 0 { RowDivider() }
        KazaCounterRow(prayer: id, count: store.debt.counts[id] ?? 0)
      }
    }
  }

  private func witrRow(_ store: KazaStore) -> some View {
    HStack(spacing: 10.5) {
      VStack(alignment: .leading, spacing: 1.75) {
        Text(t("kaza.witrToggle")).font(.system(size: 15, weight: .medium)).foregroundStyle(tokens.textPrimary)
        Text(t("kaza.witrHint")).font(.system(size: 13)).foregroundStyle(tokens.textSecondary)
      }.frame(maxWidth: .infinity, alignment: .leading)
      Toggle("", isOn: Binding(get: { store.debt.witr }, set: { on in
        Haptics.impact(.medium)
        Task { await store.setWitr(on) }
      })).labelsHidden().tint(tokens.accent)
    }
    .padding(14)
    .background(tokens.surface, in: .rect(cornerRadius: 21))
    .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
  }

  private var info: some View {
    HStack(alignment: .top, spacing: 7) {
      Ionicon("information-circle", size: 16, color: Amber.s500).padding(.top, 2)
      Text(t("kaza.info")).font(.system(size: 12)).lineSpacing(6)
        .foregroundStyle(tokens.isDark ? Amber.s300 : Amber.s700).frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(14)
    .background(tokens.isDark ? Amber.s500.opacity(0.1) : Amber.s50, in: .rect(cornerRadius: 14))
  }
}

private struct KazaCounterRow: View {
  @Environment(\.tokens) private var tokens
  let prayer: String
  let count: Int

  private var label: String { prayer == "witr" ? t("kaza.witr") : prayerLabel(prayer) }

  var body: some View {
    HStack(spacing: 10.5) {
      Ionicon(prayerIcon(prayer == "witr" ? "isha" : prayer), size: 18, color: tokens.accent)
        .frame(width: 35, height: 35)
        .background(tokens.accentSoft, in: .circle)
      Text(label).font(.system(size: 15, weight: .medium)).foregroundStyle(tokens.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
      button("remove", a11y: t("kaza.decrease", ["prayer": label]), enabled: count > 0, delta: -1)
      Text("\(count)").font(.system(size: 17, weight: .semibold)).foregroundStyle(tokens.textPrimary).tabularNumbers()
        .frame(minWidth: 44)
        .accessibilityLabel(t("kaza.countA11y", ["prayer": label, "count": count]))
      button("add", a11y: t("kaza.increase", ["prayer": label]), enabled: count < KazaPlan.max, delta: 1)
    }
    .padding(.horizontal, 14).padding(.vertical, 10.5)
  }

  private func button(_ icon: String, a11y: String, enabled: Bool, delta: Int) -> some View {
    Button {
      Haptics.impact(.medium)
      Task { await KazaStore.shared.adjust(prayer, by: delta) }
    } label: {
      Ionicon(icon, size: 18, color: delta < 0 ? tokens.inkMuted : .white)
        .frame(width: 35, height: 35)
        .background(delta < 0 ? tokens.fill : (tokens.isDark ? Accent.s500 : Accent.s600), in: .circle)
    }
    .buttonStyle(PressableStyle())
    .disabled(!enabled).opacity(enabled ? 1 : 0.4)
    .accessibilityLabel(a11y)
  }
}

/// Hesaplayıcı: kaza başlangıcı ve bitişi arasındaki gün sayısı; kadınlarda aylık özel gün düşülür.
struct KazaCalculatorView: View {
  @Environment(\.tokens) private var tokens
  @Environment(\.dismiss) private var dismiss
  @State private var start = Calendar.current.date(byAdding: .year, value: -10, to: Date()) ?? Date()
  @State private var end = Date()
  @State private var deduct = OzelGunStore.shared.gender == "kadin"
  @State private var monthly = 7

  var body: some View {
    let store = KazaStore.shared
    let days = KazaPlan.owedDays(from: start, to: end, monthlyExemptDays: deduct ? monthly : 0)
    VStack(spacing: 0) {
      HStack {
        Text(t("kaza.calcTitle")).font(.system(size: 17, weight: .semibold)).foregroundStyle(tokens.textPrimary)
        Spacer()
        Button { Haptics.impact(.light); dismiss() } label: {
          Ionicon("close", size: 20, color: tokens.inkMuted).frame(width: 35, height: 35).background(tokens.surface, in: .circle)
            .overlay(Circle().stroke(tokens.line, lineWidth: 1))
        }.buttonStyle(PressableStyle()).accessibilityLabel(t("common.close"))
      }.padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 10)

      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          Text(t("kaza.calcHint")).font(.system(size: 13)).foregroundStyle(tokens.textSecondary)
          GroupedCard {
            dateRow(t("kaza.calcStart"), $start, range: Date.distantPast...end)
            RowDivider()
            dateRow(t("kaza.calcEnd"), $end, range: start...Date())
            RowDivider()
            HStack {
              Text(t("kaza.calcDeduct")).font(.system(size: 15, weight: .medium)).foregroundStyle(tokens.textPrimary)
              Spacer()
              Toggle("", isOn: $deduct).labelsHidden().tint(tokens.accent)
            }.padding(14)
            if deduct {
              RowDivider()
              HStack {
                Text(t("kaza.calcMonthly", ["days": monthly])).font(.system(size: 15)).foregroundStyle(tokens.textPrimary).tabularNumbers()
                Spacer()
                Stepper("", value: $monthly, in: 1...15).labelsHidden()
              }.padding(14)
            }
          }
          VStack(alignment: .leading, spacing: 3.5) {
            Text(t("kaza.calcResult", ["days": days])).font(.system(size: 22, weight: .bold)).foregroundStyle(tokens.textPrimary).tabularNumbers()
            Text(t("kaza.calcEach", ["days": days])).font(.system(size: 13)).foregroundStyle(tokens.textSecondary).tabularNumbers()
          }
          AppButton(title: t("kaza.calcApply")) {
            Haptics.impact(.medium)
            let counts = Dictionary(uniqueKeysWithValues: KazaPlan.visiblePrayers(witr: store.debt.witr).map { ($0, days) })
            let apply = {
              await store.setCounts(counts)
              Haptics.notify(.success)
              dismiss()
            }
            if store.total > 0 {
              AppAlert.confirm(t("kaza.calcReplaceTitle"), t("kaza.calcReplaceMessage"), confirmText: t("kaza.calcApply")) { await apply() }
            } else {
              Task { await apply() }
            }
          }
          .disabled(days == 0)
        }
        .padding(16).padding(.bottom, 24)
      }.scrollIndicators(.hidden)
    }
    .background(tokens.canvas)
  }

  private func dateRow(_ label: String, _ value: Binding<Date>, range: ClosedRange<Date>) -> some View {
    HStack {
      Text(label).font(.system(size: 15, weight: .medium)).foregroundStyle(tokens.textPrimary)
      Spacer()
      DatePicker("", selection: value, in: range, displayedComponents: .date)
        .labelsHidden().environment(\.locale, Localizer.shared.locale).tint(tokens.accent)
    }.padding(14)
  }
}

/// Ana sayfa kartı: toplam borç ve bitiş tahmini; dokununca kaza ekranı.
struct KazaCard: View {
  @Environment(\.tokens) private var tokens
  let onOpen: () -> Void

  var body: some View {
    let store = KazaStore.shared
    Button { Haptics.impact(.light); onOpen() } label: {
      HStack(spacing: 10.5) {
        Ionicon("hourglass-outline", size: 22, color: tokens.gold)
          .frame(width: 42, height: 42)
          .background(tokens.isDark ? Gold.s700.opacity(0.25) : Gold.s100, in: .circle)
        VStack(alignment: .leading, spacing: 1.75) {
          Text(t("kaza.title")).font(.system(size: 13)).foregroundStyle(tokens.textSecondary)
          if store.total > 0 {
            Text(t("kaza.cardTotal", ["count": store.total])).font(.system(size: 17, weight: .semibold)).foregroundStyle(tokens.textPrimary).tabularNumbers()
          } else {
            Text(t("kaza.cardEmpty")).font(.system(size: 15, weight: .semibold)).foregroundStyle(tokens.textPrimary)
          }
        }.frame(maxWidth: .infinity, alignment: .leading)
        Ionicon(dirIcon("chevron-forward"), size: 18, color: tokens.inkSubtle)
      }
      .padding(17.5)
      .background(tokens.surface, in: .rect(cornerRadius: 21))
      .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
    }
    .buttonStyle(PressableStyle())
    .padding(.horizontal, 14).padding(.bottom, 10.5)
    .task { await store.fetch() }
  }
}
