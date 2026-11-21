import SwiftUI

/// Dua defteri: kendi duaların ve niyetlerin; istersen seçtiğin gün ve saatte hatırlatma.
/// Yalnız cihazda tutulur. Android `features/dua/DuaJournalScreen.kt`.
struct DuaJournalView: View {
  @Environment(\.tokens) private var tokens
  @State private var draft: DuaJournalEntry?

  var body: some View {
    let store = DuaJournalStore.shared
    VStack(spacing: 0) {
      StandardHeader(title: t("duaJournal.title"))
      ScrollView {
        VStack(alignment: .leading, spacing: 10.5) {
          if store.entries.isEmpty {
            EmptyState(icon: "create-outline", scene: "quran", title: t("duaJournal.empty"), message: t("duaJournal.emptyBody")) {
              AppButton(title: t("duaJournal.add")) { Haptics.impact(.light); draft = DuaJournalEntry() }.fixedSize()
            }
          } else {
            AppButton(title: t("duaJournal.add")) { Haptics.impact(.light); draft = DuaJournalEntry() }
              .padding(.bottom, 3.5)
            ForEach(store.entries) { entry in
              Button {
                Haptics.impact(.light)
                draft = entry
              } label: {
                row(entry)
              }
              .buttonStyle(PressableStyle())
            }
          }
          HStack(alignment: .top, spacing: 7) {
            Ionicon("lock-closed-outline", size: 14, color: tokens.inkSubtle).padding(.top, 1)
            Text(t("duaJournal.private")).font(.system(size: 12)).foregroundStyle(tokens.textSecondary)
          }
          .padding(.top, 7)
        }
        .padding(16).padding(.bottom, 84)
      }
      .scrollIndicators(.hidden)
    }
    .background(tokens.canvas)
    .toolbar(.hidden, for: .navigationBar)
    .sheet(item: $draft) { d in
      DuaJournalForm(initial: d, isNew: !store.entries.contains { $0.id == d.id }) { saved in
        draft = nil
        Haptics.notify(.success)
        store.save(saved)
      } onDelete: { id in
        AppAlert.confirm(t("duaJournal.deleteConfirm"), t("duaJournal.deleteMessage"), confirmText: t("common.delete"), destructive: true) {
          draft = nil
          store.delete(id)
        }
      }
      .presentationDetents([.fraction(0.85), .large])
      .presentationDragIndicator(.visible)
      .presentationBackground(tokens.surface)
      .presentationCornerRadius(24)
      .environment(\.tokens, tokens)
    }
  }

  private func row(_ entry: DuaJournalEntry) -> some View {
    VStack(alignment: .leading, spacing: 5.25) {
      if !entry.title.isEmpty {
        Text(entry.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(tokens.textPrimary).lineLimit(1)
      }
      if !entry.text.isEmpty {
        Text(entry.text).font(.system(size: 14)).foregroundStyle(tokens.textSecondary).lineLimit(3).multilineTextAlignment(.leading)
      }
      if let r = entry.reminder {
        HStack(spacing: 5.25) {
          Ionicon("notifications-outline", size: 13, color: tokens.accent)
          Text(t("duaJournal.reminderSummary", ["days": AlarmText.repeatText(r.days), "time": String(format: "%02d:%02d", r.hour, r.minute)]))
            .font(.system(size: 12, weight: .medium)).foregroundStyle(tokens.accent).tabularNumbers()
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .background(tokens.surface, in: .rect(cornerRadius: 21))
    .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
  }
}

private struct DuaJournalForm: View {
  @Environment(\.tokens) private var tokens
  @State private var draft: DuaJournalEntry
  @State private var remind: Bool
  @State private var reminder: DuaJournalEntry.Reminder
  let isNew: Bool
  let onSave: (DuaJournalEntry) -> Void
  let onDelete: (String) -> Void

  init(initial: DuaJournalEntry, isNew: Bool, onSave: @escaping (DuaJournalEntry) -> Void, onDelete: @escaping (String) -> Void) {
    _draft = State(initialValue: initial)
    _remind = State(initialValue: initial.reminder != nil)
    _reminder = State(initialValue: initial.reminder ?? .init())
    self.isNew = isNew
    self.onSave = onSave
    self.onDelete = onDelete
  }

  private var canSave: Bool {
    !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        Text(t(isNew ? "duaJournal.add" : "duaJournal.edit")).font(.system(size: 17, weight: .semibold)).foregroundStyle(tokens.textPrimary)

        VStack(alignment: .leading, spacing: 0) {
          FieldLabel(t("duaJournal.titleLabel"))
          InputField(placeholder: t("duaJournal.titlePlaceholder"), text: $draft.title, maxLength: DuaJournalStore.titleLimit)
        }

        VStack(alignment: .leading, spacing: 0) {
          FieldLabel(t("duaJournal.textLabel"))
          TextField("", text: $draft.text, prompt: Text(t("duaJournal.textPlaceholder")).foregroundStyle(tokens.inkSubtle), axis: .vertical)
            .font(.system(size: 15))
            .lineLimit(5...12)
            .foregroundStyle(tokens.textPrimary)
            .tint(tokens.accent)
            .padding(12.25)
            .background(tokens.isDark ? Forest.s950 : Forest.s50, in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(tokens.line, lineWidth: 1))
            .onChange(of: draft.text) { _, v in if v.count > DuaJournalStore.textLimit { draft.text = String(v.prefix(DuaJournalStore.textLimit)) } }
        }

        HStack {
          VStack(alignment: .leading, spacing: 1.75) {
            Text(t("duaJournal.reminder")).font(.system(size: 15, weight: .medium)).foregroundStyle(tokens.textPrimary)
            Text(t("duaJournal.reminderHint")).font(.system(size: 13)).foregroundStyle(tokens.textSecondary)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          Toggle("", isOn: Binding(get: { remind }, set: { Haptics.impact(.medium); remind = $0 })).labelsHidden().tint(tokens.accent)
        }

        if remind {
          HStack(spacing: 14) {
            TimeStepper(value: $reminder.hour, max: 24, step: 1, up: t("alarm.custom.hourUp"), down: t("alarm.custom.hourDown"))
            Text(verbatim: ":").font(.system(size: 48, weight: .bold)).foregroundStyle(tokens.isDark ? Forest.s500 : Forest.s400)
            TimeStepper(value: $reminder.minute, max: 60, step: 5, up: t("alarm.custom.minuteUp"), down: t("alarm.custom.minuteDown"))
          }
          .frame(maxWidth: .infinity)
          .environment(\.layoutDirection, .leftToRight)

          VStack(alignment: .leading, spacing: 7) {
            FieldLabel(t("duaJournal.days"))
            FlowLayout(spacing: 7) {
              ForEach(AlarmText.weekOrder, id: \.self) { d in
                AlarmChip(label: AlarmText.shortWeekday(d), selected: reminder.days.contains(d)) {
                  // En az bir gün kalır.
                  if reminder.days.contains(d) { if reminder.days.count > 1 { reminder.days.removeAll { $0 == d } } } else { reminder.days.append(d) }
                }
              }
            }
            Text(AlarmText.repeatText(reminder.days)).font(.system(size: 13)).foregroundStyle(tokens.textSecondary)
          }
        }

        VStack(spacing: 10.5) {
          AppButton(title: t("common.save"), disabled: !canSave) {
            var value = draft
            value.reminder = remind ? reminder : nil
            onSave(value)
          }
          if !isNew {
            AppButton(title: t("common.delete"), variant: .danger) { onDelete(draft.id) }
          }
        }
      }
      .padding(.horizontal, 17.5)
      .padding(.top, 24)
      .padding(.bottom, 32)
    }
    .scrollDismissesKeyboard(.interactively)
  }
}
