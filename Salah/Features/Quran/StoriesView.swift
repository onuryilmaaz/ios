import SwiftUI

/// Kıssa listesi: üstte "Devam et", altta her kıssa için bölüm sayısı ve okundu işareti.
struct StoriesView: View {
  @Environment(\.tokens) private var tokens
  @Bindable private var nav = QuranNavigation.shared
  private let progress = StoryProgressStore.shared

  var body: some View {
    VStack(spacing: 0) {
      StandardHeader(title: t("stories.title")) { EmptyView() }
      ScrollView {
        LazyVStack(spacing: 10.5) {
          if let story = progress.resumable { resumeRow(story) }
          if StoryCatalog.all.isEmpty {
            QuranEmptyView(icon: "albums-outline", title: t("topics.emptyTopic"))
          }
          ForEach(StoryCatalog.all) { story in row(story) }
        }.padding(.horizontal, 14).padding(.top, 10.5).padding(.bottom, 24)
      }.scrollIndicators(.hidden)
    }.background(tokens.canvas).toolbar(.hidden, for: .navigationBar)
  }

  private func resumeRow(_ story: Story) -> some View {
    Button { Haptics.impact(.light); nav.path.append(.story(story.id)) } label: {
      HStack(spacing: 10.5) {
        Ionicon("book", size: 19, color: .white).frame(width: 38, height: 38).background(.white.opacity(0.15), in: .circle)
        VStack(alignment: .leading, spacing: 1.75) {
          Text(t("stories.continue")).font(.system(size: 13, weight: .medium)).foregroundStyle(Gold.s300)
          Text(story.title).font(.system(size: 17, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
          Text(t("stories.step", ["current": progress.read(story) + 1, "total": story.sections.count]))
            .font(.system(size: 13)).foregroundStyle(.white.opacity(0.75))
        }.frame(maxWidth: .infinity, alignment: .leading)
        Ionicon(dirIcon("chevron-forward"), size: 18, color: .white.opacity(0.7))
      }.padding(14).background(tokens.isDark ? Accent.s900 : Accent.s800, in: .rect(cornerRadius: 21))
    }.buttonStyle(PressableStyle())
  }

  private func row(_ story: Story) -> some View {
    let done = progress.isDone(story)
    return Button { Haptics.impact(.light); nav.path.append(.story(story.id)) } label: {
      HStack(spacing: 10.5) {
        VStack(alignment: .leading, spacing: 1.75) {
          Text(story.title).font(.system(size: 17, weight: .semibold)).foregroundStyle(tokens.textPrimary).lineLimit(1)
          Text(t("stories.sections", ["count": story.sections.count])).font(.system(size: 13)).foregroundStyle(tokens.textSecondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
        if done {
          Ionicon("checkmark-circle", size: 20, color: tokens.accent).accessibilityLabel(t("stories.done"))
        }
        Ionicon(dirIcon("chevron-forward"), size: 18, color: tokens.inkSubtle)
      }.padding(14).background(tokens.surface, in: .rect(cornerRadius: 21))
        .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
    }.buttonStyle(PressableStyle())
      .accessibilityLabel("\(story.title), \(t("stories.sections", ["count": story.sections.count]))\(done ? ", \(t("stories.done"))" : "")")
  }
}

/// Bir kıssa: özet, sonra bölümler tek tek (başlık ve o aralıktaki ayetler); bölüm sonunda "Sonraki bölüm".
struct StoryDetailView: View {
  @Environment(\.tokens) private var tokens
  @Environment(\.dismiss) private var dismiss
  let storyID: String
  private let progress = StoryProgressStore.shared

  @State private var index = 0
  @State private var verses: [TopicVerseText]?
  @State private var failed = false
  @State private var started = false
  @State private var listenIDs: [Int] = []
  private let audio = QuranAudioPlayer.shared

  private var story: Story? { StoryCatalog.story(storyID) }

  var body: some View {
    VStack(spacing: 0) {
      StandardHeader(title: story?.title ?? t("stories.title")) { EmptyView() }
      if let story, story.sections.indices.contains(index) {
        let section = story.sections[index]
        ScrollViewReader { proxy in
          ScrollView {
            VStack(spacing: 10.5) {
              header(story).id("top")
              sectionHeader(section, total: story.sections.count)
              if let verses {
                VerseListenButton(refs: verses.map(\.ref), showsTitle: true, playKey: "listen.all", stopKey: "listen.stopAll")
                  .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(Array(verses.enumerated()), id: \.element.id) { offset, verse in
                  TopicVerseCard(ref: verse.ref, preloaded: verse, highlighted: isPlaying(offset))
                    .id("\(Localizer.shared.language.rawValue)-\(verse.id)")
                }
              } else if failed {
                Card {
                  QuranEmptyView(icon: "cloud-offline-outline", title: t("topics.loadFailed"))
                  AppButton(title: t("common.retry"), variant: .secondary) { Task { await load(section) } }
                }
              } else {
                Card { skeleton }
              }
              nextButton(story)
            }.padding(.horizontal, 14).padding(.top, 10.5).padding(.bottom, 24)
          }.scrollIndicators(.hidden)
            .onChange(of: index) { proxy.scrollTo("top", anchor: .top) }
        }
        .task(id: "\(index)-\(Localizer.shared.language.rawValue)") { await load(section) }
        .task(id: verses?.map(\.id).joined(separator: ",") ?? "") { listenIDs = await VerseAudio.verses(verses?.map(\.ref) ?? []).map(\.id) }
      } else {
        QuranEmptyView(icon: "albums-outline", title: t("topics.emptyTopic")).padding(.top, 24)
        Spacer()
      }
    }.background(tokens.canvas).toolbar(.hidden, for: .navigationBar).stopsVerseAudioOnDisappear()
      .onChange(of: index) { QuranAudioPlayer.shared.stop() }
      .onAppear {
        guard !started, let story else { return }
        started = true
        progress.opened(story)
        let done = progress.read(story)
        if let debug = DebugLaunch.storySection { index = min(max(debug - 1, 0), story.sections.count - 1) }
        // Yarım kalan kıssada kaldığın bölümden, bitmişse baştan.
        else if done > 0, done < story.sections.count { index = done }
      }
  }

  /// "Tümünü dinle" sırasında çalan ayet vurgulanır.
  private func isPlaying(_ offset: Int) -> Bool {
    !listenIDs.isEmpty && audio.state != .idle && audio.activeIndex == offset && audio.verses.map(\.id) == listenIDs
  }

  private func header(_ story: Story) -> some View {
    VStack(alignment: .leading, spacing: 3.5) {
      Text(story.overview).font(.system(size: 14)).foregroundStyle(tokens.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
      Text(t("stories.note")).font(.system(size: 13)).foregroundStyle(tokens.inkMuted)
        .frame(maxWidth: .infinity, alignment: .leading)
    }.padding(.horizontal, 3.5).padding(.bottom, 3.5)
  }

  private func sectionHeader(_ section: StorySection, total: Int) -> some View {
    VStack(alignment: .leading, spacing: 3.5) {
      SectionLabel(t("stories.step", ["current": index + 1, "total": total]))
      Text(section.text).font(.system(size: 17, weight: .semibold)).foregroundStyle(tokens.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading).accessibilityAddTraits(.isHeader)
    }.padding(.horizontal, 3.5).padding(.top, 7)
  }

  private func nextButton(_ story: Story) -> some View {
    let last = index >= story.sections.count - 1
    return AppButton(title: t(last ? "stories.finish" : "stories.next")) {
      Haptics.impact(.medium)
      progress.mark(story, section: index + 1)
      if last { dismiss() } else { index += 1 }
    }.padding(.top, 7)
  }

  private func load(_ section: StorySection) async {
    failed = false
    verses = nil
    let result = await StoryVerses.load(section)
    guard !Task.isCancelled else { return }
    verses = result
    failed = result == nil
  }

  private var skeleton: some View {
    VStack(alignment: .leading, spacing: 10.5) {
      RoundedRectangle(cornerRadius: 4).fill(tokens.fill).frame(width: 110, height: 16)
      RoundedRectangle(cornerRadius: 4).fill(tokens.fill).frame(height: 26)
      RoundedRectangle(cornerRadius: 4).fill(tokens.fill).frame(height: 14)
      RoundedRectangle(cornerRadius: 4).fill(tokens.fill).frame(width: 180, height: 14)
    }.frame(maxWidth: .infinity, alignment: .leading).accessibilityHidden(true)
  }
}
