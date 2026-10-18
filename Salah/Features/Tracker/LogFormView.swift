import SwiftUI

/// İbadet kayıt formu (alttan açılan pencere). RN: TrackerScreen `LogForm`.
struct LogFormView: View {
  @Environment(\.tokens) private var tokens
  let type: ActivityType
  let onClose: () -> Void

  @State private var pages = ""
  @State private var minutes = ""
  @State private var bookName = ""
  @State private var nafileType = "teheccud"
  @State private var rakaat = ""
  @State private var fastingType = "nafile"
  @State private var amount = ""
  @State private var sadakaDescription = ""
  @State private var newAyets = ""
  @State private var revisionAyets = ""
  @State private var notes = ""
  @State private var saving = false

  private static let noteLimit = 500

  var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        VStack(spacing: 0) {
          header
          fields
            .padding(.horizontal, 17.5)
            .padding(.top, 3.5)
        }
      }
      .scrollDismissesKeyboard(.interactively)

      HStack(spacing: 10.5) {
        AppButton(title: t("common.cancel"), variant: .secondary, action: onClose)
        AppButton(title: t("common.save"), loading: saving) { Task { await submit() } }
      }
      .padding(.horizontal, 17.5)
      .padding(.vertical, 14)
      .overlay(alignment: .top) { RowDivider(leading: 0) }
    }
    .padding(.top, 20)
  }

  private var header: some View {
    HStack(spacing: 10.5) {
      Ionicon(type.icon, size: 19, color: tokens.accent)
        .frame(width: 35, height: 35)
        .background(tokens.isDark ? Accent.s900 : Accent.s50, in: .circle)
      VStack(alignment: .leading, spacing: 0) {
        Text(type.label)
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(tokens.textPrimary)
          .accessibilityAddTraits(.isHeader)
        Text(type.descriptionText)
          .font(.system(size: 13))
          .foregroundStyle(tokens.textSecondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.horizontal, 17.5)
    .padding(.bottom, 14)
    .overlay(alignment: .bottom) { RowDivider(leading: 0) }
    .padding(.bottom, 14)
  }

  @ViewBuilder
  private var fields: some View {
    VStack(alignment: .leading, spacing: 0) {
      switch type {
      case .quran:
        stepper(t("tracker.form.pages"), $pages)
        minutesField($minutes)
      case .book:
        InputField(label: t("tracker.form.bookName"), placeholder: t("tracker.form.bookPlaceholder"), text: $bookName)
        stepper(t("tracker.form.pages"), $pages)
        minutesField($minutes)
      case .nafile:
        chips(t("tracker.form.prayerType"), TrackerText.nafileTypes, $nafileType, label: TrackerText.nafile)
        stepper(t("tracker.form.rakaat"), $rakaat, step: 2)
      case .fasting:
        chips(t("tracker.form.fastingType"), TrackerText.fastingTypes, $fastingType) { TrackerText.fasting($0) }
      case .sadaka:
        InputField(label: t("tracker.form.amount"), placeholder: t("tracker.form.amountPlaceholder"), text: $amount, keyboard: .decimalPad)
        InputField(label: t("tracker.form.description"), placeholder: t("tracker.form.descriptionPlaceholder"), text: $sadakaDescription)
      case .dua:
        stepper(t("tracker.form.minutesRequired"), $minutes, step: 5)
      case .memorization:
        stepper(t("tracker.form.newVerses"), $newAyets)
        stepper(t("tracker.form.revisedVerses"), $revisionAyets)
      }

      let placeholderKey = [.quran, .dua, .fasting, .memorization].contains(type) ? type.rawValue : "default"
      InputField(
        label: t("tracker.form.note"), placeholder: t("tracker.form.notePlaceholder.\(placeholderKey)"),
        text: $notes, maxLength: Self.noteLimit)
      if !notes.isEmpty {
        Text("\(notes.count)/\(Self.noteLimit)")
          .font(.system(size: 10.5))
          .foregroundStyle(tokens.isDark ? Forest.s500 : Forest.s400)
          .frame(maxWidth: .infinity, alignment: .trailing)
          .padding(.top, -7)
      }
    }
  }

  private func minutesField(_ binding: Binding<String>) -> some View {
    InputField(
      label: t("tracker.form.minutesOptional"), placeholder: t("tracker.form.minutesPlaceholder"),
      text: binding, keyboard: .numberPad)
  }

  private func stepper(_ label: String, _ value: Binding<String>, step: Int = 1) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      FieldLabel(label)
      NumberStepper(value: value, step: step)
    }
    .padding(.bottom, 14)
  }

  private func chips(_ title: String, _ options: [String], _ selection: Binding<String>, label: @escaping (String) -> String) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      FieldLabel(title)
      FlowLayout(spacing: 7) {
        ForEach(options, id: \.self) { option in
          Chip(title: label(option), selected: selection.wrappedValue == option) {
            selection.wrappedValue = option
          }
        }
      }
    }
    .padding(.bottom, 14)
  }

  private func submit() async {
    func num(_ s: String) -> Double { Double(s.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    var value: [String: JSONValue] = [:]
    let error: String?
    switch type {
    case .quran, .book:
      error = num(pages) < 1 ? "tracker.errors.pages" : nil
      value["pages"] = .number(num(pages))
      if num(minutes) > 0 { value["minutes"] = .number(num(minutes)) }
      let name = bookName.trimmingCharacters(in: .whitespacesAndNewlines)
      if type == .book, !name.isEmpty { value["name"] = .string(name) }
    case .nafile:
      error = num(rakaat) < 1 ? "tracker.errors.rakaat" : nil
      value = ["type": .string(nafileType), "rakaat": .number(num(rakaat))]
    case .fasting:
      error = nil
      value = ["type": .string(fastingType)]
    case .sadaka:
      error = amount.isEmpty || num(amount) < 0 ? "tracker.errors.amount" : nil
      value["amount"] = .number(num(amount))
      if !sadakaDescription.isEmpty { value["description"] = .string(sadakaDescription) }
    case .dua:
      error = num(minutes) < 1 ? "tracker.errors.minutes" : nil
      value = ["minutes": .number(num(minutes))]
    case .memorization:
      error = newAyets.isEmpty && revisionAyets.isEmpty ? "tracker.errors.memorization" : nil
      value["new_ayets"] = .number(num(newAyets))
      if !revisionAyets.isEmpty { value["revision_ayets"] = .number(num(revisionAyets)) }
    }
    if let error {
      AppAlert.error(t("common.error"), t(error))
      return
    }

    saving = true
    defer { saving = false }
    do {
      try await TrackerStore.shared.log(type, value: .object(value), notes: notes.isEmpty ? nil : notes)
      Haptics.notify(.success)
      onClose()
    } catch {
      AppAlert.error(t("common.error"), t("tracker.errors.saveFailed"))
    }
  }
}

/// −/+ düğmeli sayı alanı. RN: TrackerScreen `NumberStepper`.
private struct NumberStepper: View {
  @Environment(\.tokens) private var tokens
  @Binding var value: String
  var step = 1

  var body: some View {
    let current = Int(value) ?? 0
    HStack(spacing: 10.5) {
      button("remove", t("common.decrease")) { value = String(max(0, current - step)) }
      TextField("", text: $value, prompt: Text(verbatim: "0").foregroundStyle(tokens.inkSubtle))
        .font(.system(size: 14))
        .foregroundStyle(tokens.textPrimary)
        .tint(tokens.accent)
        .multilineTextAlignment(.center)
        .keyboardType(.numberPad)
        .monospacedDigit()
        .frame(height: 42)
        .background(tokens.isDark ? Forest.s900 : .white, in: .rect(cornerRadius: 10.5))
        .overlay(RoundedRectangle(cornerRadius: 10.5).stroke(tokens.isDark ? Forest.s700 : Forest.s200, lineWidth: 1))
      button("add", t("common.increase")) { value = String(current + step) }
    }
  }

  private func button(_ icon: String, _ label: String, action: @escaping () -> Void) -> some View {
    Button {
      Haptics.impact(.light)
      action()
    } label: {
      Ionicon(icon, size: 20, color: tokens.inkMuted)
        .frame(width: 42, height: 42)
        .background(tokens.fill, in: .circle)
    }
    .buttonStyle(PressableStyle())
    .accessibilityLabel(label)
  }
}
