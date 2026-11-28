import SwiftUI

/// Duvar kağıdı: içerik (ayet, dua, Esma) + tasarım seç, önizle, fotoğraflara kaydet ya da paylaş.
struct WallpaperView: View {
  @Environment(\.tokens) private var tokens

  enum Source: String, CaseIterable, Identifiable {
    case verse, dua, esma
    var id: String { rawValue }
    var title: String { t("wallpaper.source.\(rawValue)") }
  }

  /// Meal ya da anlam bu uzunluğu aşan öğe listede gösterilmez.
  private static let maxText = 220
  private static let maxArabic = 350

  let seed: TopicRef?
  @State private var source: Source
  @State private var design: CardDesign
  @State private var selected: WallpaperContent?
  @State private var pinned: WallpaperContent?
  @State private var topicID = TopicCatalog.all.first?.id ?? ""
  @State private var verseItems: [WallpaperContent] = []
  @State private var loading = false
  @State private var categoryID = DuaLibrary.categories.first?.id ?? ""
  @State private var saving = false
  @State private var shareItems: ShareItems?

  private struct ShareItems: Identifiable {
    let id = UUID()
    var values: [Any]
  }

  init(seed: TopicRef? = nil) {
    self.seed = seed
    _source = State(initialValue: Source(rawValue: DebugLaunch.wallpaper ?? "") ?? .verse)
    _design = State(initialValue: CardDesign(rawValue: DebugLaunch.design ?? "") ?? .orman)
  }

  private var previewSize: CGSize {
    let screen = WallpaperExport.screen.size
    let width: CGFloat = 150
    return CGSize(width: width, height: width * screen.height / screen.width)
  }

  var body: some View {
    VStack(spacing: 0) {
      StandardHeader(title: t("wallpaper.title")) { EmptyView() }
      ScrollView {
        VStack(spacing: 14) {
          HStack(alignment: .top, spacing: 14) {
            WallpaperCanvas(content: selected, design: design, size: previewSize)
              .clipShape(.rect(cornerRadius: 24))
              .overlay(RoundedRectangle(cornerRadius: 24).stroke(tokens.line, lineWidth: 1))
              .accessibilityHidden(true)
            VStack(spacing: 7) {
              SectionLabel(t("wallpaper.design.title"))
              ForEach(CardDesign.allCases) { item in designRow(item) }
            }
          }
          sourcePicker
          chips
          list
        }.padding(.horizontal, 14).padding(.top, 10.5).padding(.bottom, 14)
      }.scrollIndicators(.hidden)
      HStack(spacing: 10.5) {
        AppButton(title: t("common.share"), variant: .secondary, disabled: selected == nil || saving) { share() }
        AppButton(title: t("wallpaper.save"), loading: saving, disabled: selected == nil) { Task { await save() } }
      }.padding(.horizontal, 14).padding(.vertical, 10.5)
    }
    .background(tokens.canvas).toolbar(.hidden, for: .navigationBar)
    .task { await loadSeed() }
    .task(id: topicID) { await loadVerses() }
    .onChange(of: source) { selected = nil; ensureSelection() }
    .onChange(of: categoryID) { ensureSelection() }
    .sheet(item: $shareItems) { item in ShareSheet(items: item.values) }
  }

  // MARK: Seçiciler

  private func designRow(_ item: CardDesign) -> some View {
    let on = design == item
    return Button { Haptics.impact(.light); design = item } label: {
      HStack(spacing: 10.5) {
        Circle().fill(item.background).frame(width: 24, height: 24)
          .overlay(Circle().stroke(item.ornamentColor, lineWidth: 1))
        Text(item.title).font(.system(size: 15, weight: on ? .semibold : .regular)).foregroundStyle(tokens.textPrimary).lineLimit(1)
        Spacer(minLength: 0)
        if on { Ionicon("checkmark", size: 15, color: tokens.accent) }
      }.padding(.horizontal, 12).frame(height: 44)
        .background(tokens.surface, in: .rect(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(on ? tokens.accent : tokens.line, lineWidth: on ? 1.5 : 1))
    }.buttonStyle(PressableStyle()).accessibilityLabel(item.title).accessibilityAddTraits(on ? .isSelected : [])
  }

  private var sourcePicker: some View {
    HStack(spacing: 7) {
      ForEach(Source.allCases) { item in
        chip(item.title, on: source == item) { source = item }
      }
    }.frame(maxWidth: .infinity, alignment: .leading)
  }

  @ViewBuilder
  private var chips: some View {
    switch source {
    case .verse:
      chipRow(TopicCatalog.all.map { ($0.id, $0.title) }, current: topicID) { topicID = $0 }
    case .dua:
      chipRow(DuaLibrary.categories.map { ($0.id, $0.title) }, current: categoryID) { categoryID = $0 }
    case .esma:
      EmptyView()
    }
  }

  private func chipRow(_ items: [(String, String)], current: String, pick: @escaping (String) -> Void) -> some View {
    ScrollView(.horizontal) {
      HStack(spacing: 7) {
        ForEach(items, id: \.0) { item in chip(item.1, on: current == item.0) { pick(item.0) } }
      }
    }.scrollIndicators(.hidden)
  }

  private func chip(_ title: String, on: Bool, _ run: @escaping () -> Void) -> some View {
    Button { Haptics.impact(.light); run() } label: {
      Text(title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
        .foregroundStyle(on ? tokens.onAccent : tokens.textPrimary)
        .padding(.horizontal, 14).frame(height: 35)
        .background(on ? tokens.accent : tokens.surface, in: .capsule)
        .overlay(Capsule().stroke(on ? Color.clear : tokens.line, lineWidth: 1))
    }.buttonStyle(PressableStyle()).accessibilityAddTraits(on ? .isSelected : [])
  }

  // MARK: Liste

  private var items: [WallpaperContent] {
    switch source {
    case .verse:
      guard let pinned else { return verseItems }
      return [pinned] + verseItems.filter { $0.id != pinned.id }
    case .dua: return Self.duaItems(categoryID)
    case .esma: return Self.esmaItems()
    }
  }

  @ViewBuilder
  private var list: some View {
    let current = items
    if source == .verse && loading && current.isEmpty {
      ProgressView().frame(maxWidth: .infinity).padding(.vertical, 28)
    } else if current.isEmpty {
      QuranEmptyView(icon: "albums-outline", title: t("wallpaper.empty"))
    } else {
      LazyVStack(spacing: 10.5) {
        ForEach(current) { item in row(item) }
      }
    }
  }

  private func row(_ item: WallpaperContent) -> some View {
    let on = selected?.id == item.id
    return Button { Haptics.impact(.light); selected = item } label: {
      HStack(alignment: .top, spacing: 10.5) {
        VStack(alignment: .leading, spacing: 3.5) {
          if item.arabicLarge, let arabic = item.arabic {
            Text(arabic).font(.system(size: 22)).foregroundStyle(tokens.textPrimary).environment(\.layoutDirection, .rightToLeft)
          }
          Text(item.source).font(.system(size: 15, weight: .semibold)).foregroundStyle(tokens.textPrimary).lineLimit(1)
          if !item.text.isEmpty {
            Text(item.text).font(.system(size: 13)).foregroundStyle(tokens.textSecondary).lineLimit(2).multilineTextAlignment(.leading)
          }
        }.frame(maxWidth: .infinity, alignment: .leading)
        if on { Ionicon("checkmark-circle", size: 20, color: tokens.accent) }
      }.padding(14)
        .background(tokens.surface, in: .rect(cornerRadius: 21))
        .overlay(RoundedRectangle(cornerRadius: 21).stroke(on ? tokens.accent : tokens.line, lineWidth: on ? 1.5 : 1))
    }.buttonStyle(PressableStyle()).accessibilityAddTraits(on ? .isSelected : [])
  }

  // MARK: Veri

  private static func duaItems(_ categoryID: String) -> [WallpaperContent] {
    (DuaLibrary.categories.first { $0.id == categoryID }?.duas ?? []).compactMap { dua in
      let meaning = dua.turkish.isEmpty ? dua.title : dua.turkish
      guard meaning.count <= maxText, dua.arabic.count <= maxArabic else { return nil }
      return WallpaperContent(
        id: "dua:\(dua.id)", arabic: dua.arabic.isEmpty ? nil : dua.arabic, text: meaning,
        source: [dua.title, dua.source].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
    }
  }

  private static func esmaItems() -> [WallpaperContent] {
    let isRTL = Localizer.shared.language.isRTL
    return EsmaLibrary.names.compactMap { n in
      guard n.meaning.count <= maxText else { return nil }
      return WallpaperContent(id: "esma:\(n.id)", arabic: n.arabic, text: n.meaning, source: isRTL ? t("esma.title") : n.name, arabicLarge: true)
    }
  }

  private static func content(_ v: TopicVerseText) -> WallpaperContent {
    WallpaperContent(id: "verse:\(v.id)", arabic: v.arabic.isEmpty ? nil : v.arabic, text: v.text, source: v.source)
  }

  private func loadSeed() async {
    guard let seed, let verse = await TopicVerses.load(seed) else { ensureSelection(); return }
    let item = Self.content(verse)
    pinned = item
    selected = item
  }

  private func loadVerses() async {
    guard let topic = TopicCatalog.topic(topicID) else { return }
    loading = true
    verseItems = []
    var found: [Int: WallpaperContent] = [:]
    await withTaskGroup(of: (Int, TopicVerseText?).self) { group in
      for (index, ref) in topic.verses.enumerated() { group.addTask { (index, await TopicVerses.load(ref)) } }
      for await (index, verse) in group {
        if let verse, verse.text.count <= Self.maxText { found[index] = Self.content(verse) }
      }
    }
    guard !Task.isCancelled else { return }
    verseItems = found.keys.sorted().compactMap { found[$0] }
    loading = false
    ensureSelection()
  }

  /// Seçili öğe listede yoksa ilk öğeyi seç; önizleme hiç boş kalmasın.
  private func ensureSelection() {
    let current = items
    if let selected, current.contains(where: { $0.id == selected.id }) { return }
    selected = current.first
  }

  // MARK: Kaydet ve paylaş

  private func render() -> UIImage? {
    guard let selected else { return nil }
    return WallpaperExport.image(selected, design: design, tokens: tokens)
  }

  private func share() {
    Haptics.impact(.medium)
    guard let image = render() else { AppAlert.error(t("wallpaper.failed")); return }
    shareItems = ShareItems(values: [image])
  }

  private func save() async {
    Haptics.impact(.medium)
    guard let image = render() else { AppAlert.error(t("wallpaper.failed")); return }
    saving = true
    let result = await WallpaperExport.save(image)
    saving = false
    switch result {
    case .saved:
      Haptics.notify(.success)
      Toast.success(t("wallpaper.saved"))
    case .denied:
      Haptics.notify(.error)
      AppAlert.error(t("wallpaper.denied"), t("wallpaper.deniedHint"))
    case .failed:
      Haptics.notify(.error)
      AppAlert.error(t("wallpaper.failed"))
    }
  }
}
