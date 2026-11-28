import SwiftUI

/// Tebrik kartı vesilesi: bir dini gün (ya da cuma) ve sonraki tarihi.
struct GreetingOccasion: Identifiable, Hashable {
  let id: String
  let kind: GreetingKind
  let name: String
  let date: Date
  var isToday: Bool { Calendar.current.isDateInToday(date) }
}

/// "Tebrik kartları": tüm vesileler, sonraki tarihleriyle. Dokununca kart düzenleyici açılır.
struct GreetingsView: View {
  @Environment(\.tokens) private var tokens
  @State private var occasions: [GreetingOccasion] = []
  @State private var editing: GreetingOccasion?
  @State private var debugOpened = false

  var body: some View {
    VStack(spacing: 0) {
      StandardHeader(title: t("greetings.title")) { EmptyView() }
      ScrollView {
        LazyVStack(spacing: 10.5) {
          ForEach(occasions) { occasion in row(occasion) }
        }.padding(.horizontal, 14).padding(.top, 10.5).padding(.bottom, 24)
      }.scrollIndicators(.hidden)
    }
    .background(tokens.canvas).toolbar(.hidden, for: .navigationBar)
    .navigationDestination(item: $editing) { GreetingEditorView(occasion: $0) }
    .task(id: Localizer.shared.language) {
      occasions = Self.build(await ReligiousCalendarService.load())
      if !debugOpened, DebugLaunch.greetings == "edit" {
        debugOpened = true
        editing = occasions.first { $0.kind.rawValue == DebugLaunch.greetingKind } ?? occasions.first
      }
    }
  }

  private func row(_ occasion: GreetingOccasion) -> some View {
    Button { Haptics.impact(.light); editing = occasion } label: {
      HStack(spacing: 10.5) {
        Ionicon(occasion.kind.icon, size: 19, color: tokens.gold).frame(width: 38, height: 38)
          .background(tokens.isDark ? Gold.s700.opacity(0.2) : Gold.s50, in: .circle)
        VStack(alignment: .leading, spacing: 1.75) {
          Text(occasion.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(tokens.textPrimary).lineLimit(1)
          Text(occasion.date.formatted(.dateTime.day().month(.wide).year().locale(Localizer.shared.locale)))
            .font(.system(size: 13)).foregroundStyle(tokens.textSecondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
        if occasion.isToday { Badge(t("greetings.today")) }
        Ionicon(dirIcon("chevron-forward"), size: 18, color: tokens.inkSubtle)
      }.padding(14).background(tokens.surface, in: .rect(cornerRadius: 21))
        .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
    }.buttonStyle(PressableStyle())
      .accessibilityLabel("\(occasion.name), \(occasion.date.formatted(.dateTime.day().month(.wide).locale(Localizer.shared.locale)))")
  }

  /// Her vesilenin bir sonraki tarihi (bayramın yalnız ilk günü); cuma da eklenir. Tarihe göre sıralı.
  static func build(_ calendar: ReligiousCalendar, now: Date = Date()) -> [GreetingOccasion] {
    let cal = Calendar.current
    let start = cal.startOfDay(for: now)
    var seen = Set<String>()
    var out: [GreetingOccasion] = []
    for day in calendar.religiousDays(now: now) where day.date >= start {
      guard let kind = GreetingKind(dayId: day.id) else { continue }
      let base = day.id.replacing(/_\d+$/, with: "")
      if base.wholeMatch(of: /(ramazan|kurban)_bayram_[2-9]/) != nil { continue }
      guard seen.insert(base).inserted else { continue }
      out.append(.init(id: day.id, kind: kind, name: day.name, date: day.date))
    }
    var friday = start
    while cal.component(.weekday, from: friday) != 6 { friday = cal.date(byAdding: .day, value: 1, to: friday)! }
    out.append(.init(id: "cuma", kind: .cuma, name: t("greetings.cuma"), date: friday))
    return out.sorted { $0.date < $1.date }
  }
}

/// Kart düzenleyici: mesaj (3 seçenek) ve tasarım (klasik, kâğıt, gece) seç; paylaşım `ShareImageSheet` ile.
struct GreetingEditorView: View {
  @Environment(\.tokens) private var tokens
  let occasion: GreetingOccasion
  @State private var messageIndex = 0
  @State private var design: CardDesign
  @State private var sharing = false

  private static let designs: [CardDesign] = [.orman, .kagit, .gece]

  init(occasion: GreetingOccasion) {
    self.occasion = occasion
    let debug = CardDesign(rawValue: DebugLaunch.design ?? "")
    _design = State(initialValue: debug.flatMap { Self.designs.contains($0) ? $0 : nil } ?? .orman)
  }

  private var messages: [String] {
    let key = occasion.kind.rawValue
    return [
      AppControlStore.shared.greeting(key) ?? t("shareCards.greeting.\(key)"),
      t("shareCards.greeting.\(key)2"),
      t("shareCards.greeting.\(key)3"),
    ]
  }

  private var dayName: String? { occasion.kind == .cuma ? nil : occasion.name }
  private var dateText: String { GreetingKind.dateText(occasion.date) }

  var body: some View {
    let message = messages[min(messageIndex, 2)]
    VStack(spacing: 0) {
      StandardHeader(title: occasion.name) { EmptyView() }
      ScrollView {
        VStack(spacing: 14) {
          VStack(spacing: 0) {
            ShareCardHeader()
            GreetingCardBody(kind: occasion.kind, dayName: dayName, dateText: dateText, message: message, design: design)
          }
          .padding(.horizontal, 21).padding(.top, 24.5).padding(.bottom, 21)
          .frame(maxWidth: .infinity)
          .background(design.background, in: .rect(cornerRadius: 21))
          .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: design == .kagit ? 1 : 0))

          VStack(spacing: 7) {
            SectionLabel(t("greetings.message"))
            ForEach(Array(messages.enumerated()), id: \.offset) { index, text in messageRow(index, text) }
          }

          VStack(spacing: 7) {
            SectionLabel(t("wallpaper.design.title"))
            HStack(spacing: 7) {
              ForEach(Self.designs) { item in designChip(item) }
            }.frame(maxWidth: .infinity, alignment: .leading)
          }
        }.padding(.horizontal, 14).padding(.top, 10.5).padding(.bottom, 14)
      }.scrollIndicators(.hidden)
      AppButton(title: t("common.share")) { Haptics.impact(.medium); sharing = true }
        .padding(.horizontal, 14).padding(.vertical, 10.5)
    }
    .background(tokens.canvas).toolbar(.hidden, for: .navigationBar)
    .fullScreenCover(isPresented: $sharing) {
      ShareImageSheet(fallbackText: [message, dayName].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n"), cardColor: design.background) {
        ShareCardHeader()
        GreetingCardBody(kind: occasion.kind, dayName: dayName, dateText: dateText, message: message, design: design)
      }.environment(\.tokens, tokens)
    }
  }

  private func messageRow(_ index: Int, _ text: String) -> some View {
    let on = messageIndex == index
    return Button { Haptics.impact(.light); messageIndex = index } label: {
      HStack(spacing: 10.5) {
        Text(text).font(.system(size: 15)).foregroundStyle(tokens.textPrimary).multilineTextAlignment(.leading)
          .frame(maxWidth: .infinity, alignment: .leading)
        Ionicon(on ? "radio-button-on" : "radio-button-off", size: 20, color: on ? tokens.accent : tokens.inkSubtle)
      }.padding(14).background(tokens.surface, in: .rect(cornerRadius: 21))
        .overlay(RoundedRectangle(cornerRadius: 21).stroke(on ? tokens.accent : tokens.line, lineWidth: on ? 1.5 : 1))
    }.buttonStyle(PressableStyle()).accessibilityAddTraits(on ? .isSelected : [])
  }

  private func designChip(_ item: CardDesign) -> some View {
    let on = design == item
    return Button { Haptics.impact(.light); design = item } label: {
      HStack(spacing: 7) {
        Circle().fill(item.background).frame(width: 18, height: 18).overlay(Circle().stroke(item.ornamentColor, lineWidth: 1))
        Text(item == .orman ? t("greetings.classic") : item.title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
          .foregroundStyle(on ? tokens.onAccent : tokens.textPrimary)
      }.padding(.horizontal, 12.5).frame(height: 35)
        .background(on ? tokens.accent : tokens.surface, in: .capsule)
        .overlay(Capsule().stroke(on ? Color.clear : tokens.line, lineWidth: 1))
    }.buttonStyle(PressableStyle()).accessibilityAddTraits(on ? .isSelected : [])
  }
}

/// Kart içeriği; `GreetingShareSheet` ile aynı yerleşim, renkler tasarımdan.
struct GreetingCardBody: View {
  let kind: GreetingKind
  var dayName: String?
  let dateText: String
  let message: String
  let design: CardDesign

  var body: some View {
    let accent = design.sourceColor
    VStack(spacing: 0) {
      VStack(spacing: 0) {
        Ionicon(kind.icon, size: 36, color: accent)
          .frame(width: 70, height: 70)
          .overlay(Circle().stroke(accent, lineWidth: 1))
        if let dayName, !dayName.isEmpty {
          Text(dayName)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(accent)
            .multilineTextAlignment(.center)
            .padding(.top, 24)
        }
        Text(message)
          .font(.system(size: 30, weight: .bold))
          .lineSpacing(8)
          .foregroundStyle(design.greetingTitle)
          .multilineTextAlignment(.center)
          .padding(.top, 7)
      }
      .padding(.vertical, 14)

      HStack(spacing: 7) {
        Rectangle().frame(width: 35, height: 1)
        Rectangle().frame(width: 5.25, height: 5.25).rotationEffect(.degrees(45))
        Rectangle().frame(width: 35, height: 1)
      }
      .foregroundStyle(design.ornamentColor)
      .padding(.vertical, 17.5)

      Text(t("shareCards.greeting.prayer"))
        .font(.system(size: 15))
        .lineSpacing(9)
        .foregroundStyle(design.textColor)
        .multilineTextAlignment(.center)
      Text(dateText)
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(accent)
        .multilineTextAlignment(.center)
        .padding(.top, 20)
    }
  }
}
