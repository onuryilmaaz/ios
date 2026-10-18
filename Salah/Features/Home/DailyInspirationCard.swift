import SwiftUI

/// Günün ayeti ya da hadisi (rastgele). RN: components/home/DailyInspirationCard.tsx
@Observable
final class InspirationModel {
  struct Item: Equatable, Identifiable {
    var id: String { text }
    enum Kind { case verse, hadith }
    let kind: Kind
    let text: String
    let arabic: String
    let source: String
  }

  private(set) var current: Item? {
    didSet { if let current { Self.publish(current) } }
  }

  /// Kilit ekranı ilham widget'ı bugünün içeriğini gösterir.
  static func publish(_ item: Item) {
    WidgetBridge.updateInspiration(
      text: item.text, source: item.source, type: item.kind == .verse ? "ayet" : "hadis", arabic: item.arabic, date: localDateString())
  }
  private(set) var isLoading = false

  func load() async {
    guard !isLoading else { return }
    isLoading = true
    defer { isLoading = false }
    if Bool.random(), let r = await QuranService.randomVerse() {
      current = Item(
        kind: .verse,
        text: r.verse.translation.text,
        arabic: r.verse.verse_simplified,
        source: t("notif.verseRef", ["surah": surahName(r.surah, withSuffix: true), "verse": r.verse.verse_number])
      )
    } else if let h = await HadithService.random() {
      current = Item(kind: .hadith, text: h.text, arabic: "", source: h.bookName)
    }
  }
}

struct DailyInspirationCard: View {
  @Environment(\.tokens) private var tokens
  @State private var model = InspirationModel()
  @State private var expanded = false
  @State private var sharing: InspirationModel.Item?

  private static let longTextThreshold = 130

  var body: some View {
    Group {
      if let item = NotificationNavigation.shared.inspiration ?? model.current {
        card(item)
      } else if model.isLoading || model.current == nil {
        ProgressView()
          .tint(tokens.accent)
          .frame(maxWidth: .infinity, minHeight: 180)
          .background(tokens.surface, in: .rect(cornerRadius: 21))
          .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
      }
    }
    .padding(.horizontal, 14)
    .padding(.bottom, 10.5)
    .task {
      if NotificationNavigation.shared.inspiration != nil { expanded = true }
      else if model.current == nil { await model.load() }
    }
    .onChange(of: NotificationNavigation.shared.homeRequest) { expanded = true }
    .fullScreenCover(item: $sharing) { item in
      ShareCardSheet(
        arabic: item.arabic.isEmpty ? nil : item.arabic,
        text: item.text,
        source: item.source,
        label: t(item.kind == .verse ? "home.inspiration.verse" : "home.inspiration.hadith")
      )
      .environment(\.tokens, tokens)
    }
  }

  private func card(_ item: InspirationModel.Item) -> some View {
    Card {
      HStack {
        HStack(spacing: 7) {
          Ionicon(item.kind == .verse ? "book" : "chatbubble-ellipses", size: 15, color: tokens.gold)
          Text(t(item.kind == .verse ? "home.inspiration.verse" : "home.inspiration.hadith"))
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(tokens.textPrimary)
            .accessibilityAddTraits(.isHeader)
        }
        Spacer()
        Button {
          Haptics.impact(.light)
          sharing = item
        } label: {
          Ionicon("share-outline", size: 17, color: tokens.inkMuted)
            .frame(width: 31.5, height: 31.5)
            .background(tokens.fill, in: .circle)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(t("common.share"))
        .padding(.trailing, 7)
        Button {
          Haptics.impact(.light)
          expanded = false
          NotificationNavigation.shared.clear()
          Task { await model.load() }
        } label: {
          Group {
            if model.isLoading {
              ProgressView().controlSize(.small).tint(tokens.inkMuted)
            } else {
              Ionicon("refresh-outline", size: 17, color: tokens.inkMuted)
            }
          }
          .frame(width: 31.5, height: 31.5)
          .background(tokens.fill, in: .circle)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(t("home.inspiration.refresh"))
      }
      .padding(.bottom, 10.5)

      VStack(alignment: .leading, spacing: 0) {
        if !item.arabic.isEmpty {
          Text(QuranFont.text(item.arabic))
            .font(.custom(QuranFont.name, size: 24))
            .lineSpacing(12)
            .foregroundStyle(tokens.isDark ? Forest.s100 : Forest.s900)
            // Ayet her arayüz dilinde sağa yaslı: RTL ortamında "leading" sağdır.
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.layoutDirection, .rightToLeft)
            .padding(.bottom, 14)
        }

        Text(item.text)
          .font(.system(size: 16))
          .lineSpacing(6)
          .foregroundStyle(tokens.isDark ? Forest.s300 : Forest.s700)
          .lineLimit(expanded ? nil : 4)

        if item.text.count > Self.longTextThreshold {
          Button {
            Haptics.impact(.light)
            expanded.toggle()
          } label: {
            Text(t(expanded ? "home.inspiration.showLess" : "home.inspiration.readMore"))
              .font(.system(size: 15, weight: .medium))
              .foregroundStyle(tokens.isDark ? Accent.s400 : Accent.s700)
          }
          .buttonStyle(PressableStyle())
          .padding(.top, 7)
        }

        Text(item.source)
          .font(.system(size: 13))
          .foregroundStyle(tokens.textSecondary)
          .padding(.top, 14)
      }
      .id(item.text)
      .transition(.opacity)
      .animation(.easeOut(duration: 0.3), value: item.text)
    }
  }
}
