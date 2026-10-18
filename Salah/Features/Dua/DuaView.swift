import SwiftUI

/// Dualar. RN: screens/user/DuaScreen.tsx
struct DuaView: View {
  @Environment(\.tokens) private var tokens
  @State private var category: DuaCategory? = DebugLaunch.dua == "category" ? DuaLibrary.categories.first : nil
  @State private var selected: Dua? = DebugLaunch.dua == "detail" ? DuaLibrary.allDuas.first : nil
  @State private var sharing: Dua? = DebugLaunch.dua == "share" ? DuaLibrary.allDuas.first : nil

  var body: some View {
    let favorites = DuaFavorites.shared
    let categories = DuaLibrary.categories
    let favoriteDuas = categories.flatMap(\.duas).filter { favorites.contains($0.id) }
    let dark = tokens.isDark

    VStack(spacing: 0) {
      StandardHeader(title: t("dua.title"))
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          DuaMoodFinder { selected = $0 }
            .padding(.top, 14)
            .padding(.bottom, 17.5)

          if !favoriteDuas.isEmpty {
            HStack(spacing: 7) {
              Ionicon("heart", size: 16, color: Gold.s500)
              Text(t("dua.favorites")).font(.system(size: 13, weight: .medium)).foregroundStyle(tokens.textSecondary)
            }
            .padding(.bottom, 10.5)
            ForEach(favoriteDuas) { dua in
              Button {
                Haptics.impact(.light)
                selected = dua
              } label: {
                HStack {
                  Text(dua.title)
                    .font(.system(size: 12.25, weight: .bold))
                    .foregroundStyle(dark ? .white : Forest.s900)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                  Ionicon(dirIcon("chevron-forward"), size: 16, color: dark ? Gold.s400.opacity(0.6) : Gold.s500)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10.5)
                .background(dark ? Gold.s400.opacity(0.1) : Gold.s50, in: .rect(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(dark ? Gold.s700 : Gold.s100, lineWidth: 1))
              }
              .buttonStyle(PressableStyle())
              .padding(.bottom, 7)
            }
            Spacer().frame(height: 10.5)
          }

          Text(t("dua.categories"))
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(tokens.textSecondary)
            .padding(.bottom, 10.5)
          VStack(spacing: 10.5) {
            ForEach(categories) { cat in
              Button {
                Haptics.impact(.light)
                category = cat
              } label: {
                HStack(spacing: 0) {
                  Ionicon(cat.icon, size: 22, color: tokens.accent)
                    .frame(width: 42, height: 42)
                    .background(dark ? Accent.s900 : Accent.s50, in: .circle)
                    .padding(.trailing, 14)
                  VStack(alignment: .leading, spacing: 1.75) {
                    Text(cat.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(dark ? .white : Forest.s900)
                    Text(t("dua.count", ["count": cat.duas.count])).font(.system(size: 10.5)).foregroundStyle(tokens.textSecondary)
                  }
                  .frame(maxWidth: .infinity, alignment: .leading)
                  Ionicon(dirIcon("chevron-forward"), size: 20, color: dark ? .white.opacity(0.2) : Forest.s400)
                }
                .padding(14)
                .background(tokens.surface, in: .rect(cornerRadius: 21))
                .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
              }
              .buttonStyle(PressableStyle())
            }
          }
          .padding(.bottom, 32)
        }
        .padding(.horizontal, 14)
      }
      .scrollIndicators(.hidden)
      .scrollDismissesKeyboard(.interactively)
    }
    .background(tokens.canvas)
    .toolbar(.hidden, for: .navigationBar)
    .sheet(item: $category) { cat in
      DuaCategorySheet(category: cat, onShare: { sharing = $0 }) { dua in
        category = nil
        Task {
          try? await Task.sleep(for: .milliseconds(300))
          selected = dua
        }
      }
      .sheetStyle(tokens)
    }
    .sheet(item: $selected) { dua in
      DuaDetailSheet(dua: dua) { sharing = $0 }.sheetStyle(tokens)
    }
    .fullScreenCover(item: $sharing) { dua in
      ShareCardSheet(
        arabic: dua.arabic.isEmpty ? nil : dua.arabic,
        text: dua.turkish.isEmpty ? dua.title : dua.turkish,
        source: [dua.title, dua.source].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "),
        label: t("shareCards.dua.label"),
        icon: "hand-left-outline"
      )
      .environment(\.tokens, tokens)
    }
  }
}

extension View {
  /// RN DraggableBottomSheet (90%) karşılığı.
  func sheetStyle(_ tokens: Tokens) -> some View {
    self
      .presentationDetents([.fraction(0.9)])
      .presentationDragIndicator(.visible)
      .presentationBackground(tokens.surface)
      .presentationCornerRadius(24)
      .environment(\.tokens, tokens)
  }
}

/// Kategori sayfası başlığı + kapat düğmesi.
private struct SheetHeader<Leading: View, Trailing: View>: View {
  @Environment(\.tokens) private var tokens
  @Environment(\.dismiss) private var dismiss
  @ViewBuilder var leading: Leading
  @ViewBuilder var trailing: Trailing

  var body: some View {
    HStack(spacing: 10.5) {
      leading.frame(maxWidth: .infinity, alignment: .leading)
      trailing
      Button {
        dismiss()
      } label: {
        Ionicon("close", size: 18, color: tokens.isDark ? Forest.s400 : Forest.s600)
          .frame(width: 31.5, height: 31.5)
          .background(tokens.fill, in: .circle)
      }
      .buttonStyle(PressableStyle())
      .accessibilityLabel(t("common.close"))
    }
    .padding(.horizontal, 17.5)
    .padding(.top, 24)
    .padding(.bottom, 14)
    .overlay(alignment: .bottom) { RowDivider(leading: 0) }
  }
}

private struct FavoriteButton: View {
  @Environment(\.tokens) private var tokens
  let id: String
  var size: CGFloat = 18

  var body: some View {
    let on = DuaFavorites.shared.contains(id)
    Button {
      Haptics.impact(.light)
      DuaFavorites.shared.toggle(id)
    } label: {
      Ionicon(on ? "heart" : "heart-outline", size: size, color: on ? Gold.s500 : (tokens.isDark ? Forest.s600 : Forest.s400))
    }
    .buttonStyle(PressableStyle())
    .accessibilityLabel(t(on ? "dua.favRemove" : "dua.favAdd"))
  }
}

private struct DuaCategorySheet: View {
  @Environment(\.tokens) private var tokens
  let category: DuaCategory
  let onShare: (Dua) -> Void
  let onSelect: (Dua) -> Void

  var body: some View {
    let dark = tokens.isDark
    VStack(spacing: 0) {
      SheetHeader {
        HStack(spacing: 10.5) {
          Ionicon(category.icon, size: 20, color: tokens.accent)
            .frame(width: 35, height: 35)
            .background(dark ? Accent.s900 : Accent.s50, in: .circle)
          Text(category.title).font(.system(size: 15.75, weight: .semibold)).foregroundStyle(dark ? .white : Forest.s900)
        }
      } trailing: {
        EmptyView()
      }

      ScrollView {
        LazyVStack(spacing: 10.5) {
          ForEach(category.duas) { dua in
            Button {
              onSelect(dua)
            } label: {
              VStack(alignment: .leading, spacing: 0) {
                HStack {
                  Text(dua.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(dark ? .white : Forest.s900)
                    .frame(maxWidth: .infinity, alignment: .leading)
                  HStack(spacing: 10.5) {
                    FavoriteButton(id: dua.id)
                    Button {
                      Haptics.impact(.light)
                      onShare(dua)
                    } label: {
                      Ionicon("share-outline", size: 18, color: dark ? Forest.s600 : Forest.s400)
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel(t("dua.share"))
                  }
                }
                .padding(.horizontal, 17.5)
                .padding(.vertical, 10.5)
                .overlay(alignment: .bottom) { Rectangle().fill(dark ? Forest.s800 : Forest.s100).frame(height: 1) }

                VStack(alignment: .leading, spacing: 0) {
                  ArabicText(dua.arabic, size: 18, lineHeight: 32)
                    .padding(.bottom, 10.5)
                  if !dua.transliteration.isEmpty {
                    Text(dua.transliteration).font(.system(size: 10.5)).italic().foregroundStyle(tokens.textSecondary)
                      .padding(.bottom, 7)
                  }
                  if !dua.turkish.isEmpty {
                    Text(dua.turkish).font(.system(size: 12.25)).lineSpacing(3).foregroundStyle(dark ? Forest.s300 : Forest.s700)
                  }
                  if let source = dua.source {
                    Text(t("dua.source", ["source": source])).font(.system(size: 10.5)).foregroundStyle(dark ? Forest.s500 : Forest.s400)
                      .padding(.top, 7)
                  }
                }
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 17.5)
                .padding(.vertical, 14)
              }
              .background(dark ? Forest.s800.opacity(0.6) : Forest.s50, in: .rect(cornerRadius: 14))
              .overlay(RoundedRectangle(cornerRadius: 14).stroke(dark ? Forest.s800 : Forest.s100, lineWidth: 1))
            }
            .buttonStyle(PressableStyle(pressedOpacity: 0.8))
          }
        }
        .padding(16)
        .padding(.bottom, 24)
      }
      .scrollIndicators(.hidden)
    }
  }
}

private struct DuaDetailSheet: View {
  @Environment(\.tokens) private var tokens
  let dua: Dua
  let onShare: (Dua) -> Void

  var body: some View {
    let dark = tokens.isDark
    VStack(spacing: 0) {
      SheetHeader {
        Text(dua.title).font(.system(size: 15.75, weight: .semibold)).foregroundStyle(dark ? .white : Forest.s900)
      } trailing: {
        HStack(spacing: 10.5) {
          FavoriteButton(id: dua.id, size: 22)
          Button {
            Haptics.impact(.light)
            onShare(dua)
          } label: {
            Ionicon("share-social-outline", size: 22, color: dark ? Forest.s600 : Forest.s400)
          }
          .buttonStyle(PressableStyle())
          .accessibilityLabel(t("dua.share"))
        }
        .padding(.trailing, 3.5)
      }

      ScrollView {
        VStack(alignment: .leading, spacing: 14) {
          ArabicText(dua.arabic, size: 22, lineHeight: 40)
            .padding(.horizontal, 22)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity)
            .background(MushafDecorativeFrame(color: dark ? Accent.s400 : Accent.s600))
            .background(dark ? Forest.s800.opacity(0.6) : Forest.s50, in: .rect(cornerRadius: 14))
            .padding(.bottom, 8)

          if !dua.transliteration.isEmpty {
            VStack(alignment: .leading, spacing: 3.5) {
              Text(t("dua.transliteration")).font(.system(size: 13, weight: .medium)).foregroundStyle(Forest.s400)
              Text(dua.transliteration).font(.system(size: 14)).italic().lineSpacing(4).foregroundStyle(dark ? Forest.s300 : Forest.s600)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(tokens.surface, in: .rect(cornerRadius: 21))
            .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
          }

          if !dua.turkish.isEmpty {
            VStack(alignment: .leading, spacing: 3.5) {
              Text(t("dua.meaning")).font(.system(size: 13, weight: .medium)).foregroundStyle(dark ? Accent.s400 : Accent.s600)
              Text(dua.turkish).font(.system(size: 14)).lineSpacing(4).foregroundStyle(dark ? Forest.s200 : Forest.s700)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(dark ? Accent.s500.opacity(0.1) : Accent.s50, in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(dark ? Accent.s800 : Accent.s100, lineWidth: 1))
          }

          if let source = dua.source {
            HStack(spacing: 7) {
              Ionicon("library-outline", size: 14, color: dark ? Forest.s600 : Forest.s400)
              Text(t("dua.source", ["source": source])).font(.system(size: 10.5)).foregroundStyle(tokens.textSecondary)
              Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10.5)
            .background(dark ? Forest.s800 : Forest.s50, in: .rect(cornerRadius: 10.5))
          }
        }
        .padding(24)
        .padding(.bottom, 16)
      }
      .scrollIndicators(.hidden)
    }
  }
}

/// Dua/ayet Arapça metni: her arayüz dilinde sağa yaslı, kalın sistem fontu
/// (RN'de dualar Kur'an fontuyla değil sistem fontuyla çizilir).
struct ArabicText: View {
  @Environment(\.tokens) private var tokens
  let text: String
  var size: CGFloat
  var lineHeight: CGFloat

  init(_ text: String, size: CGFloat, lineHeight: CGFloat) {
    self.text = text
    self.size = size
    self.lineHeight = lineHeight
  }

  var body: some View {
    Text(text)
      .font(.system(size: size, weight: .bold))
      .lineSpacing(max(0, lineHeight - size * 1.2))
      .foregroundStyle(tokens.isDark ? .white : Forest.s900)
      // RTL ortamında "leading" sağdır.
      .multilineTextAlignment(.leading)
      .frame(maxWidth: .infinity, alignment: .leading)
      .environment(\.layoutDirection, .rightToLeft)
  }
}

/// Duruma göre dua önerisi: hızlı ruh hâli çipleri (anında, çevrimdışı) + serbest metin → AI.
/// AI kapalı/başarısızsa anahtar kelime eşleşmesine düşer. RN: components/dua/DuaMoodFinder.tsx
private struct DuaMoodFinder: View {
  @Environment(\.tokens) private var tokens
  let onSelect: (Dua) -> Void
  @State private var activeKey: String?
  @State private var text = ""
  @State private var loading = false
  @State private var suggestion: (message: String?, duas: [Dua])?

  var body: some View {
    let dark = tokens.isDark
    let accent = dark ? Accent.s400 : Accent.s600
    let canAsk = !text.trimmingCharacters(in: .whitespaces).isEmpty

    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 7) {
        Ionicon("sparkles", size: 16, color: accent)
        Text(t("dua.mood.title")).font(.system(size: 12.25, weight: .semibold)).foregroundStyle(dark ? .white : Forest.s900)
      }
      .padding(.bottom, 10.5)
      Text(t("dua.mood.subtitle")).font(.system(size: 10.5)).foregroundStyle(tokens.textSecondary).padding(.bottom, 10.5)

      FlowLayout(spacing: 7) {
        ForEach(DuaLibrary.situations) { s in
          let active = activeKey == s.key
          Button {
            Haptics.impact(.light)
            activeKey = s.key
            suggestion = (nil, DuaLibrary.duas(ids: s.duaIds))
          } label: {
            HStack(spacing: 5.25) {
              Ionicon(s.icon, size: 13, color: active ? (dark ? Forest.s950 : .white) : accent)
              Text(s.label).font(.system(size: 13, weight: .medium))
                .foregroundStyle(active ? (dark ? Forest.s950 : .white) : (dark ? Forest.s300 : Forest.s700))
            }
            .padding(.horizontal, 10.5)
            .padding(.vertical, 7)
            .background(active ? tokens.accent : tokens.fill, in: .capsule)
          }
          .buttonStyle(PressableStyle())
          .accessibilityAddTraits(active ? .isSelected : [])
        }
      }

      HStack(spacing: 7) {
        TextField("", text: $text, prompt: Text(t("dua.mood.placeholder")).foregroundStyle(dark ? Forest.s600 : Forest.s400))
          .font(.system(size: 12.25))
          .foregroundStyle(dark ? .white : Forest.s900)
          .tint(tokens.accent)
          .submitLabel(.search)
          .onSubmit { Task { await ask() } }
          .frame(height: 35)
        Button {
          Task { await ask() }
        } label: {
          Group {
            if loading {
              ProgressView().tint(.white).controlSize(.small)
            } else {
              Text(t("dua.mood.suggest")).font(.system(size: 10.5, weight: .semibold)).foregroundStyle(.white)
            }
          }
          .padding(.horizontal, 10.5)
          .frame(height: 31.5)
          .background(canAsk ? (dark ? Accent.s500 : Accent.s600) : (dark ? Forest.s700 : Forest.s200), in: .rect(cornerRadius: 10.5))
        }
        .buttonStyle(PressableStyle())
        .disabled(!canAsk || loading)
      }
      .padding(.horizontal, 10.5)
      .padding(.vertical, 3.5)
      .background(tokens.surface, in: .rect(cornerRadius: 21))
      .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
      .padding(.top, 10.5)

      if let suggestion {
        VStack(alignment: .leading, spacing: 7) {
          if let message = suggestion.message, !message.isEmpty {
            MarkdownText(text: message, size: 12, color: dark ? Accent.s200 : Accent.s800, italic: true)
          }
          ForEach(suggestion.duas) { dua in
            Button {
              Haptics.impact(.light)
              onSelect(dua)
            } label: {
              HStack {
                Text(dua.title).font(.system(size: 12.25, weight: .bold)).foregroundStyle(dark ? .white : Forest.s900)
                  .lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                Ionicon(dirIcon("chevron-forward"), size: 16, color: accent)
              }
              .padding(.horizontal, 14)
              .padding(.vertical, 10.5)
              .background(tokens.surface, in: .rect(cornerRadius: 21))
              .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
            }
            .buttonStyle(PressableStyle())
          }
        }
        .padding(.top, 10.5)
      }
    }
    .padding(14)
    .background(dark ? Accent.s500.opacity(0.1) : Accent.s50.opacity(0.6), in: .rect(cornerRadius: 14))
    .overlay(RoundedRectangle(cornerRadius: 14).stroke(dark ? Accent.s800 : Accent.s100, lineWidth: 1))
  }

  private func ask() async {
    let feeling = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !feeling.isEmpty, !loading else { return }
    Haptics.impact(.medium)
    loading = true
    activeKey = nil
    defer { loading = false }
    if let ai = await DuaLibrary.suggest(feeling: feeling) {
      suggestion = (ai.message, ai.duas)
    } else if let situation = DuaLibrary.matchSituation(feeling) {
      suggestion = (t("dua.mood.matched", ["label": situation.label]), DuaLibrary.duas(ids: situation.duaIds))
    } else {
      suggestion = (t("dua.mood.fallback"), DuaLibrary.duas(ids: ["genel-1", "genel-2"]))
    }
  }
}
