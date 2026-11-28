import SwiftUI

/// Kur'an sekmesinin üstündeki yatay "Keşfet" satırı. Yeni bölümler (Kıssalar, Günün okuması, ...) `items`e eklenir.
struct QuranDiscoverRow: View {
  @Environment(\.tokens) private var tokens

  struct Item: Identifiable {
    let id: String
    let icon: String
    let title: String
    let route: QuranRoute
  }

  var items: [Item]
  var open: (QuranRoute) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      SectionLabel(t("discover.title"))
      ScrollView(.horizontal) {
        HStack(spacing: 10.5) {
          ForEach(items) { item in
            Button { Haptics.impact(.light); open(item.route) } label: {
              HStack(spacing: 10.5) {
                Ionicon(item.icon, size: 19, color: tokens.accent).frame(width: 38, height: 38)
                  .background(tokens.accent.opacity(0.12), in: .circle)
                Text(item.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(tokens.textPrimary).lineLimit(1)
                Ionicon(dirIcon("chevron-forward"), size: 15, color: tokens.inkSubtle)
              }.padding(.vertical, 10.5).padding(.leading, 10.5).padding(.trailing, 14)
                .background(tokens.surface, in: .rect(cornerRadius: 21))
                .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
            }.buttonStyle(PressableStyle()).accessibilityLabel(item.title)
          }
        }
      }.scrollIndicators(.hidden)
    }.padding(.bottom, 14)
  }
}

/// Konu ızgarası; üstte kaydedilen ayetler satırı.
struct TopicsView: View {
  @Environment(\.tokens) private var tokens
  @Bindable private var nav = QuranNavigation.shared
  private let saved = TopicSavedStore.shared

  private let columns = [GridItem(.flexible(), spacing: 10.5), GridItem(.flexible(), spacing: 10.5)]

  var body: some View {
    VStack(spacing: 0) {
      StandardHeader(title: t("topics.title")) { EmptyView() }
      ScrollView {
        VStack(spacing: 10.5) {
          if !saved.ids.isEmpty { savedRow }
          if TopicCatalog.all.isEmpty {
            QuranEmptyView(icon: "albums-outline", title: t("topics.emptyTopic"))
          } else {
            LazyVGrid(columns: columns, spacing: 10.5) {
              ForEach(TopicCatalog.all) { topic in tile(topic) }
            }
          }
        }.padding(.horizontal, 14).padding(.top, 10.5).padding(.bottom, 24)
      }.scrollIndicators(.hidden)
    }.background(tokens.canvas).toolbar(.hidden, for: .navigationBar)
  }

  private var savedRow: some View {
    Button { Haptics.impact(.light); nav.path.append(.topicsSaved) } label: {
      HStack(spacing: 10.5) {
        Ionicon("bookmark", size: 19, color: tokens.gold).frame(width: 38, height: 38)
          .background(tokens.isDark ? Gold.s700.opacity(0.2) : Gold.s50, in: .circle)
        VStack(alignment: .leading, spacing: 1.75) {
          Text(t("topics.saved")).font(.system(size: 17, weight: .semibold)).foregroundStyle(tokens.textPrimary)
          Text(t("topics.count", ["count": saved.ids.count])).font(.system(size: 13)).foregroundStyle(tokens.textSecondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
        Ionicon(dirIcon("chevron-forward"), size: 18, color: tokens.inkSubtle)
      }.padding(14).background(tokens.surface, in: .rect(cornerRadius: 21))
        .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
    }.buttonStyle(PressableStyle())
  }

  private func tile(_ topic: Topic) -> some View {
    Button { Haptics.impact(.light); nav.path.append(.topic(topic.id)) } label: {
      VStack(alignment: .leading, spacing: 0) {
        Ionicon(topic.icon, size: 21, color: tokens.accent).frame(width: 42, height: 42)
          .background(tokens.accent.opacity(0.12), in: .circle)
        Text(topic.title).font(.system(size: 17, weight: .semibold)).foregroundStyle(tokens.textPrimary).lineLimit(1).padding(.top, 12)
        Text(topic.sub).font(.system(size: 13)).foregroundStyle(tokens.textSecondary).lineLimit(2, reservesSpace: true)
          .multilineTextAlignment(.leading).padding(.top, 2)
        Text(t("topics.count", ["count": topic.verses.count])).font(.system(size: 13, weight: .medium)).foregroundStyle(tokens.inkMuted).padding(.top, 6)
      }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(tokens.surface, in: .rect(cornerRadius: 21))
        .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
    }.buttonStyle(PressableStyle())
      .accessibilityLabel("\(topic.title), \(t("topics.count", ["count": topic.verses.count]))")
  }
}

/// Bir konunun (ya da kaydedilenlerin) ayet listesi.
struct TopicDetailView: View {
  @Environment(\.tokens) private var tokens
  let topicID: String?
  /// Kaydedilenler görünümünde canlı liste, konuda sabit liste.
  private let saved = TopicSavedStore.shared

  private var topic: Topic? { topicID.flatMap(TopicCatalog.topic) }
  private var refs: [TopicRef] { topicID == nil ? saved.refs : (topic?.verses ?? []) }

  var body: some View {
    VStack(spacing: 0) {
      StandardHeader(title: topic?.title ?? t("topics.saved")) { EmptyView() }
      ScrollView {
        LazyVStack(spacing: 10.5) {
          if let topic {
            Text(topic.sub).font(.system(size: 14)).foregroundStyle(tokens.textSecondary)
              .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 3.5).padding(.bottom, 3.5)
          }
          if refs.isEmpty {
            QuranEmptyView(icon: topicID == nil ? "bookmark-outline" : "albums-outline",
                           title: topicID == nil ? t("topics.savedEmpty") : t("topics.emptyTopic"),
                           message: topicID == nil ? t("topics.savedEmptyHint") : "")
          }
          ForEach(refs) { ref in TopicVerseCard(ref: ref).id(ref.id) }
        }.padding(.horizontal, 14).padding(.top, 10.5).padding(.bottom, 24)
      }.scrollIndicators(.hidden)
    }.background(tokens.canvas).toolbar(.hidden, for: .navigationBar)
  }
}

struct TopicVerseCard: View {
  @Environment(\.tokens) private var tokens
  let ref: TopicRef
  /// Önceden çekilmiş metin (kıssa bölümü: sure bazında bir kez yüklenir).
  var preloaded: TopicVerseText?
  /// Mushaf, sure ve duvar kağıdı bağlantıları Kur'an sekmesi yığınına gider; ana sayfada kapalı.
  var links = true
  @State private var verse: TopicVerseText?
  @State private var failed = false
  @State private var sharing: TopicVerseText?
  private let saved = TopicSavedStore.shared

  var body: some View {
    Card {
      if let verse { content(verse) }
      else if failed { errorView }
      else { skeleton }
    }
    .task(id: Localizer.shared.language) { await load() }
    .fullScreenCover(item: $sharing) { item in
      ShareCardSheet(arabic: item.arabic.isEmpty ? nil : item.arabic, text: item.text, source: item.source, label: t("home.inspiration.verse"))
        .environment(\.tokens, tokens)
    }
  }

  private func load() async {
    failed = false
    if let preloaded { verse = preloaded; return }
    if let loaded = await TopicVerses.load(ref) { verse = loaded } else if verse == nil { failed = true }
  }

  private func content(_ item: TopicVerseText) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 7) {
        Text(item.source).font(.system(size: 17, weight: .semibold)).foregroundStyle(tokens.textPrimary).lineLimit(1)
          .frame(maxWidth: .infinity, alignment: .leading).accessibilityAddTraits(.isHeader)
        if links { Menu {
          if let page = item.page {
            Button(t("topics.openMushaf")) { Haptics.impact(.light); QuranNavigation.shared.mushaf = .init(id: page) }
          }
          if AppControlStore.shared.isOn("wallpapers") {
            Button(t("topics.wallpaper")) { Haptics.impact(.light); QuranNavigation.shared.path.append(.wallpaper(ref)) }
          }
        } label: {
          Ionicon("ellipsis-horizontal", size: 17, color: tokens.inkMuted).frame(width: 31.5, height: 31.5).background(tokens.fill, in: .circle)
        }.accessibilityLabel(t("topics.more")) }
        action("share-outline", label: t("common.share")) { Haptics.impact(.light); sharing = item }
        action(saved.isSaved(ref) ? "bookmark" : "bookmark-outline", label: t(saved.isSaved(ref) ? "topics.unsave" : "topics.save"),
               color: saved.isSaved(ref) ? tokens.gold : tokens.inkMuted) {
          Haptics.impact(.medium)
          saved.toggle(ref)
        }
      }.padding(.bottom, 10.5)
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
      Text(item.text).font(.system(size: 16)).lineSpacing(6).foregroundStyle(tokens.isDark ? Forest.s300 : Forest.s700)
      if links {
        Button {
          Haptics.impact(.light)
          QuranNavigation.shared.path.append(.surah(ref.s, ref.a))
        } label: {
          HStack(spacing: 3.5) {
            Text(t("topics.goToSurah")).font(.system(size: 14, weight: .semibold))
            Ionicon(dirIcon("chevron-forward"), size: 13, color: tokens.accent)
          }.foregroundStyle(tokens.accent).padding(.top, 12)
        }.buttonStyle(PressableStyle())
      }
    }
  }

  private func action(_ icon: String, label: String, color: Color? = nil, _ run: @escaping () -> Void) -> some View {
    Button(action: run) {
      Ionicon(icon, size: 17, color: color ?? tokens.inkMuted).frame(width: 31.5, height: 31.5).background(tokens.fill, in: .circle)
    }.buttonStyle(PressableStyle()).accessibilityLabel(label)
  }

  private var skeleton: some View {
    VStack(alignment: .leading, spacing: 10.5) {
      RoundedRectangle(cornerRadius: 4).fill(tokens.fill).frame(width: 110, height: 16)
      RoundedRectangle(cornerRadius: 4).fill(tokens.fill).frame(height: 26)
      RoundedRectangle(cornerRadius: 4).fill(tokens.fill).frame(height: 14)
      RoundedRectangle(cornerRadius: 4).fill(tokens.fill).frame(width: 180, height: 14)
    }.frame(maxWidth: .infinity, alignment: .leading).accessibilityHidden(true)
  }

  private var errorView: some View {
    VStack(spacing: 10.5) {
      QuranEmptyView(icon: "cloud-offline-outline", title: t("topics.loadFailed"))
      AppButton(title: t("common.retry"), variant: .secondary) { Task { await load() } }
    }
  }
}
