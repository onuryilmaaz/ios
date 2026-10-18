import SwiftUI

/// Cuma hutbesi. RN: screens/user/HutbeScreen.tsx
struct HutbeView: View {
  @Environment(\.tokens) private var tokens
  @State private var list: [HutbeParser.Item]?
  @State private var listError = false
  @State private var selectedId: String?
  @State private var text: HutbeParser.Parsed?
  @State private var textState: TextState = .idle
  @State private var audio = HutbeAudio()

  private enum TextState { case idle, loading, error }
  private let lang = HutbeService.lang

  var body: some View {
    VStack(spacing: 0) {
      StandardHeader(title: t("hutbe.title"))
      if list == nil && listError {
        errorView
      } else if let list, let selected = list.first(where: { $0.id == selectedId }) ?? list.first {
        content(list: list, selected: selected)
      } else {
        Spacer()
        ProgressView().tint(tokens.accent)
        Text(t("common.loading")).font(.system(size: 14)).foregroundStyle(tokens.textSecondary).padding(.top, 12)
        Spacer()
      }
    }
    .background(tokens.canvas)
    .toolbar(.hidden, for: .navigationBar)
    .task { await loadList() }
    .onDisappear { audio.stop() }
  }

  private var errorView: some View {
    VStack(spacing: 0) {
      Spacer()
      Ionicon("cloud-offline-outline", size: 44, color: tokens.inkSubtle)
      Text(t("hutbe.loadFailed")).font(.system(size: 17, weight: .semibold)).foregroundStyle(tokens.textPrimary).padding(.top, 16)
      Text(t("hutbe.loadFailedMessage")).font(.system(size: 15)).foregroundStyle(tokens.textSecondary)
        .multilineTextAlignment(.center).padding(.top, 6).padding(.horizontal, 32)
      AppButton(title: t("common.retry")) { Task { await loadList(force: true) } }
        .frame(width: 180).padding(.top, 20)
      Spacer()
      AppButton(title: t("hutbe.openWeb"), variant: .outline) { open(HutbeService.pageURL(lang)) }
        .padding(.horizontal, 16).padding(.bottom, 32)
    }
  }

  private func content(list: [HutbeParser.Item], selected: HutbeParser.Item) -> some View {
    let isLatest = selected.id == list.first?.id
    let others = Array(list.filter { $0.id != selected.id }.prefix(8))
    let dark = tokens.isDark

    return ScrollViewReader { proxy in
      ScrollView {
        VStack(alignment: .leading, spacing: 14) {
          VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
              Ionicon("calendar-outline", size: 14, color: Gold.s300)
              Text(isLatest ? t("hutbe.thisWeek") : Self.format(selected.date))
                .font(.system(size: 13, weight: .medium)).foregroundStyle(Gold.s300)
            }
            Text(selected.title).font(.system(size: 24, weight: .bold)).foregroundStyle(.white).lineSpacing(4).padding(.top, 7)
            if isLatest {
              Text(Self.format(selected.date)).font(.system(size: 13)).foregroundStyle(.white.opacity(0.7)).padding(.top, 3.5)
            }
            if selected.audioUrl != nil { audioBar.padding(.top, 17.5) }
          }
          .padding(17.5)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(dark ? Accent.s900 : Accent.s800, in: .rect(cornerRadius: 21))
          .id("top")

          if HutbeService.canReadInApp(lang) && textState != .error {
            Card {
              if textState == .loading || text == nil {
                HStack(spacing: 10) {
                  ProgressView().tint(tokens.accent)
                  Text(t("hutbe.textLoading")).font(.system(size: 14)).foregroundStyle(tokens.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
              } else if let text {
                VStack(alignment: .leading, spacing: 17.5) {
                  ForEach(Array(text.sections.enumerated()), id: \.offset) { _, s in
                    VStack(alignment: .leading, spacing: 7) {
                      if let heading = s.heading {
                        Text(heading).font(.system(size: 17, weight: .semibold)).foregroundStyle(dark ? Accent.s300 : Accent.s700)
                      }
                      Text(s.text).font(.system(size: 16)).lineSpacing(9).foregroundStyle(dark ? Forest.s200 : Forest.s800)
                    }
                  }
                  if !text.footnotes.isEmpty {
                    VStack(alignment: .leading, spacing: 3.5) {
                      Text(t("hutbe.footnotes")).font(.system(size: 13, weight: .medium)).foregroundStyle(tokens.textSecondary).padding(.bottom, 4)
                      ForEach(text.footnotes, id: \.self) { f in
                        Text(f).font(.system(size: 13)).lineSpacing(4).foregroundStyle(tokens.textSecondary)
                      }
                    }
                    .padding(.top, 14)
                    .overlay(alignment: .top) { Rectangle().fill(tokens.line).frame(height: 1) }
                  }
                  Text(t("hutbe.source")).font(.system(size: 13)).foregroundStyle(tokens.textSecondary)
                }
              }
            }
          } else {
            Card {
              Text(t(textState == .error ? "hutbe.textFailed" : "hutbe.pdfOnly"))
                .font(.system(size: 15)).lineSpacing(5).foregroundStyle(dark ? Forest.s300 : Forest.s600)
              if let pdf = selected.pdfUrl {
                AppButton(title: t("hutbe.openPdf")) {
                  Haptics.impact(.light)
                  open(pdf)
                }
                .padding(.top, 16)
              }
            }
          }

          if !others.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
              SectionLabel(t("hutbe.previous"))
              GroupedCard {
                ForEach(Array(others.enumerated()), id: \.element.id) { i, h in
                  Button {
                    Haptics.impact(.light)
                    select(h.id)
                    withAnimation { proxy.scrollTo("top", anchor: .top) }
                  } label: {
                    HStack(spacing: 10.5) {
                      VStack(alignment: .leading, spacing: 1.75) {
                        Text(h.title).font(.system(size: 16)).foregroundStyle(tokens.textPrimary).lineLimit(2).multilineTextAlignment(.leading)
                        Text(Self.format(h.date, weekday: false)).font(.system(size: 13)).foregroundStyle(tokens.textSecondary)
                      }
                      .frame(maxWidth: .infinity, alignment: .leading)
                      if h.audioUrl != nil { Ionicon("headset-outline", size: 16, color: tokens.inkMuted) }
                      Ionicon(dirIcon("chevron-forward"), size: 16, color: tokens.inkSubtle)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12.25)
                    .contentShape(.rect)
                  }
                  .buttonStyle(PressableStyle())
                  if i < others.count - 1 { RowDivider() }
                }
              }
            }
          }
        }
        .padding(14)
        .padding(.bottom, 24)
      }
      .scrollIndicators(.hidden)
    }
    .task(id: selected.id) {
      if let url = selected.audioUrl { audio.load(url) } else { audio.stop() }
      await loadText(selected)
    }
  }

  private var audioBar: some View {
    let progress = audio.duration > 0 ? min(1, audio.position / audio.duration) : 0
    return VStack(spacing: 10.5) {
      HStack(spacing: 14) {
        Button {
          Haptics.impact(.light)
          audio.toggle()
        } label: {
          Ionicon(audio.playing ? "pause" : "play", size: 24, color: Accent.s900)
            .offset(x: audio.playing ? 0 : 1.5)
            .frame(width: 49, height: 49)
            .background(Gold.s300, in: .circle)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(t(audio.playing ? "hutbe.pause" : "hutbe.play"))

        VStack(alignment: .leading, spacing: 1.75) {
          Text(t("hutbe.listen")).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
          Text(
            audio.duration > 0
              ? "\(Self.clock(audio.position)) / \(Self.clock(audio.duration))"
              : (audio.playing || audio.buffering ? t("common.loading") : "--:--")
          )
          .font(.system(size: 13)).foregroundStyle(.white.opacity(0.7)).tabularNumbers()
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        skipButton("play-back", label: t("hutbe.back15")) { audio.skip(-15) }
        skipButton("play-forward", label: t("hutbe.forward15")) { audio.skip(15) }
      }
      Capsule().fill(.white.opacity(0.15)).frame(height: 3.5)
        .overlay(alignment: .leading) {
          GeometryReader { geo in Capsule().fill(Gold.s300).frame(width: geo.size.width * progress) }
        }
        .clipShape(.capsule)
    }
  }

  private func skipButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
    Button {
      Haptics.impact(.light)
      action()
    } label: {
      Ionicon(icon, size: 16, color: .white).frame(width: 35, height: 35).background(.white.opacity(0.1), in: .circle)
    }
    .buttonStyle(PressableStyle())
    .accessibilityLabel(label)
  }

  // MARK: - Veri

  private func loadList(force: Bool = false) async {
    listError = false
    // Önbellek varsa anında göster, tazesi arkadan gelsin.
    let cached = HutbeService.cachedList(lang)
    if list == nil, let cached, !cached.isEmpty { list = cached }
    do {
      list = try await HutbeService.list(lang, force: force)
    } catch {
      if cached?.isEmpty ?? true { listError = true }
    }
  }

  private func select(_ id: String) {
    selectedId = id
  }

  private func loadText(_ item: HutbeParser.Item) async {
    guard HutbeService.canReadInApp(lang) else { return }
    text = nil
    textState = .loading
    do {
      let parsed = try await HutbeService.text(lang, item: item)
      guard !Task.isCancelled else { return }
      text = parsed
      textState = .idle
    } catch {
      if !Task.isCancelled { textState = .error }
    }
  }

  private func open(_ raw: String) {
    guard let url = URL(string: raw) else {
      Toast.error(t("common.error"), t("cuma.openFailed"))
      return
    }
    InAppBrowser.open(url)
  }

  private static func format(_ date: Date, weekday: Bool = true) -> String {
    var style = Date.FormatStyle.dateTime.day().month(.wide).year().locale(Localizer.shared.locale)
    if weekday { style = style.weekday(.wide) }
    return date.formatted(style)
  }

  private static func clock(_ seconds: Double) -> String {
    let s = max(0, Int(seconds))
    return "\(s / 60):\(String(format: "%02d", s % 60))"
  }
}
