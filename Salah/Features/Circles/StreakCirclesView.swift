import SwiftUI

/// Birlikte seri: gruplarım, grup kurma (tür seçerek) ve kodla katılma.
struct StreakCirclesView: View {
  private enum Entry: String, Identifiable {
    case create, join
    var id: String { rawValue }
  }

  @Environment(\.tokens) private var tokens
  @State private var circles: [StreakCircleAPI.Summary]?
  @State private var failed = false
  @State private var attempt = 0
  @State private var entry: Entry?

  var body: some View {
    let signedIn = AuthStore.shared.isAuthenticated
    VStack(spacing: 0) {
      StandardHeader(title: t("circles.title"))
      if !signedIn {
        Spacer()
        Text(t("circles.signIn")).font(.system(size: 15)).foregroundStyle(tokens.textSecondary).multilineTextAlignment(.center).padding(.horizontal, 24)
        AppButton(title: t("auth.login.submit")) { AuthFlow.shared.present() }.frame(width: 200).padding(.top, 16)
        Spacer()
      } else {
        ScrollView {
          VStack(alignment: .leading, spacing: 14) { content }
            .padding(14).padding(.bottom, 84)
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
      if signedIn, StreakCircleAPI.pendingCode != nil { entry = .join }
    }
    .sheet(item: $entry) { item in
      CircleEntrySheet(joining: item == .join) { detail in
        entry = nil
        open(detail.id)
      }
      .presentationDetents([.height(item == .join ? 270 : 470)])
      .presentationDragIndicator(.visible)
      .presentationBackground(tokens.surface)
      .presentationCornerRadius(24)
      .environment(\.tokens, tokens)
    }
  }

  @ViewBuilder
  private var content: some View {
    if let circles {
      if circles.isEmpty {
        Card {
          VStack(alignment: .leading, spacing: 14) {
            Text(t("circles.intro")).font(.system(size: 15)).lineSpacing(3).foregroundStyle(tokens.textPrimary)
            ForEach(Array(["circles.how1", "circles.how2", "circles.how3"].enumerated()), id: \.offset) { index, key in
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
      HStack(spacing: 10) {
        AppButton(title: t("circles.create")) { Haptics.impact(.light); entry = .create }
        AppButton(title: t("circles.join"), variant: .outline) { Haptics.impact(.light); entry = .join }
      }
      ForEach(circles) { circle in
        Button {
          Haptics.impact(.light)
          open(circle.id)
        } label: {
          HStack(spacing: 12) {
            VStack(spacing: 0) {
              Text("\(circle.sharedStreak)").font(.system(size: 22, weight: .bold)).foregroundStyle(tokens.isDark ? Gold.s300 : Gold.s700).tabularNumbers()
              Ionicon("flame", size: 13, color: tokens.gold)
            }
            .frame(width: 52, height: 52)
            .background(tokens.isDark ? Gold.s700.opacity(0.25) : Gold.s100, in: .circle)
            VStack(alignment: .leading, spacing: 2) {
              Text(t("circles.kind.\(circle.kind)")).font(.system(size: 16, weight: .semibold)).foregroundStyle(tokens.textPrimary)
              Text("\(t("circles.members", ["count": circle.memberCount]))  ·  \(t("circles.todayDone", ["done": circle.doneToday, "total": circle.memberCount]))")
                .font(.system(size: 13)).foregroundStyle(tokens.textSecondary).tabularNumbers().lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Ionicon(dirIcon("chevron-forward"), size: 16, color: tokens.inkSubtle)
          }
          .padding(14)
          .background(tokens.surface, in: .rect(cornerRadius: 21))
          .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
        }
        .buttonStyle(PressableStyle(pressedOpacity: 0.85))
        .accessibilityLabel("\(t("circles.kind.\(circle.kind)")), \(t("circles.shared")) \(t("circles.sharedDays", ["count": circle.sharedStreak]))")
      }
      Text(t("circles.privacy")).font(.system(size: 12)).foregroundStyle(tokens.textSecondary).padding(.horizontal, 4)
    } else if failed {
      VStack(spacing: 16) {
        Text(t("circles.failed")).font(.system(size: 15)).foregroundStyle(tokens.textSecondary).multilineTextAlignment(.center)
        AppButton(title: t("common.retry")) { attempt += 1 }.frame(width: 180)
      }
      .frame(maxWidth: .infinity).padding(.vertical, 24)
    } else {
      ProgressView().tint(tokens.accent).frame(maxWidth: .infinity).padding(30)
    }
  }

  private func open(_ id: String) {
    StreakCircleAPI.pendingCode = nil
    HomeNavigation.shared.path.append(.circle(id))
  }

  private func load() async {
    guard AuthStore.shared.isAuthenticated else { return }
    failed = false
    do {
      let list = try await StreakCircleAPI.list()
      if Task.isCancelled { return }
      circles = list
    } catch {
      // Ekran açılırken görev yeniden başlar; iptal edilen istek (URLError.cancelled) hata sayılmaz.
      if Task.isCancelled || error is CancellationError { return }
      failed = true
    }
  }
}

/// Grup kurma (tür seçimi) ya da kodla katılma.
private struct CircleEntrySheet: View {
  @Environment(\.tokens) private var tokens
  let joining: Bool
  let onDone: (StreakCircleAPI.Detail) -> Void
  @State private var text = ""
  @State private var kind = "family"
  @State private var busy = false
  @FocusState private var focused: Bool

  private var code: String { text.trimmingCharacters(in: .whitespaces) }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(t(joining ? "circles.joinTitle" : "circles.createTitle")).font(.system(size: 17, weight: .semibold)).foregroundStyle(tokens.textPrimary)
      Text(t(joining ? "circles.joinHint" : "circles.createHint")).font(.system(size: 14)).lineSpacing(3).foregroundStyle(tokens.textSecondary)
      if joining {
        TextField("", text: $text, prompt: Text(verbatim: "K7M2QPXA").foregroundStyle(tokens.inkSubtle))
          .font(.system(size: 24, weight: .semibold, design: .monospaced))
          .foregroundStyle(tokens.textPrimary).tint(tokens.accent)
          .multilineTextAlignment(.center)
          .textInputAutocapitalization(.characters).autocorrectionDisabled().keyboardType(.asciiCapable)
          .focused($focused)
          .frame(height: 58)
          .background(tokens.fill, in: .rect(cornerRadius: 14))
          .padding(.vertical, 8)
          .accessibilityLabel(t("circles.code"))
          .onChange(of: text) { _, next in
            let clean = String(next.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(8))
            if clean != next { text = clean }
          }
      } else {
        VStack(spacing: 7) {
          ForEach(StreakCircleAPI.kinds, id: \.self) { value in
            let selected = kind == value
            Button { Haptics.impact(.light); kind = value } label: {
              HStack {
                Text(t("circles.kind.\(value)")).font(.system(size: 15, weight: selected ? .semibold : .regular))
                  .foregroundStyle(selected ? tokens.accent : tokens.textPrimary)
                Spacer()
                if selected { Ionicon("checkmark", size: 18, color: tokens.accent) }
              }
              .padding(.horizontal, 14).frame(height: 46)
              .background(selected ? tokens.accentSoft : tokens.fill, in: .rect(cornerRadius: 14))
            }
            .buttonStyle(PressableStyle())
            .accessibilityAddTraits(selected ? .isSelected : [])
          }
        }
        .padding(.vertical, 8)
      }
      AppButton(title: t(joining ? "circles.join" : "circles.create"), loading: busy, disabled: joining && code.count != 8) { submit() }
      Spacer(minLength: 0)
    }
    .padding(20).padding(.top, 8)
    .onAppear {
      if joining {
        text = StreakCircleAPI.pendingCode ?? ""
        focused = true
      }
    }
  }

  private func submit() {
    guard !busy else { return }
    Haptics.impact(.medium)
    busy = true
    Task {
      defer { busy = false }
      do {
        let detail = joining ? try await StreakCircleAPI.join(code: code) : try await StreakCircleAPI.create(kind: kind)
        Haptics.notify(.success)
        onDone(detail)
      } catch {
        Haptics.notify(.error)
        Toast.error(t("common.error"), StreakCircleAPI.errorText(error))
      }
    }
  }
}

/// Grup ayrıntısı: ortak seri, bugün kim tamamladı, davet, üyeler.
struct StreakCircleView: View {
  private struct ShareItem: Identifiable {
    let text: String
    var id: String { text }
  }

  @Environment(\.tokens) private var tokens
  @Environment(\.dismiss) private var dismiss
  let id: String
  @State private var circle: StreakCircleAPI.Detail?
  @State private var failed = false
  @State private var attempt = 0
  @State private var share: ShareItem?

  var body: some View {
    VStack(spacing: 0) {
      StandardHeader(title: circle.map { t("circles.kind.\($0.kind)") } ?? t("circles.title"))
      if let circle {
        ScrollView {
          VStack(alignment: .leading, spacing: 14) {
            hero(circle)
            invite(circle)
            members(circle)
            actions(circle)
          }
          .padding(14).padding(.bottom, 84)
        }
        .scrollIndicators(.hidden)
        .refreshable { await load() }
      } else if failed {
        Spacer()
        VStack(spacing: 16) {
          Text(t("circles.failed")).font(.system(size: 15)).foregroundStyle(tokens.textSecondary).multilineTextAlignment(.center)
          AppButton(title: t("common.retry")) { attempt += 1 }.frame(width: 180)
        }
        Spacer()
      } else {
        ProgressView().tint(tokens.accent).frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .background(tokens.canvas)
    .toolbar(.hidden, for: .navigationBar)
    .task(id: attempt) { await load() }
    .sheet(item: $share) { item in ShareSheet(items: [item.text]).presentationDetents([.medium, .large]) }
  }

  private func hero(_ circle: StreakCircleAPI.Detail) -> some View {
    let done = circle.members.filter { $0.today >= 5 }.count
    return VStack(alignment: .leading, spacing: 3.5) {
      Text(t("circles.shared")).font(.system(size: 13, weight: .medium)).foregroundStyle(Gold.s300)
      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Text("\(circle.sharedStreak)").font(.system(size: 40, weight: .bold)).foregroundStyle(.white).tabularNumbers()
        Text(t("circles.days")).font(.system(size: 17)).foregroundStyle(.white.opacity(0.85))
        Spacer()
        Ionicon("flame", size: 30, color: Gold.s300)
      }
      Text(done == circle.members.count ? t("circles.todayAll") : t("circles.todayDone", ["done": done, "total": circle.members.count]))
        .font(.system(size: 14)).foregroundStyle(.white.opacity(0.85)).tabularNumbers()
      HStack(spacing: 4) {
        ForEach(circle.members) { m in
          Capsule().fill(m.today >= 5 ? Gold.s300 : .white.opacity(0.2)).frame(height: 6)
        }
      }
      .padding(.top, 10)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(17.5)
    .background(Accent.s800, in: .rect(cornerRadius: 24))
    .accessibilityElement(children: .combine)
  }

  private func invite(_ circle: StreakCircleAPI.Detail) -> some View {
    let alone = circle.members.count == 1
    return Card {
      VStack(alignment: .leading, spacing: 10) {
        Text(t(alone ? "circles.inviteAlone" : "circles.inviteTitle"))
          .font(.system(size: alone ? 15 : 13, weight: alone ? .regular : .semibold))
          .foregroundStyle(alone ? tokens.textPrimary : tokens.textSecondary)
        HStack(spacing: 8) {
          Text(circle.inviteCode)
            .font(.system(size: 20, weight: .semibold, design: .monospaced)).foregroundStyle(tokens.textPrimary)
            .lineLimit(1).minimumScaleFactor(0.7).textSelection(.enabled)
          Spacer(minLength: 4)
          Button {
            Haptics.notify(.success)
            UIPasteboard.general.string = circle.inviteCode
            Toast.success(t("circles.copied"))
          } label: {
            Ionicon("copy-outline", size: 19, color: tokens.accent).frame(width: 44, height: 44).background(tokens.fill, in: .circle)
          }
          .buttonStyle(PressableStyle())
          .accessibilityLabel(t("circles.copy"))
          Button {
            Haptics.impact(.light)
            share = ShareItem(text: t("circles.inviteText", ["code": circle.inviteCode]))
          } label: {
            Text(t("circles.invite")).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
              .padding(.horizontal, 16).frame(height: 44)
              .background(tokens.isDark ? Accent.s500 : Accent.s600, in: .capsule)
          }
          .buttonStyle(PressableStyle())
        }
      }
    }
  }

  private func members(_ circle: StreakCircleAPI.Detail) -> some View {
    Card {
      Text(t("circles.membersTitle")).font(.system(size: 17, weight: .semibold)).foregroundStyle(tokens.textPrimary).padding(.bottom, 6)
      ForEach(circle.members) { member in
        let name = member.isMe ? t("circles.you") : (member.name ?? "?")
        HStack(spacing: 10) {
          Text(initials(member.name ?? "?"))
            .font(.system(size: 13, weight: .semibold)).foregroundStyle(tokens.accent)
            .frame(width: 36, height: 36).background(tokens.accentSoft, in: .circle)
          VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
              Text(name).font(.system(size: 15)).foregroundStyle(tokens.textPrimary).lineLimit(1)
              if member.isOwner { Text(t("circles.owner")).font(.system(size: 12)).foregroundStyle(tokens.textSecondary) }
            }
            HStack(spacing: 3) {
              ForEach(0..<5, id: \.self) { i in
                Circle().fill(i < member.today ? tokens.accent : tokens.fill).frame(width: 7, height: 7)
              }
              Text(t("circles.memberStreak", ["count": member.streak])).font(.system(size: 12)).foregroundStyle(tokens.textSecondary).tabularNumbers().padding(.leading, 6)
            }
          }
          Spacer(minLength: 6)
          if circle.isOwner, !member.isMe {
            Button {
              Haptics.impact(.light)
              AppAlert.confirm(t("circles.remove"), t("circles.removeConfirm", ["name": name]), destructive: true) {
                do { try await StreakCircleAPI.removeMember(id, userId: member.id) } catch { Toast.error(t("common.error"), t("circles.failed")) }
                attempt += 1
              }
            } label: {
              Ionicon("close", size: 18, color: tokens.inkSubtle).frame(width: 44, height: 44)
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel(t("circles.remove"))
          }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(t("circles.memberToday", ["count": member.today])), \(t("circles.memberStreak", ["count": member.streak]))")
      }
    }
  }

  private func actions(_ circle: StreakCircleAPI.Detail) -> some View {
    VStack(spacing: 2) {
      quiet("circles.leave", color: tokens.textSecondary) {
        AppAlert.confirm(t("circles.leave"), t("circles.leaveConfirm"), destructive: true) {
          do {
            try await StreakCircleAPI.removeMember(id, userId: "me")
            dismiss()
          } catch { Toast.error(t("common.error"), t("circles.failed")) }
        }
      }
      if circle.isOwner {
        quiet("circles.delete", color: tokens.danger) {
          AppAlert.confirm(t("circles.delete"), t("circles.deleteConfirm"), destructive: true) {
            do {
              try await StreakCircleAPI.delete(id)
              dismiss()
            } catch { Toast.error(t("common.error"), t("circles.failed")) }
          }
        }
      }
      Text(t("circles.privacy")).font(.system(size: 12)).foregroundStyle(tokens.textSecondary).multilineTextAlignment(.center).padding(.top, 8)
    }
    .frame(maxWidth: .infinity)
  }

  private func quiet(_ key: String, color: Color, action: @escaping () -> Void) -> some View {
    Button { Haptics.impact(.light); action() } label: {
      Text(t(key)).font(.system(size: 15, weight: .medium)).foregroundStyle(color).frame(minHeight: 44)
    }
    .buttonStyle(PressableStyle())
  }

  private func initials(_ name: String) -> String {
    String(name.split(separator: " ").prefix(2).compactMap(\.first)).uppercased()
  }

  private func load() async {
    failed = false
    do {
      let detail = try await StreakCircleAPI.detail(id)
      if Task.isCancelled { return }
      circle = detail
    } catch {
      if Task.isCancelled || error is CancellationError { return }
      failed = true
    }
  }
}
