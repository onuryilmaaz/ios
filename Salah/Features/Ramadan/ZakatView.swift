import SwiftUI

/// Zekât, fitre ve fidye hesabı: sonuç üstte sabit, altında yalnız seçili hesabın alanları.
/// Girilen tutarlar saklanmaz.
struct ZakatView: View {
  private enum Section: String, CaseIterable, Identifiable {
    case zakat = "zakat.tabZakat"
    case fitre = "zakat.tabFitre"
    case fidye = "zakat.tabFidye"
    var id: String { rawValue }
  }

  @Environment(\.tokens) private var tokens
  @Environment(\.openURL) private var openURL
  @State private var section = Section.zakat
  @State private var gold = ""
  @State private var price = ""
  @State private var cash = ""
  @State private var trade = ""
  @State private var receivable = ""
  @State private var debt = ""
  @State private var people = "1"
  @State private var fidyeDays = "1"
  @State private var paid = false
  @State private var showConditions = false
  /// Sunucudan yazılan altın fiyatı: kullanıcı değiştirdiyse üzerine yazılmaz.
  @State private var autoPrice: String?

  private static let zakatSource = "https://kurul.diyanet.gov.tr/Cevap-Ara/406/farkli-ayarda-altini-bulunan-kimse-zekatini-nasil-hesaplar"
  private static let fidyeSource = "https://fetva.diyanet.gov.tr/Cevap-Ara/532/fidye-nedir-hangi-durumlarda-gerekir"
  private var paidKey: String { "@salah_fitre_paid_\(RamadanSchedule.window(ReligiousCalendarService.cached()).hijriYear)" }

  private func money(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(0...2)).locale(Localizer.shared.locale))
  }

  private func tl(_ value: Double) -> String { t("zakat.money", ["amount": money(value)]) }

  private func count(_ text: String) -> Int { max(0, Int(ZakatCalc.parseAmount(text, grouped: false))) }

  var body: some View {
    let config = RamadanConfigStore.shared.config
    VStack(spacing: 0) {
      StandardHeader(title: t("zakat.title"))
      VStack(spacing: 12) {
        tabs
        result(config)
      }
      .padding(.horizontal, 14)
      .padding(.top, 4)
      .padding(.bottom, 12)
      ScrollView {
        VStack(alignment: .leading, spacing: 14) {
          switch section {
          case .zakat: zakatForm
          case .fitre: fitreForm(config)
          case .fidye: fidyeForm(config)
          }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 24)
      }
      .scrollIndicators(.hidden)
      .scrollDismissesKeyboard(.interactively)
    }
    .background(tokens.canvas)
    .toolbar(.hidden, for: .navigationBar)
    .toolbar {
      ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button(t("zakat.keyboardDone")) {
          Haptics.impact(.light)
          UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .tint(tokens.accent)
      }
    }
    .task {
      switch DebugLaunch.sheet {
      case "fitre": section = .fitre
      case "fidye": section = .fidye
      case "filled":
        price = "6.000"
        cash = "1.250.000"
        showConditions = true
      case "gold":
        price = money(6556.39)
        autoPrice = price
        cash = "1.250.000"
      default: break
      }
      paid = LocalStore.string(paidKey) == "true"
      applyGoldPrice()
      await RamadanConfigStore.shared.refresh()
      applyGoldPrice()
    }
  }

  private func applyGoldPrice() {
    guard let value = RamadanConfigStore.shared.config.goldPricePerGram, price.isEmpty || price == autoPrice else { return }
    price = money(value)
    autoPrice = price
  }

  private var priceHint: String {
    guard price == autoPrice else { return t("zakat.goldPriceHint") }
    let parser = ISO8601DateFormatter()
    parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    var when = Date()
    if let raw = RamadanConfigStore.shared.config.goldPriceAt, let parsed = parser.date(from: raw) { when = parsed }
    let formatter = DateFormatter()
    formatter.locale = Localizer.shared.locale
    formatter.dateFormat = "dd.MM HH:mm"
    return t("zakat.goldPriceAuto", ["time": formatter.string(from: when)])
  }

  private var tabs: some View {
    HStack(spacing: 4) {
      ForEach(Section.allCases) { item in
        let selected = section == item
        Button {
          guard !selected else { return }
          Haptics.impact(.light)
          section = item
          UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        } label: {
          Text(t(item.rawValue))
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(selected ? tokens.surface : tokens.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 38)
            .background(selected ? tokens.accent : .clear, in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
      }
    }
    .padding(4)
    .background(tokens.fill, in: .capsule)
  }

  @ViewBuilder
  private func result(_ config: RamadanConfigStore.Config) -> some View {
    switch section {
    case .zakat:
      let goldPrice = ZakatCalc.parseAmount(price)
      let value = ZakatCalc.compute(
        goldGrams: ZakatCalc.parseAmount(gold, grouped: false), goldPrice: goldPrice, cash: ZakatCalc.parseAmount(cash), trade: ZakatCalc.parseAmount(trade),
        receivable: ZakatCalc.parseAmount(receivable), debt: ZakatCalc.parseAmount(debt), nisabGrams: config.nisabGoldGrams)
      if goldPrice <= 0 {
        resultCard(label: nil, value: nil, title: t("zakat.resultNeedPrice"), detail: t("zakat.resultNeedPriceBody"), fraction: nil)
      } else if value.due {
        resultCard(label: t("zakat.resultDue"), value: tl(value.amount), title: nil, detail: t("zakat.netVsNisab", ["net": money(value.net), "nisab": money(value.nisab)]), fraction: 1)
      } else {
        resultCard(label: nil, value: nil, title: t("zakat.resultNone"), detail: t("zakat.netVsNisab", ["net": money(max(0, value.net)), "nisab": money(value.nisab)]), fraction: max(0, value.net) / value.nisab)
      }
    case .fitre:
      let n = count(people)
      resultCard(label: t("zakat.fitreResult"), value: tl(Double(n) * config.fitreAmount), title: nil, detail: t("zakat.fitreCalc", ["count": n, "amount": money(config.fitreAmount)]), fraction: nil)
    case .fidye:
      let n = count(fidyeDays)
      resultCard(label: t("zakat.fidyeResult"), value: tl(Double(n) * config.fidyeAmount), title: nil, detail: t("zakat.fidyeCalc", ["count": n, "amount": money(config.fidyeAmount)]), fraction: nil)
    }
  }

  private func resultCard(label: String?, value: String?, title: String?, detail: String, fraction: Double?) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      if let label { Text(label).font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.85)) }
      if let value {
        Text(value).font(.system(size: 30, weight: .semibold)).foregroundStyle(Gold.s300).tabularNumbers().lineLimit(1).minimumScaleFactor(0.6)
      }
      if let title { Text(title).font(.system(size: 17, weight: .semibold)).foregroundStyle(.white) }
      Text(detail).font(.system(size: 13)).foregroundStyle(.white.opacity(0.85)).tabularNumbers().lineLimit(2).minimumScaleFactor(0.85)
      if let fraction, fraction.isFinite {
        GeometryReader { geo in
          ZStack(alignment: .leading) {
            Capsule().fill(.white.opacity(0.2))
            Capsule().fill(Gold.s300).frame(width: geo.size.width * min(1, max(0, fraction)))
          }
        }
        .frame(height: 5)
        .padding(.top, 7)
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Accent.s800, in: .rect(cornerRadius: 21))
    .accessibilityElement(children: .combine)
  }

  @ViewBuilder
  private var zakatForm: some View {
    Card {
      AmountRow(label: t("zakat.goldPrice"), unit: t("zakat.unitTl"), text: $price)
      Text(priceHint).font(.system(size: 13)).lineSpacing(3).foregroundStyle(tokens.textSecondary).tabularNumbers().padding(.top, 2)
    }
    Card {
      sectionTitle("zakat.assets")
      AmountRow(label: t("zakat.gold"), unit: t("zakat.unitGram"), text: $gold)
      Divider().overlay(tokens.line)
      AmountRow(label: t("zakat.cash"), unit: t("zakat.unitTl"), text: $cash)
      Divider().overlay(tokens.line)
      AmountRow(label: t("zakat.trade"), unit: t("zakat.unitTl"), text: $trade)
      Divider().overlay(tokens.line)
      AmountRow(label: t("zakat.receivable"), unit: t("zakat.unitTl"), text: $receivable)
    }
    Card {
      sectionTitle("zakat.deduct")
      AmountRow(label: t("zakat.debt"), unit: t("zakat.unitTl"), text: $debt)
    }
    Card {
      Button {
        Haptics.impact(.light)
        showConditions.toggle()
      } label: {
        HStack {
          Text(t("zakat.whoTitle")).font(.system(size: 15, weight: .semibold)).foregroundStyle(tokens.textPrimary).multilineTextAlignment(.leading)
          Spacer(minLength: 8)
          Ionicon(showConditions ? "chevron-up" : "chevron-down", size: 16, color: tokens.inkSubtle)
        }
        .frame(minHeight: 32)
        .contentShape(.rect)
      }
      .buttonStyle(PressableStyle())
      if showConditions {
        VStack(alignment: .leading, spacing: 8) {
          note("zakat.conditions")
          note("zakat.disclaimer")
          source(Self.zakatSource)
        }
        .padding(.top, 8)
      }
    }
  }

  @ViewBuilder
  private func fitreForm(_ config: RamadanConfigStore.Config) -> some View {
    Card {
      CountRow(label: t("zakat.people"), text: $people, range: 1...99)
      note("zakat.fitreNote", ["period": config.period, "amount": money(config.fitreAmount)]).padding(.top, 8)
    }
    AppButton(title: t(paid ? "zakat.fitreDone" : "zakat.fitrePaid"), variant: paid ? .outline : .primary) {
      Haptics.impact(.medium)
      paid.toggle()
      LocalStore.set(paid ? "true" : nil, for: paidKey)
    }
  }

  @ViewBuilder
  private func fidyeForm(_ config: RamadanConfigStore.Config) -> some View {
    Card {
      CountRow(label: t("zakat.days"), text: $fidyeDays, range: 1...99)
    }
    Card {
      Text(t("zakat.whoFidye")).font(.system(size: 15, weight: .semibold)).foregroundStyle(tokens.textPrimary).padding(.bottom, 6)
      VStack(alignment: .leading, spacing: 8) {
        note("zakat.fidyeNote")
        note("zakat.disclaimer")
        source(Self.fidyeSource)
      }
    }
  }

  private func sectionTitle(_ key: String) -> some View {
    Text(t(key)).font(.system(size: 13, weight: .semibold)).foregroundStyle(tokens.textSecondary).padding(.bottom, 2)
  }

  private func note(_ key: String, _ values: [String: any CustomStringConvertible] = [:]) -> some View {
    Text(t(key, values)).font(.system(size: 13)).lineSpacing(3).foregroundStyle(tokens.textSecondary)
  }

  private func source(_ link: String) -> some View {
    Button {
      Haptics.impact(.light)
      if let url = URL(string: link) { openURL(url) }
    } label: {
      HStack(spacing: 6) {
        Ionicon("open-outline", size: 15, color: tokens.accent)
        Text(t("zakat.source")).font(.system(size: 14, weight: .medium)).foregroundStyle(tokens.accent)
      }
      .padding(.vertical, 4)
    }
    .buttonStyle(PressableStyle())
  }
}

/// Solda etiket, sağda birimli tutar; satırın tamamı dokunulabilir.
private struct AmountRow: View {
  @Environment(\.tokens) private var tokens
  let label: String
  let unit: String
  @Binding var text: String
  @FocusState private var focused: Bool

  var body: some View {
    HStack(spacing: 8) {
      Text(label).font(.system(size: 15)).foregroundStyle(tokens.textPrimary).lineLimit(2).minimumScaleFactor(0.85)
      Spacer(minLength: 4)
      TextField("", text: $text, prompt: Text(verbatim: "0").foregroundStyle(tokens.inkSubtle))
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(tokens.textPrimary)
        .tint(tokens.accent)
        .monospacedDigit()
        .multilineTextAlignment(.trailing)
        .keyboardType(.decimalPad)
        .focused($focused)
        .frame(width: 110)
        .accessibilityLabel(label)
      Text(unit).font(.system(size: 13)).foregroundStyle(tokens.textSecondary).frame(width: 36, alignment: .leading)
    }
    .frame(minHeight: 48)
    .contentShape(.rect)
    .onTapGesture { focused = true }
  }
}

/// Eksi/artı düğmeli sayı; ortadaki değer elle de yazılabilir.
private struct CountRow: View {
  @Environment(\.tokens) private var tokens
  let label: String
  @Binding var text: String
  let range: ClosedRange<Int>

  private var value: Int { Int(ZakatCalc.parseAmount(text, grouped: false)) }

  var body: some View {
    HStack(spacing: 8) {
      Text(label).font(.system(size: 15)).foregroundStyle(tokens.textPrimary).lineLimit(2)
      Spacer(minLength: 4)
      step("remove", key: "zakat.decrease", enabled: value > range.lowerBound) { text = "\(max(range.lowerBound, value - 1))" }
      TextField("", text: $text)
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(tokens.textPrimary)
        .tint(tokens.accent)
        .monospacedDigit()
        .multilineTextAlignment(.center)
        .keyboardType(.numberPad)
        .frame(width: 44)
        .accessibilityLabel(label)
        .onChange(of: text) { _, next in
          if value > range.upperBound { text = "\(range.upperBound)" } else if next.count > 3 { text = String(next.prefix(3)) }
        }
      step("add", key: "zakat.increase", enabled: value < range.upperBound) { text = "\(min(range.upperBound, value + 1))" }
    }
    .frame(minHeight: 48)
  }

  private func step(_ icon: String, key: String, enabled: Bool, action: @escaping () -> Void) -> some View {
    Button {
      Haptics.impact(.light)
      action()
    } label: {
      Ionicon(icon, size: 20, color: enabled ? tokens.accent : tokens.inkSubtle)
        .frame(width: 44, height: 44)
        .background(tokens.fill, in: .circle)
    }
    .buttonStyle(PressableStyle())
    .disabled(!enabled)
    .accessibilityLabel(t(key))
  }
}
