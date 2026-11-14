import SwiftUI

/// Ezber: tekrar listesi, ayet ekleme ve aralıklı tekrar oturumu. Android HifzScreen.
struct HifzView: View {
  @Environment(\.tokens) private var tokens
  @State private var session: [HifzPlan.Card]?
  @State private var adding = false
  @State private var surahs: [Surah] = []

  private func name(_ id: Int) -> String { surahs.first { $0.id == id }.map { surahName($0) } ?? "\(id)" }

  var body: some View {
    VStack(spacing: 0) {
      StandardHeader(title: t("hifz.title"))
      if let session {
        HifzReviewView(cards: session, name: name) {
          self.session = nil
          QuranAudioPlayer.shared.stop()
        }
      } else {
        overview
      }
    }
    .background(tokens.canvas)
    .toolbar(.hidden, for: .navigationBar)
    .task { surahs = await QuranService.surahs() }
    .onDisappear { QuranAudioPlayer.shared.stop() }
    .sheet(isPresented: $adding) {
      HifzAddSheet(initial: surahs).environment(\.tokens, tokens).presentationDetents([.large]).presentationDragIndicator(.visible)
    }
  }

  private var overview: some View {
    let store = HifzStore.shared
    let due = store.due()
    return ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 3.5) {
          Text(t("hifz.heroDue")).font(.system(size: 13, weight: .medium)).foregroundStyle(Gold.s300)
          Text(t("hifz.heroCount", ["count": due.count])).font(.system(size: 28, weight: .bold)).foregroundStyle(.white).tabularNumbers()
          Text(t("hifz.stats", ["total": store.cards.count, "strong": store.strongCount]))
            .font(.system(size: 13)).foregroundStyle(.white.opacity(0.85)).tabularNumbers()
          if !store.cards.isEmpty {
            Button {
              Haptics.impact(.medium)
              session = due
            } label: {
              Text(t(due.isEmpty ? "hifz.allDone" : "hifz.start")).font(.system(size: 15, weight: .semibold)).foregroundStyle(Accent.s900)
                .frame(maxWidth: .infinity).padding(.vertical, 12).background(.white, in: .capsule)
            }
            .buttonStyle(PressableStyle())
            .disabled(due.isEmpty).opacity(due.isEmpty ? 0.6 : 1)
            .padding(.top, 10.5)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(17.5)
        .background(Accent.s800, in: .rect(cornerRadius: 24))

        if store.cards.isEmpty {
          Text(t("hifz.empty")).font(.system(size: 14)).foregroundStyle(tokens.textSecondary)
        }
        let groups = Dictionary(grouping: store.cards, by: \.surah).sorted { $0.key < $1.key }
        if !groups.isEmpty {
          GroupedCard {
            ForEach(Array(groups.enumerated()), id: \.element.key) { i, group in
              if i > 0 { RowDivider() }
              row(surah: group.key, list: group.value, due: due.filter { $0.surah == group.key }.count)
            }
          }
        }
        AppButton(title: t("hifz.add"), variant: store.cards.isEmpty ? .primary : .secondary) {
          Haptics.impact(.light)
          adding = true
        }
      }
      .padding(16).padding(.bottom, 84)
    }
    .scrollIndicators(.hidden)
  }

  private func row(surah: Int, list: [HifzPlan.Card], due: Int) -> some View {
    HStack(spacing: 10.5) {
      Text("\(surah)").font(.system(size: 13)).monospacedDigit().foregroundStyle(tokens.inkSubtle)
      VStack(alignment: .leading, spacing: 1.75) {
        Text(name(surah)).font(.system(size: 15, weight: .medium)).foregroundStyle(tokens.textPrimary)
        Text(t("hifz.surahRow", ["count": list.count, "due": due, "from": list.first?.verse ?? 0, "to": list.last?.verse ?? 0]))
          .font(.system(size: 12)).foregroundStyle(tokens.textSecondary).tabularNumbers()
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      Button {
        Haptics.impact(.light)
        AppAlert.confirm(t("hifz.removeTitle"), t("hifz.removeMessage", ["surah": name(surah)]), confirmText: t("hifz.remove"), destructive: true) {
          HifzStore.shared.removeSurah(surah)
        }
      } label: {
        Ionicon("trash-outline", size: 18, color: tokens.danger).frame(width: 35, height: 35)
      }
      .buttonStyle(PressableStyle())
      .accessibilityLabel(t("hifz.remove"))
    }
    .padding(.horizontal, 14).padding(.vertical, 10.5)
  }
}

/// Tekrar oturumu: metin gizli başlar, dinlenebilir; gösterince değerlendirilir.
private struct HifzReviewView: View {
  @Environment(\.tokens) private var tokens
  let cards: [HifzPlan.Card]
  let name: (Int) -> String
  let onDone: () -> Void
  @State private var index = 0
  @State private var revealed = false
  @State private var verses: [Int: [Verse]] = [:]
  @Bindable private var audio = QuranAudioPlayer.shared

  var body: some View {
    if index >= cards.count {
      VStack(spacing: 16) {
        VStack(spacing: 10) {
          Ionicon("checkmark-circle", size: 44, color: Gold.s300)
          Text(t("hifz.sessionDone")).font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
          Text(t("hifz.sessionDoneHint", ["count": cards.count])).font(.system(size: 14)).foregroundStyle(.white.opacity(0.85)).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(24)
        .background(Accent.s800, in: .rect(cornerRadius: 24))
        AppButton(title: t("hifz.close"), variant: .secondary) { onDone() }
        Spacer()
      }
      .padding(16)
    } else {
      session(cards[index])
    }
  }

  private func session(_ card: HifzPlan.Card) -> some View {
    let verse = verses[card.surah]?.first { $0.verse_number == card.verse }
    return ScrollView {
      VStack(spacing: 16) {
        HStack {
          Text(t("hifz.verseLabel", ["surah": name(card.surah), "verse": card.verse]))
            .font(.system(size: 15, weight: .semibold)).foregroundStyle(tokens.textPrimary)
          Spacer()
          Text(t("hifz.progress", ["index": index + 1, "total": cards.count])).font(.system(size: 13)).foregroundStyle(tokens.textSecondary).tabularNumbers()
        }
        GeometryReader { g in
          ZStack(alignment: .leading) {
            Capsule().fill(tokens.fill)
            Capsule().fill(tokens.accent).frame(width: g.size.width * Double(index) / Double(cards.count))
          }
        }
        .frame(height: 5.25).environment(\.layoutDirection, .leftToRight)

        Button {
          guard verse != nil, !revealed else { return }
          Haptics.impact(.light)
          revealed = true
        } label: {
          VStack(spacing: 12) {
            if let verse {
              if revealed {
                Text(QuranFont.text(verse.verse_simplified))
                  .font(.custom(QuranFont.name, size: 26)).lineSpacing(14)
                  .foregroundStyle(tokens.textPrimary).multilineTextAlignment(.center)
                  .environment(\.layoutDirection, .rightToLeft)
                // Latin harfli okunuş (Arapça arayüzde gerekmez).
                if Localizer.shared.language != .ar, let reading = verse.transcription, !reading.isEmpty {
                  Text(reading).font(.system(size: 15).italic()).foregroundStyle(tokens.accent).multilineTextAlignment(.center)
                }
                Text(verse.translation.text).font(.system(size: 13)).foregroundStyle(tokens.textSecondary).multilineTextAlignment(.center)
              } else {
                Ionicon("eye-off-outline", size: 28, color: tokens.inkSubtle)
                Text(t("hifz.reveal")).font(.system(size: 14)).foregroundStyle(tokens.textSecondary).multilineTextAlignment(.center)
              }
            } else {
              ProgressView().tint(tokens.accent)
            }
          }
          .frame(maxWidth: .infinity, minHeight: 200)
          .padding(17.5)
          .background(tokens.surface, in: .rect(cornerRadius: 21))
          .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
        }
        .buttonStyle(.plain)

        if let verse {
          Button {
            Haptics.impact(.light)
            audio.configure([verse])
            audio.play(index: 0)
          } label: {
            HStack(spacing: 7) {
              Ionicon(audio.state == .playing ? "volume-high" : "play", size: 18, color: tokens.accent)
              Text(t("hifz.listen")).font(.system(size: 15, weight: .semibold)).foregroundStyle(tokens.accent)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(tokens.surface, in: .capsule)
            .overlay(Capsule().stroke(tokens.line, lineWidth: 1))
          }
          .buttonStyle(PressableStyle())
        }

        if revealed {
          HStack(spacing: 8) {
            rate(.forgot, "hifz.forgot", .outline, card)
            rate(.hard, "hifz.hard", .secondary, card)
            rate(.remembered, "hifz.remembered", .primary, card)
          }
        }
      }
      .padding(16).padding(.bottom, 84)
    }
    .scrollIndicators(.hidden)
    .task(id: card.surah) {
      if verses[card.surah] == nil { verses[card.surah] = await QuranService.surah(card.surah) }
    }
  }

  private func rate(_ rating: HifzPlan.Rating, _ key: String, _ variant: AppButton.Variant, _ card: HifzPlan.Card) -> some View {
    AppButton(title: t(key), variant: variant) {
      if rating == .remembered { Haptics.notify(.success) } else { Haptics.impact(.medium) }
      HifzStore.shared.rate(card, rating)
      audio.stop()
      revealed = false
      index += 1
    }
  }
}

/// Sure ve ayet aralığı seçip ezbere ekler.
private struct HifzAddSheet: View {
  @Environment(\.tokens) private var tokens
  @Environment(\.dismiss) private var dismiss
  let initial: [Surah]
  @State private var loaded: [Surah]?
  @State private var loadFailed = false
  @State private var attempt = 0
  @State private var surah: Surah?
  @State private var from = 1
  @State private var to = 1
  @State private var busy = false

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Text(t("hifz.addTitle")).font(.system(size: 17, weight: .semibold)).foregroundStyle(tokens.textPrimary)
        Spacer()
        Button { Haptics.impact(.light); dismiss() } label: {
          Ionicon("close", size: 20, color: tokens.inkMuted).frame(width: 35, height: 35).background(tokens.surface, in: .circle)
            .overlay(Circle().stroke(tokens.line, lineWidth: 1))
        }.buttonStyle(PressableStyle()).accessibilityLabel(t("common.close"))
      }
      if let surah {
        Button { Haptics.impact(.light); self.surah = nil } label: {
          HStack {
            Text(surahName(surah)).font(.system(size: 15, weight: .semibold)).foregroundStyle(tokens.textPrimary)
            Spacer()
            Text(t("hifz.change")).font(.system(size: 13)).foregroundStyle(tokens.accent)
          }
          .padding(14)
          .background(tokens.surface, in: .rect(cornerRadius: 21))
          .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
        }.buttonStyle(PressableStyle())
        stepper(t("hifz.from"), value: $from, range: 1...to)
        stepper(t("hifz.to"), value: $to, range: from...surah.verse_count)
        AppButton(title: t("hifz.addButton", ["count": to - from + 1]), loading: busy) { Task { await add(surah) } }
        Spacer()
      } else {
        Text(t("hifz.pickSurah")).font(.system(size: 13, weight: .medium)).foregroundStyle(tokens.textSecondary)
        if surahs.isEmpty {
          VStack(spacing: 16) {
            if loadFailed {
              Text(t("hifz.surahsFailed")).font(.system(size: 15)).foregroundStyle(tokens.textSecondary).multilineTextAlignment(.center)
              AppButton(title: t("common.retry")) { attempt += 1 }.frame(width: 180)
            } else {
              ProgressView().tint(tokens.accent)
            }
          }
          .frame(maxWidth: .infinity).padding(.vertical, 30)
          Spacer()
        } else {
        ScrollView {
          LazyVStack(spacing: 0) {
            ForEach(surahs) { s in
              Button {
                Haptics.impact(.light)
                surah = s
                from = 1
                to = min(5, s.verse_count)
              } label: {
                HStack(spacing: 10.5) {
                  Text("\(s.id)").font(.system(size: 13)).monospacedDigit().foregroundStyle(tokens.inkSubtle).frame(width: 28, alignment: .leading)
                  Text(surahName(s)).font(.system(size: 15)).foregroundStyle(tokens.textPrimary).frame(maxWidth: .infinity, alignment: .leading)
                  Text(t("quran.verseCount", ["count": s.verse_count])).font(.system(size: 12)).foregroundStyle(tokens.textSecondary)
                  Ionicon(dirIcon("chevron-forward"), size: 14, color: tokens.inkSubtle)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .contentShape(.rect)
              }
              .buttonStyle(PressableStyle())
              RowDivider()
            }
          }
        }
        .background(tokens.surface, in: .rect(cornerRadius: 21))
        .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
        }
      }
    }
    .padding(16)
    .background(tokens.canvas)
    .task(id: attempt) { await loadSurahs() }
  }

  private var surahs: [Surah] { loaded ?? initial }

  /// Ana ekrandaki liste gelmediyse (ağ, açılış yarışı) sayfa kendisi yükler.
  private func loadSurahs() async {
    guard surahs.isEmpty else { return }
    loadFailed = false
    let list = await QuranService.surahs()
    if Task.isCancelled { return }
    loaded = list
    loadFailed = list.isEmpty
  }

  private func stepper(_ label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
    HStack(spacing: 10.5) {
      Text(label).font(.system(size: 15)).foregroundStyle(tokens.textPrimary).frame(maxWidth: .infinity, alignment: .leading)
      ForEach([-1, 1], id: \.self) { delta in
        let enabled = range.contains(value.wrappedValue + delta)
        Button {
          Haptics.impact(.light)
          value.wrappedValue += delta
        } label: {
          Ionicon(delta < 0 ? "remove" : "add", size: 18, color: tokens.inkMuted).frame(width: 35, height: 35).background(tokens.fill, in: .circle)
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled).opacity(enabled ? 1 : 0.4)
        .accessibilityLabel(t(delta < 0 ? "hifz.less" : "hifz.more", ["label": label]))
        if delta < 0 {
          Text("\(value.wrappedValue)").font(.system(size: 17, weight: .semibold)).foregroundStyle(tokens.textPrimary).tabularNumbers().frame(minWidth: 30)
        }
      }
    }
    .padding(.horizontal, 14).padding(.vertical, 10.5)
    .background(tokens.surface, in: .rect(cornerRadius: 21))
    .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
  }

  private func add(_ surah: Surah) async {
    guard !busy else { return }
    busy = true
    let verses = await QuranService.surah(surah.id)
    busy = false
    guard !verses.isEmpty else {
      Toast.error(t("common.error"), t("hifz.loadFailed"))
      return
    }
    let picked = verses.filter { (from...to).contains($0.verse_number) }.map { ($0.verse_number, $0.id) }
    HifzStore.shared.add(surah: surah.id, verses: picked)
    Haptics.notify(.success)
    Toast.success(t("hifz.added", ["count": picked.count]))
    dismiss()
  }
}

/// Kur'an sekmesindeki giriş kartı.
struct HifzEntryCard: View {
  @Environment(\.tokens) private var tokens
  let onOpen: () -> Void

  var body: some View {
    let store = HifzStore.shared
    let due = store.due().count
    Button { Haptics.impact(.light); onOpen() } label: {
      HStack(spacing: 10.5) {
        Ionicon("school-outline", size: 21, color: tokens.accent).frame(width: 42, height: 42).background(tokens.accentSoft, in: .circle)
        VStack(alignment: .leading, spacing: 1.75) {
          Text(t("hifz.title")).font(.system(size: 17, weight: .semibold)).foregroundStyle(tokens.textPrimary)
          Text(store.cards.isEmpty ? t("hifz.entryEmpty") : due > 0 ? t("hifz.entryDue", ["count": due]) : t("hifz.allDone"))
            .font(.system(size: 13)).foregroundStyle(tokens.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        Ionicon(dirIcon("chevron-forward"), size: 18, color: tokens.inkSubtle)
      }
      .padding(17.5)
      .background(tokens.surface, in: .rect(cornerRadius: 21))
      .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
    }
    .buttonStyle(PressableStyle())
  }
}
