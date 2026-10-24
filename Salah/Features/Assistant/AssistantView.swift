import SwiftUI

/// Yapay zekâ asistanı (Sor sekmesi). RN: screens/user/AssistantScreen.tsx
/// Sohbet yalnız bellekte tutulur (RN ile aynı); yanıt arayüz dilinde istenir.
@Observable
final class AssistantModel {
  struct Message: Identifiable, Equatable {
    enum Role: String { case user, model }
    let id = UUID()
    let role: Role
    let text: String
  }

  private(set) var messages: [Message] = AssistantModel.debugMessages
  private(set) var loading = false

  /// Yalnız Debug önizlemesi: `-SalahDebugAssistant chat` örnek sohbet gösterir.
  private static var debugMessages: [Message] {
    #if DEBUG
      guard UserDefaults.standard.string(forKey: "SalahDebugAssistant") == "chat" else { return [] }
      return [
        Message(role: .user, text: t("assistant.suggest.wudu")),
        Message(role: .model, text: "## Abdest\n1. **Niyet:** Kalben niyet edilir.\n2. **Eller:** Bileklere kadar üç kez yıkanır.\n- *Not:* Sıraya dikkat edilir."),
      ]
    #else
      return []
    #endif
  }

  func send(_ text: String) async {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, !loading else { return }
    Haptics.impact(.light)
    messages.append(Message(role: .user, text: trimmed))
    loading = true
    defer { loading = false }

    struct Response: Decodable {
      struct Payload: Decodable { let reply: String? }
      let data: Payload?
    }
    let history = messages.map { JSONValue.object(["role": .string($0.role.rawValue), "text": .string($0.text)]) }
    do {
      let res = try await APIClient.shared.post(
        "/assistant/chat",
        body: ["messages": .array(history), "language": .string(Localizer.shared.language.rawValue)],
        as: Response.self)
      messages.append(Message(role: .model, text: res.data?.reply ?? t("assistant.fallbackReply")))
    } catch {
      let unavailable = (error as? APIError)?.status == 503
      messages.append(Message(role: .model, text: t(unavailable ? "assistant.unavailable" : "assistant.error")))
    }
  }

  func clear() { messages = [] }
}

struct AssistantView: View {
  @Environment(\.tokens) private var tokens
  @State private var model = AssistantModel()
  @State private var input = ""
  @FocusState private var focused: Bool

  private static let suggestions: [(icon: String, key: String)] = [
    ("water-outline", "assistant.suggest.wudu"),
    ("book-outline", "assistant.suggest.prayerDuas"),
    ("airplane-outline", "assistant.suggest.travel"),
    ("time-outline", "assistant.suggest.qada"),
  ]

  var body: some View {
    let dark = tokens.isDark
    VStack(spacing: 0) {
      StandardHeader(title: t("assistant.title"), showBackButton: false) {
        if !model.messages.isEmpty {
          Button {
            Haptics.impact(.medium)
            AppAlert.confirm(
              t("assistant.clearTitle"), t("assistant.clearConfirm"),
              confirmText: t("assistant.clearConfirmButton"), cancelText: t("common.cancel"), destructive: true
            ) { model.clear() }
          } label: {
            Ionicon("trash-outline", size: 18, color: dark ? Forest.s400 : Forest.s500)
              .frame(width: 31.5, height: 31.5)
              .background(tokens.fill, in: .circle)
          }
          .buttonStyle(PressableStyle())
          .accessibilityLabel(t("assistant.clear"))
        }
      }

      ScrollViewReader { proxy in
        ScrollView {
          VStack(spacing: 14) {
            if model.messages.isEmpty {
              intro
            } else {
              ForEach(model.messages) { message in
                bubble(message).transition(.opacity.combined(with: .move(edge: .bottom)))
              }
            }
            if model.loading { typing.transition(.opacity) }
            Color.clear.frame(height: 1).id("bottom")
          }
          .padding(16)
          .padding(.bottom, 8)
          .animation(.easeOut(duration: 0.22), value: model.messages)
          .animation(.easeOut(duration: 0.2), value: model.loading)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: model.messages.count) { withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } }
        .tourScroll(proxy, top: nil)
        .onChange(of: model.loading) { withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } }
      }

      composer
    }
    .background(tokens.canvas)
    .toolbar(.hidden, for: .navigationBar)
    // İlk cevap gelince bir kez: basılı tutup kopyalama.
    .task(id: model.messages.count) {
      guard AuthStore.shared.isAuthenticated, !TourStore.shared.isDone(Tour.assistantChat.id),
        !model.loading, model.messages.contains(where: { $0.role == .model })
      else { return }
      focused = false
      await TourStore.shared.startIfNeeded(.assistantChat) { !model.loading && TourStore.shared.anchors["assistant.copy"] != nil }
    }
    // Sekmeye girişliyken ilk girişte bir kez (boş sohbet ekranında).
    .task(id: TourStore.shared.replayNonce) {
      guard AuthStore.shared.isAuthenticated else { return }
      await TourStore.shared.startIfNeeded(.assistant) {
        model.messages.isEmpty && !focused && TourStore.shared.anchors["assistant.intro"] != nil
      }
    }
  }

  // MARK: - Boş durum

  private var intro: some View {
    let dark = tokens.isDark
    return VStack(spacing: 10.5) {
      VStack(alignment: .leading, spacing: 0) {
        Ionicon("sparkles", size: 20, color: Gold.s300)
          .frame(width: 38.5, height: 38.5)
          .background(.white.opacity(0.1), in: .circle)
        Text(t("assistant.introTitle"))
          .font(.system(size: 22, weight: .semibold))
          .lineSpacing(2)
          .foregroundStyle(.white)
          .padding(.top, 14)
        Text(t("assistant.introText"))
          .font(.system(size: 15))
          .lineSpacing(3)
          .foregroundStyle(.white.opacity(0.7))
          .padding(.top, 5.25)
      }
      .padding(17.5)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(dark ? Accent.s900 : Accent.s800, in: .rect(cornerRadius: 21))
      .tourAnchor("assistant.intro")

      LazyVGrid(columns: [GridItem(.flexible(), spacing: 10.5), GridItem(.flexible(), spacing: 10.5)], spacing: 10.5) {
        ForEach(Self.suggestions, id: \.key) { s in
          Button {
            Task { await model.send(t(s.key)) }
          } label: {
            VStack(alignment: .leading, spacing: 0) {
              Ionicon(s.icon, size: 17, color: tokens.accent)
                .frame(width: 31.5, height: 31.5)
                .background(dark ? Accent.s900 : Accent.s50, in: .circle)
              Spacer(minLength: 0)
              Text(t(s.key))
                .font(.system(size: 14, weight: .medium))
                .lineSpacing(2)
                .foregroundStyle(dark ? Forest.s100 : Forest.s800)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 112, maxHeight: 112, alignment: .leading)
            .background(tokens.surface, in: .rect(cornerRadius: 21))
            .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
          }
          .buttonStyle(PressableStyle())
        }
      }
      .tourAnchor("assistant.suggestions")
    }
    .padding(.top, 7)
  }

  // MARK: - Mesajlar

  @ViewBuilder
  private func bubble(_ m: AssistantModel.Message) -> some View {
    let dark = tokens.isDark
    if m.role == .user {
      HStack {
        Spacer(minLength: 48)
        Text(m.text)
          .font(.system(size: 15))
          .lineSpacing(5)
          .foregroundStyle(.white)
          .padding(.horizontal, 14)
          .padding(.vertical, 10.5)
          .background(dark ? Accent.s800 : Accent.s700, in: UnevenRoundedRectangle(topLeadingRadius: 21, bottomLeadingRadius: 21, bottomTrailingRadius: 7, topTrailingRadius: 21))
          .onLongPressGesture { copy(m.text) }
      }
      .frame(maxWidth: .infinity, alignment: .trailing)
    } else {
      HStack(alignment: .bottom, spacing: 7) {
        avatar
        MarkdownText(text: m.text, size: 15, color: dark ? Forest.s100 : Forest.s800, lineSpacing: 5)
          .padding(.horizontal, 14)
          .padding(.vertical, 10.5)
          .background(tokens.surface, in: UnevenRoundedRectangle(topLeadingRadius: 21, bottomLeadingRadius: 7, bottomTrailingRadius: 21, topTrailingRadius: 21))
          .overlay(UnevenRoundedRectangle(topLeadingRadius: 21, bottomLeadingRadius: 7, bottomTrailingRadius: 21, topTrailingRadius: 21).stroke(tokens.line, lineWidth: 1))
          .onLongPressGesture { copy(m.text) }
          .tourAnchor(m.id == model.messages.last(where: { $0.role == .model })?.id ? "assistant.copy" : nil)
        Spacer(minLength: 32)
      }
    }
  }

  private var avatar: some View {
    Ionicon("sparkles", size: 18, color: tokens.isDark ? Accent.s400 : Accent.s600)
      .frame(width: 31.5, height: 31.5)
      .background(tokens.isDark ? Color(hex: 0x14b8a6).opacity(0.2) : Color(hex: 0xccfbf1), in: .rect(cornerRadius: 14))
  }

  private var typing: some View {
    HStack(alignment: .bottom, spacing: 7) {
      avatar
      TypingDots()
        .padding(.horizontal, 17.5)
        .padding(.vertical, 14)
        .background(tokens.surface, in: UnevenRoundedRectangle(topLeadingRadius: 21, bottomLeadingRadius: 5.25, bottomTrailingRadius: 21, topTrailingRadius: 21))
        .overlay(UnevenRoundedRectangle(topLeadingRadius: 21, bottomLeadingRadius: 5.25, bottomTrailingRadius: 21, topTrailingRadius: 21).stroke(tokens.line, lineWidth: 1))
      Spacer()
    }
  }

  // MARK: - Giriş alanı

  private var composer: some View {
    let dark = tokens.isDark
    let canSend = !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !model.loading
    return HStack(alignment: .bottom, spacing: 7) {
      TextField("", text: $input, prompt: Text(t("assistant.placeholder")).foregroundStyle(Forest.s400), axis: .vertical)
        .font(.system(size: 15))
        .foregroundStyle(dark ? .white : Forest.s900)
        .tint(tokens.accent)
        .lineLimit(1...5)
        .focused($focused)
        .disabled(model.loading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10.5)
      Button {
        let text = input
        input = ""
        Task { await model.send(text) }
      } label: {
        Ionicon("arrow-up", size: 22, color: canSend ? (dark ? Forest.s950 : .white) : Forest.s400)
          .frame(width: 38.5, height: 38.5)
          .background(canSend ? (dark ? Accent.s400 : Accent.s700) : (dark ? Forest.s700 : Forest.s200), in: .circle)
      }
      .buttonStyle(PressableStyle(pressedOpacity: 0.85))
      .disabled(!canSend)
      .accessibilityLabel(t("assistant.send"))
    }
    .padding(5.25)
    .background(.ultraThinMaterial, in: .rect(cornerRadius: 21))
    .background(dark ? Forest.s900.opacity(0.4) : Color.white.opacity(0.4), in: .rect(cornerRadius: 21))
    .overlay(RoundedRectangle(cornerRadius: 21).stroke(dark ? Color.white.opacity(0.1) : Color.white.opacity(0.5), lineWidth: 1))
    .tourAnchor("assistant.composer")
    .padding(.horizontal, 10.5)
    .padding(.top, 7)
    .padding(.bottom, 8)
  }

  private func copy(_ text: String) {
    UIPasteboard.general.string = Markdown.strip(text)
    Haptics.notify(.success)
    Toast.success(t("assistant.copied"), t("assistant.copiedMessage"))
  }
}

/// Animasyonlu "yazıyor" noktaları.
private struct TypingDots: View {
  @State private var phase = 0.0

  var body: some View {
    TimelineView(.animation) { context in
      let time = context.date.timeIntervalSinceReferenceDate
      HStack(spacing: 5.25) {
        ForEach(0..<3, id: \.self) { i in
          // RN: 350 ms yukarı + 350 ms aşağı, noktalar 150 ms arayla.
          let v = (sin((time - Double(i) * 0.15) * .pi / 0.7) + 1) / 2
          Circle()
            .fill(Forest.s400)
            .frame(width: 7, height: 7)
            .opacity(0.35 + v * 0.65)
            .offset(y: -4 * v)
        }
      }
    }
    .accessibilityLabel(t("common.loading"))
  }
}
