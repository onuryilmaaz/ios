import SwiftUI
import UIKit

/// Yalnız Mushaf'ta yatay okumaya izin verilir; kapatılınca dikeye dönülür.
enum ReadingOrientation {
  static var mask: UIInterfaceOrientationMask = .portrait
  static func set(_ value: UIInterfaceOrientationMask) {
    mask = value
    for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
      scene.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
      scene.requestGeometryUpdate(.iOS(interfaceOrientations: value))
    }
  }
}

struct MushafReaderView: View {
  @Environment(\.tokens) private var tokens
  @Environment(\.dismiss) private var dismiss
  let initialPage: Int
  @State private var page = 1
  @State private var chrome = true
  @State private var picker = false
  @State private var themes = false
  @State private var surahs: [Surah] = []
  @State private var detail: Verse?
  @State private var initialized = false

  /// Sayfalar yatayda tam ekran genişliğine yerleşir (yan boşluk sayfada `side` ile verilir);
  /// GeometryReader'ın genişliği güvenli alan çıkarılmış hali olduğundan onu kullanınca
  /// yatayda sayfa dar hesaplanıp sola kayıyordu. Yükseklik kabın kendisiyle aynı kalır.
  private func fullSize(_ g: GeometryProxy) -> CGSize {
    CGSize(width: g.size.width + g.safeAreaInsets.leading + g.safeAreaInsets.trailing, height: g.size.height)
  }

  private var currentSurah: Surah? { surahs.last { ($0.page_number ?? 1) <= page } }
  private var palette: MushafPalette { .init(theme: QuranReadingStore.shared.mushafTheme, appIsDark: tokens.isDark) }

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .top) {
        palette.canvas.ignoresSafeArea()
        TabView(selection: $page) {
          ForEach(1...604, id: \.self) { number in
            MushafPageView(page: number, size: fullSize(geometry), insets: geometry.safeAreaInsets, surahs: surahs,
              palette: palette, selectedVerse: detail.map { "\($0.surah_id):\($0.verse_number)" },
              onTap: { withAnimation(.easeInOut(duration: 0.18)) { chrome.toggle() } }, onVerse: { key, text in openVerse(key, text: text) })
              .environment(\.layoutDirection, Localizer.shared.layoutDirection).tag(number)
          }
        }
        .tabViewStyle(.page(indexDisplayMode: .never)).environment(\.layoutDirection, .rightToLeft)
        .ignoresSafeArea()
        if chrome {
          HStack(spacing: 7) {
            CircleIconButton(icon: "close", size: 35, iconSize: 20, accessibilityLabel: t("common.close")) { Haptics.impact(.light); dismiss() }
            VStack(spacing: 2) {
              Text(currentSurah.map { surahName($0, withSuffix: true) } ?? t("mushaf.title"))
                .font(.system(size: 16, weight: .semibold)).foregroundStyle(tokens.textPrimary).lineLimit(1)
              Text(t("mushaf.page", ["page": page, "total": 604])).font(.system(size: 12)).monospacedDigit().foregroundStyle(tokens.textSecondary)
            }.frame(maxWidth: .infinity)
            if let mark = QuranReadingStore.shared.mushafMark, mark.page != page {
              CircleIconButton(icon: "bookmark", size: 35, iconSize: 17, color: tokens.gold, accessibilityLabel: t("mushaf.goToMark", ["page": mark.page])) {
                Haptics.impact(.light); page = mark.page
              }
            }
            CircleIconButton(icon: "contrast-outline", size: 35, iconSize: 18, accessibilityLabel: t("mushaf.theme")) { Haptics.impact(.light); themes = true }
            CircleIconButton(icon: "list", size: 35, iconSize: 19, accessibilityLabel: t("mushaf.chooseSurah")) { Haptics.impact(.light); picker = true }
          }.padding(.horizontal, 14).padding(.top, geometry.safeAreaInsets.top + 6).padding(.bottom, 10.5)
            .background(tokens.canvas).overlay(alignment: .bottom) { RowDivider(leading: 0) }.ignoresSafeArea(edges: .top)
        }
        if chrome {
          HStack(spacing: 5.25) {
            Ionicon("information-circle-outline", size: 13, color: .white)
            Text(t("mushaf.hint")).font(.system(size: 12, weight: .medium)).foregroundStyle(.white)
          }.padding(.horizontal, 12.25).padding(.vertical, 7).background(Forest.s900.opacity(0.85), in: .capsule)
            .frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, 44).allowsHitTesting(false)
        }
      }
      .statusBarHidden(!chrome)
      .statusBar(palette.isDark ? .light : .dark)
    }
    .onAppear {
      guard !initialized else { return }
      initialized = true
      page = min(604, max(1, initialPage))
      QuranReadingStore.shared.setPage(page)
      ReadingOrientation.set(.allButUpsideDown)
    }
    .onDisappear { ReadingOrientation.set(.portrait); StatusBarStyle.apply() }
    .task {
      surahs = await QuranService.surahs()
      MushafService.prefetch(page)
      if DebugLaunch.quran == nil {
        try? await Task.sleep(for: .milliseconds(2500))
        if !Task.isCancelled { withAnimation { chrome = false } }
      }
    }
    .onChange(of: page) { _, value in Haptics.impact(.light); QuranReadingStore.shared.setPage(value); MushafService.prefetch(value) }
    .sheet(isPresented: $themes) { themePicker.presentationDetents([.height(220)]).presentationDragIndicator(.visible) }
    .sheet(isPresented: $picker) { surahPicker }
    .sheet(item: $detail) { verse in
      VerseDetailView(surahID: verse.surah_id, name: surahs.first(where: { $0.id == verse.surah_id }).map { surahName($0) } ?? "", verse: verse).environment(\.tokens, tokens)
    }
  }

  private var themePicker: some View {
    VStack(alignment: .leading, spacing: 17.5) {
      Text(t("mushaf.theme")).font(.system(size: 17, weight: .semibold)).foregroundStyle(tokens.textPrimary)
      HStack(spacing: 7) {
        ForEach(MushafTheme.allCases, id: \.self) { theme in
          let selected = QuranReadingStore.shared.mushafTheme == theme
          Button { Haptics.impact(.light); QuranReadingStore.shared.setTheme(theme) } label: {
            VStack(spacing: 7) {
              Group {
                if theme == .auto { Ionicon("phone-portrait-outline", size: 18, color: Forest.s500) }
                else { Text("بِسۡمِ").font(.custom(QuranFont.name, size: 18)).foregroundStyle(MushafPalette(theme: theme, appIsDark: false).ink) }
              }.frame(maxWidth: .infinity).frame(height: 49)
                .background(MushafPalette(theme: theme, appIsDark: false).canvas, in: .rect(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? tokens.accent : tokens.line, lineWidth: 2))
              Text(t("mushaf.themes.\(theme.rawValue)")).font(.system(size: 13, weight: selected ? .semibold : .regular)).foregroundStyle(selected ? tokens.textPrimary : tokens.textSecondary)
            }
          }.buttonStyle(PressableStyle()).accessibilityAddTraits(selected ? .isSelected : [])
        }
      }
      Spacer(minLength: 0)
    }.padding(17.5).background(tokens.surface)
  }

  private var surahPicker: some View {
    VStack(spacing: 0) {
      HStack {
        Text(t("mushaf.chooseSurah")).font(.system(size: 20, weight: .bold)).foregroundStyle(tokens.textPrimary)
        Spacer()
        Button { Haptics.impact(.light); picker = false } label: { Text(t("common.close")).foregroundStyle(tokens.accent) }
      }.padding(17.5)
      ScrollView {
        LazyVStack(spacing: 0) {
          ForEach(surahs) { surah in
            Button {
              Haptics.impact(.light); page = min(604, max(1, surah.page_number ?? 1)); picker = false
            } label: {
              HStack {
                Text("\(surah.id)").frame(width: 31.5, alignment: .leading).foregroundStyle(tokens.inkSubtle)
                Text(surahName(surah)).foregroundStyle(currentSurah?.id == surah.id ? tokens.accent : tokens.textPrimary).frame(maxWidth: .infinity, alignment: .leading)
                Text(t("mushaf.pageShort", ["page": surah.page_number ?? 1])).font(.system(size: 13)).foregroundStyle(tokens.textSecondary)
              }.font(.system(size: 14)).padding(.vertical, 12.25).contentShape(.rect)
            }.buttonStyle(PressableStyle())
            RowDivider(leading: 36)
          }
        }.padding(.horizontal, 16).padding(.bottom, 24)
      }.scrollIndicators(.hidden)
    }.background(tokens.canvas)
  }

  private func openVerse(_ key: String, text: String) {
    let parts = key.split(separator: ":").compactMap { Int($0) }
    guard parts.count == 2 else { return }
    Haptics.impact(.light)
    // Önce sayfadaki metin, sheet içinde tam ayet alınır (önceki sayfadan devam edebilir).
    detail = Verse(id: parts[0] * 1000 + parts[1], surah_id: parts[0], verse_number: parts[1], verse_simplified: text,
      page_number: page, juz_number: nil, transcription: nil, translation: .init(id: nil, text: "", author: nil))
  }
}

private struct MushafPageView: View {
  let page: Int
  let size: CGSize
  let insets: EdgeInsets
  let surahs: [Surah]
  let palette: MushafPalette
  let selectedVerse: String?
  let onTap: () -> Void
  let onVerse: (String, String) -> Void
  @State private var data: MushafPage?
  @State private var failed = false
  @State private var attempt = 0
  @Environment(\.tokens) private var tokens

  var body: some View {
    let landscape = size.width > size.height
    let side = max(insets.leading, insets.trailing)
    let contentW = size.width - 2 * (18 + side)
    let available = max(240, size.height - insets.top - insets.bottom - 72)
    let font = landscape ? contentW / 18.6 : min(contentW / 18.6, available / 30)
    let lineH = landscape ? font * 2 : available / 15
    let bodyHeight = max(size.height, insets.top + insets.bottom + 72 + lineH * 15)
    ZoomingQuranPage(width: size.width, height: bodyHeight, background: UIColor(palette.canvas)) {
      VStack(spacing: 0) {
        HStack {
          Text(data.map { t("mushaf.juz", ["juz": $0.juz]) } ?? " ")
          Spacer()
          Text(data.flatMap { d in surahs.first { $0.id == d.surahId } }.map { surahName($0, withSuffix: true) } ?? " ")
        }.font(.system(size: 12)).foregroundStyle(palette.muted).frame(height: 28)
        if let data {
          VStack(spacing: 0) {
            if data.centered { Spacer(minLength: 0) }
            ForEach(Array(data.lines.enumerated()), id: \.offset) { index, line in
              lineView(line, index: index, pageData: data, font: font).frame(height: lineH)
            }
            if data.centered { Spacer(minLength: 0) }
          }.frame(height: lineH * 15)
        } else if failed {
          VStack(spacing: 14) {
            Ionicon("cloud-offline-outline", size: 32, color: palette.muted)
            Text(t("mushaf.loadFailed")).font(.system(size: 15)).foregroundStyle(palette.muted).multilineTextAlignment(.center)
            AppButton(title: t("common.retry"), variant: .secondary) { attempt += 1 }.frame(width: 160)
          }.frame(height: lineH * 15)
        } else {
          VStack { ForEach(0..<15) { _ in Capsule().fill(palette.muted.opacity(0.15)).frame(height: 12).frame(maxHeight: .infinity) } }.frame(height: lineH * 15)
        }
        Text("\(page)").font(.system(size: 12)).monospacedDigit().foregroundStyle(palette.muted).frame(height: 28)
      }
      .padding(.horizontal, 18 + side).padding(.top, insets.top + 8).padding(.bottom, insets.bottom + 8)
      .frame(width: size.width, height: bodyHeight).background(palette.canvas)
      .contentShape(.rect).onTapGesture { onTap() }
      .environment(\.tokens, tokens)
    }
    .task(id: attempt) {
      failed = false
      do { let result = try await MushafService.page(page); if !Task.isCancelled { data = result } }
      catch { if !Task.isCancelled { failed = true } }
    }
    .accessibilityLabel(t("mushaf.pageA11y", ["page": page]))
  }

  private func lineView(_ line: MushafLine, index: Int, pageData: MushafPage, font: Double) -> some View {
    let mark = QuranReadingStore.shared.mushafMark
    let marked = mark?.page == page && mark?.line == index
    return ZStack(alignment: .trailing) {
      Group {
        if line.kind == "header" {
          Text(surahs.first(where: { $0.id == line.surahId })?.name_arabic ?? " ")
            .font(.custom(QuranFont.name, size: font * 0.95)).foregroundStyle(palette.ink)
            .frame(minWidth: size.width * 0.55).padding(.horizontal, 21).padding(.vertical, 1.75)
            .background(palette.header, in: .capsule).overlay(Capsule().stroke(palette.border, lineWidth: 1))
        } else if line.kind == "basmala" {
          Text(QuranFont.text(QuranScripture.basmala)).font(.custom(QuranFont.name, size: font)).foregroundStyle(palette.ink)
        } else {
          HStack(spacing: pageData.centered ? font * 0.3 : 0) {
            ForEach(Array((line.words ?? []).enumerated()), id: \.offset) { index, word in
              Text(QuranFont.text(word.text)).font(.custom(QuranFont.name, size: font)).foregroundStyle(word.isEnd ? palette.gold : word.verse == selectedVerse ? palette.accent : palette.ink)
                .fixedSize().onTapGesture {
                  if word.isEnd {
                    onVerse(word.verse, verseText(word.verse, pageData: pageData))
                  } else { onTap() }
                }
                .accessibilityLabel(word.isEnd ? t("mushaf.verseA11y", ["verse": word.verse.split(separator: ":").last.map(String.init) ?? ""]) : word.text)
              if !pageData.centered && index < (line.words?.count ?? 0) - 1 { Spacer(minLength: 0) }
            }
          }.environment(\.layoutDirection, .rightToLeft).frame(maxWidth: .infinity, alignment: .center)
        }
      }.frame(maxWidth: .infinity)
      if marked { Ionicon("bookmark", size: 14, color: palette.gold).offset(x: 14) }
    }
    .background(marked ? palette.mark : .clear, in: .rect(cornerRadius: 7)).contentShape(.rect)
    .onLongPressGesture(minimumDuration: 0.35) {
      QuranReadingStore.shared.toggleMark(page: page, line: index)
      if marked { Haptics.impact(.light); Toast.info(t("mushaf.markRemoved")) }
      else { Haptics.notify(.success); Toast.success(t("mushaf.marked"), t("mushaf.markedDetail", ["page": page, "line": index + 1])) }
    }
    .accessibilityLabel(t(marked ? "mushaf.lineMarkedA11y" : "mushaf.lineA11y", ["line": index + 1]))
    .accessibilityHint(t("mushaf.markHint"))
  }

  private func verseText(_ key: String, pageData: MushafPage) -> String {
    var parts: [String] = []
    for line in pageData.lines {
      for word in line.words ?? [] where word.verse == key && !word.isEnd { parts.append(word.text) }
    }
    return parts.joined(separator: " ")
  }
}

/// UIKit'in gerçek zoom davranışı; sayfa yakınlaştırıldığında yatay/dikey kaydırılır.
private struct ZoomingQuranPage<Content: View>: UIViewRepresentable {
  var width: CGFloat
  var height: CGFloat
  var background: UIColor
  @ViewBuilder var content: Content
  func makeCoordinator() -> QuranZoomCoordinator { QuranZoomCoordinator(content: AnyView(content)) }
  func makeUIView(context: Context) -> UIScrollView {
    let scroll = UIScrollView()
    scroll.delegate = context.coordinator
    scroll.minimumZoomScale = 1
    scroll.maximumZoomScale = 1.8
    scroll.showsHorizontalScrollIndicator = false
    scroll.showsVerticalScrollIndicator = false
    scroll.contentInsetAdjustmentBehavior = .never
    scroll.addSubview(context.coordinator.host.view)
    return scroll
  }
  func updateUIView(_ scroll: UIScrollView, context: Context) {
    context.coordinator.host.rootView = AnyView(content)
    let changed = context.coordinator.lastSize != CGSize(width: width, height: height)
    if changed {
      scroll.setZoomScale(1, animated: false)
      context.coordinator.host.view.frame = CGRect(x: 0, y: 0, width: width, height: height)
      context.coordinator.lastSize = CGSize(width: width, height: height)
    }
    context.coordinator.host.view.backgroundColor = background
    scroll.contentSize = CGSize(width: width * scroll.zoomScale, height: height * scroll.zoomScale)
    scroll.backgroundColor = background
  }
}

private final class QuranZoomCoordinator: NSObject, UIScrollViewDelegate {
  let host: UIHostingController<AnyView>
  var lastSize = CGSize.zero
  init(content: AnyView) {
    host = UIHostingController(rootView: content)
    // Güvenli alan boşluğu sayfada elle veriliyor (`side`, `insets`). Barındırıcı bunu
    // bir kez daha uygularsa yatayda içerik çentik payı kadar yana kayıyordu.
    host.safeAreaRegions = []
  }
  func viewForZooming(in scrollView: UIScrollView) -> UIView? { host.view }
}
