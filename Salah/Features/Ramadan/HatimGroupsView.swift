import SwiftUI

/// Gruplarım. Grup kurma ve kodla katılma ayrı alt sayfalarda açılır.
struct HatimGroupsView: View {
  private enum Entry: String, Identifiable {
    case create, join
    var id: String { rawValue }
  }

  @Environment(\.tokens) private var tokens
  @State private var groups: [HatimGroupAPI.Summary]?
  @State private var failed = false
  @State private var attempt = 0
  @State private var entry: Entry?

  var body: some View {
    let signedIn = AuthStore.shared.isAuthenticated
    VStack(spacing: 0) {
      StandardHeader(title: t("hatimGroups.title"))
      if !signedIn {
        Spacer()
        Text(t("hatimGroups.signIn")).font(.system(size: 15)).foregroundStyle(tokens.textSecondary).multilineTextAlignment(.center).padding(.horizontal, 24)
        AppButton(title: t("auth.login.submit")) { AuthFlow.shared.present() }.frame(width: 200).padding(.top, 16)
        Spacer()
      } else {
        ScrollView {
          VStack(alignment: .leading, spacing: 14) {
            content
          }
          .padding(14)
          .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .refreshable { await load() }
      }
    }
    .background(tokens.canvas)
    .toolbar(.hidden, for: .navigationBar)
    .task(id: "\(attempt)|\(signedIn)") { await load() }
    .onAppear {
      attempt += 1
      if signedIn, HatimGroupAPI.pendingCode != nil { entry = .join }
      if DebugLaunch.sheet == "join" { entry = .join } else if DebugLaunch.sheet == "create" { entry = .create }
    }
    .sheet(item: $entry) { item in
      GroupEntrySheet(joining: item == .join) { detail in
        entry = nil
        open(detail.id)
      }
      .presentationDetents([.height(item == .join ? 250 : 270)])
      .presentationDragIndicator(.visible)
      .presentationBackground(tokens.surface)
      .presentationCornerRadius(24)
      .environment(\.tokens, tokens)
    }
  }

  @ViewBuilder
  private var content: some View {
    if let groups {
      if groups.isEmpty {
        Card {
          VStack(alignment: .leading, spacing: 14) {
            Text(t("hatimGroups.emptyTitle")).font(.system(size: 17, weight: .semibold)).foregroundStyle(tokens.textPrimary)
            ForEach(Array(["hatimGroups.how1", "hatimGroups.how2", "hatimGroups.how3"].enumerated()), id: \.offset) { index, key in
              HStack(alignment: .top, spacing: 12) {
                Text(verbatim: "\(index + 1)")
                  .font(.system(size: 13, weight: .semibold)).foregroundStyle(tokens.accent).tabularNumbers()
                  .frame(width: 26, height: 26).background(tokens.accentSoft, in: .circle)
                Text(t(key)).font(.system(size: 15)).foregroundStyle(tokens.textPrimary).frame(maxWidth: .infinity, minHeight: 26, alignment: .leading)
              }
            }
          }
        }
      }
      actions
      ForEach(groups) { group in
        Button {
          Haptics.impact(.light)
          open(group.id)
        } label: {
          Card {
            HStack {
              VStack(alignment: .leading, spacing: 2) {
                Text(group.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(tokens.textPrimary).lineLimit(1)
                Text("\(t("hatimGroups.members", ["count": group.memberCount]))  ·  \(t("hatimGroups.progress", ["done": group.doneCount]))")
                  .font(.system(size: 13)).foregroundStyle(tokens.textSecondary).tabularNumbers()
              }
              Spacer(minLength: 0)
              Ionicon(dirIcon("chevron-forward"), size: 16, color: tokens.inkSubtle)
            }
            ProgressBar(fraction: Double(group.doneCount) / 30, height: 6, fill: tokens.accent).frame(height: 6).padding(.top, 10)
          }
        }
        .buttonStyle(PressableStyle(pressedOpacity: 0.85))
      }
    } else if failed {
      VStack(spacing: 16) {
        Text(t("hatimGroups.failed")).font(.system(size: 15)).foregroundStyle(tokens.textSecondary).multilineTextAlignment(.center)
        AppButton(title: t("common.retry")) { attempt += 1 }.frame(width: 180)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 24)
    } else {
      ProgressView().tint(tokens.accent).frame(maxWidth: .infinity).padding(30)
    }
  }

  private var actions: some View {
    HStack(spacing: 10) {
      AppButton(title: t("hatimGroups.create")) {
        Haptics.impact(.light)
        entry = .create
      }
      AppButton(title: t("hatimGroups.join"), variant: .outline) {
        Haptics.impact(.light)
        entry = .join
      }
    }
  }

  private func open(_ id: String) {
    HatimGroupAPI.pendingCode = nil
    HomeNavigation.shared.path.append(.hatimGroup(id))
  }

  private func load() async {
    guard AuthStore.shared.isAuthenticated else { return }
    failed = false
    do { groups = try await HatimGroupAPI.list() } catch { if !(error is CancellationError) { failed = true } }
  }
}

/// Tek alanlı alt sayfa: grup adı ya da davet kodu.
private struct GroupEntrySheet: View {
  @Environment(\.tokens) private var tokens
  let joining: Bool
  let onDone: (HatimGroupAPI.Detail) -> Void
  @State private var text = ""
  @State private var busy = false
  @FocusState private var focused: Bool

  private var value: String { text.trimmingCharacters(in: .whitespaces) }
  private var valid: Bool { joining ? value.count >= 6 : !value.isEmpty }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(t(joining ? "hatimGroups.joinTitle" : "hatimGroups.createTitle")).font(.system(size: 17, weight: .semibold)).foregroundStyle(tokens.textPrimary)
      Text(t(joining ? "hatimGroups.joinHint" : "hatimGroups.createHint")).font(.system(size: 14)).lineSpacing(3).foregroundStyle(tokens.textSecondary)
      if joining {
        TextField("", text: $text, prompt: Text(verbatim: "K7M2QPXA").foregroundStyle(tokens.inkSubtle))
          .font(.system(size: 24, weight: .semibold, design: .monospaced))
          .foregroundStyle(tokens.textPrimary)
          .tint(tokens.accent)
          .multilineTextAlignment(.center)
          .textInputAutocapitalization(.characters)
          .autocorrectionDisabled()
          .keyboardType(.asciiCapable)
          .focused($focused)
          .frame(height: 58)
          .background(tokens.fill, in: .rect(cornerRadius: 14))
          .padding(.vertical, 8)
          .accessibilityLabel(t("hatimGroups.code"))
          .onChange(of: text) { _, next in
            let clean = String(next.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(10))
            if clean != next { text = clean }
          }
      } else {
        InputField(placeholder: t("hatimGroups.namePlaceholder"), text: $text, maxLength: 40, prominent: true)
          .focused($focused)
          .padding(.top, 8)
      }
      AppButton(title: t(joining ? "hatimGroups.join" : "hatimGroups.create"), loading: busy, disabled: !valid) { submit() }
      Spacer(minLength: 0)
    }
    .padding(20)
    .padding(.top, 8)
    .onAppear {
      if joining { text = HatimGroupAPI.pendingCode ?? "" }
      focused = true
    }
  }

  private func submit() {
    guard valid, !busy else { return }
    Haptics.impact(.medium)
    busy = true
    Task {
      defer { busy = false }
      do {
        let detail = joining ? try await HatimGroupAPI.join(code: value) : try await HatimGroupAPI.create(name: value)
        Haptics.notify(.success)
        onDone(detail)
      } catch {
        Haptics.notify(.error)
        Toast.error(t("common.error"), HatimGroupAPI.errorText(error))
      }
    }
  }
}

/// Grup ayrıntısı: durum, senin cüzlerin, 30 cüz ızgarası, davet ve üyeler.
struct HatimGroupView: View {
  private struct Selection: Identifiable { let id: Int }
  private struct MushafPage: Identifiable { let id: Int }
  private struct ShareItem: Identifiable {
    let text: String
    var id: String { text }
  }

  @Environment(\.tokens) private var tokens
  @Environment(\.dismiss) private var dismiss
  let id: String
  @State private var group: HatimGroupAPI.Detail?
  @State private var failed = false
  @State private var attempt = 0
  @State private var shareText: String?
  @State private var selected: Selection?
  @State private var mushaf: MushafPage?
  @State private var acting = false

  var body: some View {
    VStack(spacing: 0) {
      StandardHeader(title: group?.name ?? t("hatimGroups.title"))
      if let group {
        detail(group)
      } else if failed {
        Spacer()
        Text(t("hatimGroups.failed")).font(.system(size: 15)).foregroundStyle(tokens.textSecondary).multilineTextAlignment(.center).padding(.horizontal, 24)
        AppButton(title: t("common.retry")) { attempt += 1 }.frame(width: 180).padding(.top, 16)
        Spacer()
      } else {
        Spacer()
        ProgressView().tint(tokens.accent)
        Spacer()
      }
    }
    .background(tokens.canvas)
    .toolbar(.hidden, for: .navigationBar)
    .task(id: attempt) {
      await load()
      if DebugLaunch.sheet == "free" { selected = Selection(id: 20) } else if DebugLaunch.sheet == "mine" { selected = Selection(id: 12) }
    }
    .sheet(item: Binding(get: { shareText.map(ShareItem.init) }, set: { shareText = $0?.text })) { item in
      ShareSheet(items: [item.text]).presentationDetents([.medium, .large])
    }
    .sheet(item: $selected) { item in
      juzSheet(item.id)
        .presentationDetents([.height(255)])
        .presentationDragIndicator(.visible)
        .presentationBackground(tokens.surface)
        .presentationCornerRadius(24)
        .environment(\.tokens, tokens)
    }
    .fullScreenCover(item: $mushaf) { page in
      MushafReaderView(initialPage: page.id).environment(\.tokens, tokens)
    }
  }

  private func detail(_ group: HatimGroupAPI.Detail) -> some View {
    let alone = group.members.count <= 1
    return ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        hero(group)
        myCard(group)
        if alone { invite(group, alone: true) }
        gridCard(group)
        if !alone { invite(group, alone: false) }
        membersCard(group)
        groupActions(group)
      }
      .padding(14)
      .padding(.bottom, 24)
    }
    .scrollIndicators(.hidden)
    .refreshable { await load() }
  }

  private func hero(_ group: HatimGroupAPI.Detail) -> some View {
    let done = group.juz.filter(\.done).count
    let reading = group.juz.count - done
    return VStack(alignment: .leading, spacing: 4) {
      Text(t("hatimGroups.heroRead", ["done": done])).font(.system(size: 22, weight: .semibold)).foregroundStyle(.white).tabularNumbers()
      Text(t("hatimGroups.heroState", ["reading": reading, "free": 30 - group.juz.count])).font(.system(size: 13)).foregroundStyle(.white.opacity(0.85)).tabularNumbers()
      GeometryReader { geo in
        ZStack(alignment: .leading) {
          Capsule().fill(.white.opacity(0.2))
          Capsule().fill(Gold.s300).frame(width: geo.size.width * Double(done) / 30)
        }
      }
      .frame(height: 6)
      .padding(.top, 10)
      if group.completed > 0 {
        Text(t("hatimGroups.completed", ["count": group.completed])).font(.system(size: 13, weight: .medium)).foregroundStyle(Gold.s300).padding(.top, 8)
      }
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Accent.s800, in: .rect(cornerRadius: 21))
  }

  private func myCard(_ group: HatimGroupAPI.Detail) -> some View {
    let mine = group.juz.filter { $0.isMine && !$0.done }
    let next = (1...30).first { number in !group.juz.contains { $0.juz == number } }
    return Card {
      VStack(alignment: .leading, spacing: 10) {
        Text(t("hatimGroups.myTitle")).font(.system(size: 17, weight: .semibold)).foregroundStyle(tokens.textPrimary)
        if mine.isEmpty {
          Text(t(next == nil ? "hatimGroups.allTaken" : "hatimGroups.noneMine")).font(.system(size: 14)).foregroundStyle(tokens.textSecondary)
        }
        ForEach(mine, id: \.juz) { entry in
          let pages = HatimGroupAPI.pages(ofJuz: entry.juz)
          HStack(spacing: 8) {
            Button {
              Haptics.impact(.light)
              selected = Selection(id: entry.juz)
            } label: {
              VStack(alignment: .leading, spacing: 1) {
                Text(t("hatimGroups.juzTitle", ["juz": entry.juz])).font(.system(size: 15, weight: .semibold)).foregroundStyle(tokens.textPrimary).tabularNumbers()
                Text(t("hatimGroups.pages", ["from": pages.lowerBound, "to": pages.upperBound])).font(.system(size: 13)).foregroundStyle(tokens.textSecondary).tabularNumbers()
              }
              .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
              .contentShape(.rect)
            }
            .buttonStyle(PressableStyle())
            pill("hatimGroups.readNow", filled: false) {
              Haptics.impact(.light)
              mushaf = MushafPage(id: pages.lowerBound)
            }
            pill("hatimGroups.done", filled: true) {
              Task { await act(entry.juz, "done") }
            }
          }
        }
        if let next {
          AppButton(title: t("hatimGroups.takeNext", ["juz": next]), variant: mine.isEmpty ? .primary : .outline, loading: acting) {
            Haptics.impact(.medium)
            Task { await act(next, "take") }
          }
        }
      }
    }
  }

  private func pill(_ key: String, filled: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(t(key))
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(filled ? tokens.surface : tokens.accent)
        .lineLimit(1)
        .padding(.horizontal, 14)
        .frame(minHeight: 40)
        .background(filled ? tokens.accent : tokens.accentSoft, in: .capsule)
    }
    .buttonStyle(PressableStyle())
    .disabled(acting)
  }

  private func gridCard(_ group: HatimGroupAPI.Detail) -> some View {
    Card {
      Text(t("hatimGroups.gridTitle")).font(.system(size: 17, weight: .semibold)).foregroundStyle(tokens.textPrimary).padding(.bottom, 12)
      LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 5), spacing: 7) {
        ForEach(1...30, id: \.self) { cell($0, group) }
      }
      LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], alignment: .leading, spacing: 6) {
        legend(tokens.accent, nil, "hatimGroups.mine")
        legend(tokens.fill, nil, "hatimGroups.others")
        legend(Gold.s300, nil, "hatimGroups.read")
        legend(tokens.surface, tokens.line, "hatimGroups.free")
      }
      .padding(.top, 12)
    }
  }

  private func invite(_ group: HatimGroupAPI.Detail, alone: Bool) -> some View {
    Card {
      VStack(alignment: .leading, spacing: 10) {
        Text(t(alone ? "hatimGroups.inviteAlone" : "hatimGroups.inviteTitle")).font(.system(size: alone ? 15 : 13, weight: alone ? .regular : .semibold)).foregroundStyle(alone ? tokens.textPrimary : tokens.textSecondary)
        HStack(spacing: 8) {
          Text(group.inviteCode)
            .font(.system(size: 20, weight: .semibold, design: .monospaced))
            .foregroundStyle(tokens.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .textSelection(.enabled)
          Spacer(minLength: 4)
          Button {
            Haptics.notify(.success)
            UIPasteboard.general.string = group.inviteCode
            Toast.success(t("hatimGroups.copied"))
          } label: {
            Ionicon("copy-outline", size: 19, color: tokens.accent).frame(width: 44, height: 44).background(tokens.fill, in: .circle)
          }
          .buttonStyle(PressableStyle())
          .accessibilityLabel(t("hatimGroups.copy"))
          pill("hatimGroups.invite", filled: true) {
            Haptics.impact(.light)
            shareText = t("hatimGroups.inviteText", ["name": group.name, "code": group.inviteCode])
          }
        }
      }
    }
  }

  private func membersCard(_ group: HatimGroupAPI.Detail) -> some View {
    Card {
      Text(t("hatimGroups.membersTitle")).font(.system(size: 17, weight: .semibold)).foregroundStyle(tokens.textPrimary).padding(.bottom, 6)
      ForEach(group.members) { member in
        let entries = group.juz.filter { $0.userId == member.id }
        let read = entries.filter(\.done).count
        HStack(spacing: 10) {
          Text(initials(member.name))
            .font(.system(size: 13, weight: .semibold)).foregroundStyle(tokens.accent)
            .frame(width: 36, height: 36).background(tokens.accentSoft, in: .circle)
          VStack(alignment: .leading, spacing: 1) {
            Text(member.name).font(.system(size: 15)).foregroundStyle(tokens.textPrimary).lineLimit(1)
            Text(entries.isEmpty ? t("hatimGroups.memberIdle") : t("hatimGroups.memberStats", ["read": read, "reading": entries.count - read]))
              .font(.system(size: 13)).foregroundStyle(tokens.textSecondary).tabularNumbers().lineLimit(1)
          }
          Spacer(minLength: 6)
          if member.id == group.ownerId {
            Text(t("hatimGroups.owner")).font(.system(size: 13)).foregroundStyle(tokens.textSecondary)
          } else if group.isOwner, !member.isMe {
            Button {
              Haptics.impact(.light)
              AppAlert.confirm(t("hatimGroups.remove"), t("hatimGroups.removeConfirm", ["name": member.name]), destructive: true) {
                do { try await HatimGroupAPI.removeMember(id, userId: member.id) } catch { Toast.error(t("common.error"), t("hatimGroups.failed")) }
                attempt += 1
              }
            } label: {
              Ionicon("close", size: 18, color: tokens.inkSubtle).frame(width: 44, height: 44)
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel(t("hatimGroups.remove"))
          }
        }
        .padding(.vertical, 6)
      }
    }
  }

  private func groupActions(_ group: HatimGroupAPI.Detail) -> some View {
    VStack(spacing: 2) {
      quietButton("hatimGroups.leave", color: tokens.textSecondary) {
        AppAlert.confirm(t("hatimGroups.leave"), t("hatimGroups.leaveConfirm"), destructive: true) {
          do {
            try await HatimGroupAPI.removeMember(id, userId: "me")
            dismiss()
          } catch { Toast.error(t("common.error"), t("hatimGroups.failed")) }
        }
      }
      if !group.isOwner {
        quietButton("hatimGroups.report", color: tokens.textSecondary) { report() }
      }
      if group.isOwner {
        quietButton("hatimGroups.delete", color: tokens.isDark ? Color(hex: 0xf87171) : Color(hex: 0xdc2626)) {
          AppAlert.confirm(t("hatimGroups.delete"), t("hatimGroups.deleteConfirm"), destructive: true) {
            do {
              try await HatimGroupAPI.delete(id)
              dismiss()
            } catch { Toast.error(t("common.error"), t("hatimGroups.failed")) }
          }
        }
      }
    }
    .frame(maxWidth: .infinity)
  }

  private func report() {
    let send: (String) async -> Void = { reason in
      do {
        try await HatimGroupAPI.report(id, reason: reason)
        Haptics.notify(.success)
        Toast.success(t("hatimGroups.reportSent"))
      } catch {
        Haptics.notify(.error)
        Toast.error(t("common.error"), t("hatimGroups.failed"))
      }
    }
    AppAlert.show(.confirm, t("hatimGroups.reportTitle"), nil, buttons: [
      .init(text: t("hatimGroups.reportName")) { await send("name") },
      .init(text: t("hatimGroups.reportMember")) { await send("member") },
      .init(text: t("hatimGroups.reportOther")) { await send("other") },
      .init(text: t("common.cancel"), style: .cancel),
    ])
  }

  private func quietButton(_ key: String, color: Color, action: @escaping () -> Void) -> some View {
    Button {
      Haptics.impact(.light)
      action()
    } label: {
      Text(t(key)).font(.system(size: 15, weight: .medium)).foregroundStyle(color).frame(maxWidth: .infinity, minHeight: 44)
    }
    .buttonStyle(PressableStyle())
  }

  private func initials(_ name: String) -> String {
    name.split(separator: " ").prefix(2).compactMap { $0.first.map(String.init) }.joined()
  }

  private func cell(_ number: Int, _ group: HatimGroupAPI.Detail) -> some View {
    let entry = group.juz.first { $0.juz == number }
    let mine = entry?.isMine == true
    let done = entry?.done == true
    let background: Color = done ? Gold.s300 : mine ? tokens.accent : entry != nil ? tokens.fill : tokens.surface
    let ink: Color = done ? Accent.s900 : mine ? tokens.surface : entry != nil ? tokens.textPrimary : tokens.textSecondary
    return Button {
      Haptics.impact(.light)
      selected = Selection(id: number)
    } label: {
      // Kare hücre metinden değil genişlikten ölçülür.
      RoundedRectangle(cornerRadius: 12).fill(background)
        .aspectRatio(1, contentMode: .fit)
        .overlay {
          if entry == nil { RoundedRectangle(cornerRadius: 12).stroke(tokens.line, lineWidth: 1) }
        }
        .overlay {
          VStack(spacing: 0) {
            Text(verbatim: "\(number)").font(.system(size: 16, weight: .semibold)).foregroundStyle(ink).tabularNumbers().lineLimit(1).fixedSize()
            if done {
              Ionicon("checkmark", size: 12, color: ink)
            } else if let entry, !mine {
              Text(initials(entry.name)).font(.system(size: 10, weight: .medium)).foregroundStyle(tokens.textSecondary).lineLimit(1)
            }
          }
        }
    }
    .buttonStyle(PressableStyle())
    .accessibilityLabel(t("hatimGroups.juzTitle", ["juz": number]))
    .accessibilityValue(status(number, entry))
  }

  private func status(_ number: Int, _ entry: HatimGroupAPI.Juz?) -> String {
    guard let entry else { return t("hatimGroups.freeStatus") }
    if entry.isMine { return t(entry.done ? "hatimGroups.mineDoneStatus" : "hatimGroups.mineStatus") }
    return t(entry.done ? "hatimGroups.doneBy" : "hatimGroups.takenBy", ["name": entry.name])
  }

  @ViewBuilder
  private func juzSheet(_ number: Int) -> some View {
    let entry = group?.juz.first { $0.juz == number }
    let pages = HatimGroupAPI.pages(ofJuz: number)
    VStack(alignment: .leading, spacing: 4) {
      Text(t("hatimGroups.juzTitle", ["juz": number])).font(.system(size: 22, weight: .bold)).foregroundStyle(tokens.textPrimary).tabularNumbers()
      Text(t("hatimGroups.pages", ["from": pages.lowerBound, "to": pages.upperBound])).font(.system(size: 14)).foregroundStyle(tokens.textSecondary).tabularNumbers()
      Text(status(number, entry)).font(.system(size: 15, weight: .medium)).foregroundStyle(tokens.textPrimary).padding(.top, 8).padding(.bottom, 12)
      VStack(spacing: 8) {
        if entry == nil {
          AppButton(title: t("hatimGroups.take")) { perform(number, "take") }
        } else if entry?.isMine == true, entry?.done == false {
          AppButton(title: t("hatimGroups.done")) { perform(number, "done") }
          HStack(spacing: 8) {
            AppButton(title: t("hatimGroups.readNow"), variant: .outline) { openMushaf(pages.lowerBound) }
            AppButton(title: t("hatimGroups.release"), variant: .outline) { perform(number, "release") }
          }
        } else if entry?.isMine == true {
          AppButton(title: t("hatimGroups.undone"), variant: .outline) { perform(number, "undone") }
        } else {
          AppButton(title: t("hatimGroups.readNow"), variant: .outline) { openMushaf(pages.lowerBound) }
        }
      }
      Spacer(minLength: 0)
    }
    .padding(20)
    .padding(.top, 8)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func openMushaf(_ page: Int) {
    Haptics.impact(.light)
    selected = nil
    Task {
      // Alt sayfa kapanmadan tam ekran açılmaz.
      try? await Task.sleep(for: .milliseconds(350))
      mushaf = MushafPage(id: page)
    }
  }

  private func perform(_ number: Int, _ action: String) {
    Haptics.impact(.medium)
    selected = nil
    Task { await act(number, action) }
  }

  private func act(_ number: Int, _ action: String) async {
    guard !acting else { return }
    acting = true
    defer { acting = false }
    do {
      let before = group?.completed ?? 0
      let next = try await HatimGroupAPI.juz(id, number, action: action)
      group = next
      Haptics.notify(.success)
      if next.completed > before { Toast.success(t("hatimGroups.completed", ["count": next.completed])) }
    } catch {
      Haptics.notify(.error)
      Toast.error(t("common.error"), HatimGroupAPI.errorText(error))
      attempt += 1
    }
  }

  private func legend(_ color: Color, _ stroke: Color?, _ key: String) -> some View {
    HStack(spacing: 6) {
      RoundedRectangle(cornerRadius: 4).fill(color).frame(width: 14, height: 14)
        .overlay { if let stroke { RoundedRectangle(cornerRadius: 4).stroke(stroke, lineWidth: 1) } }
      Text(t(key)).font(.system(size: 13)).foregroundStyle(tokens.textSecondary).lineLimit(1)
    }
  }

  private func load() async {
    failed = false
    do { group = try await HatimGroupAPI.detail(id) } catch { if !(error is CancellationError) { failed = true } }
  }
}
