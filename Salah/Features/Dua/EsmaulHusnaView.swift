import SwiftUI

struct EsmaName: Codable, Equatable, Identifiable, Sendable {
  let id: Int
  /// Latin okunuş (Arapça arayüzde Arapça ad).
  let name: String
  let arabic: String
  /// Kısa anlam (Arapça arayüzde boş).
  let meaning: String
}

/// 99 isim seçili dilde. Veri RN ile ortak kaynaktan üretilir:
/// mobile/src/data/esmaulHusna.ts + i18n/esmaulHusna.en.json → `bun ios/scripts/gen-esma.ts`.
enum EsmaLibrary {
  private static let all: [String: [EsmaName]] = {
    guard let url = Bundle.main.url(forResource: "esma.generated", withExtension: "json"),
      let data = try? Data(contentsOf: url)
    else { return [:] }
    return (try? JSONDecoder().decode([String: [EsmaName]].self, from: data)) ?? [:]
  }()

  static var names: [EsmaName] { all[Localizer.shared.language.rawValue] ?? all["tr"] ?? [] }

  /// Ad, anlam, Arapça ya da sıra numarasıyla arama (Türkçe karakter ve şapka duyarsız).
  static func filter(_ names: [EsmaName], query: String) -> [EsmaName] {
    let raw = query.trimmingCharacters(in: .whitespaces)
    guard !raw.isEmpty else { return names }
    let q = normalize(raw)
    return names.filter {
      normalize($0.name).contains(q) || normalize($0.meaning).contains(q) || normalize($0.arabic).contains(q) || String($0.id) == raw
    }
  }

  /// RN `normalize`: küçük harf, ı/â/î/û/ö/ü/ş/ç/ğ sadeleştirme, kesme ve tire atılır.
  static func normalize(_ s: String) -> String {
    var out = s.lowercased()
    let map: [Character: Character] = [
      "ı": "i", "â": "a", "ā": "a", "î": "i", "ī": "i", "û": "u", "ū": "u",
      "ö": "o", "ô": "o", "ü": "u", "ş": "s", "ç": "c", "ğ": "g",
    ]
    out = String(out.compactMap { ch -> Character? in
      if ["'", "’", "-"].contains(ch) { return nil }
      return map[ch] ?? ch
    })
    return out
  }
}

/// Esmaül Hüsna. RN: screens/user/EsmaulHusnaScreen.tsx
struct EsmaulHusnaView: View {
  @Environment(\.tokens) private var tokens
  @State private var query = ""
  @State private var selected: EsmaName? = DebugLaunch.esma == "detail" ? EsmaLibrary.names.first : nil
  @State private var sharing: EsmaName? = DebugLaunch.esma == "share" ? EsmaLibrary.names.first : nil

  /// iOS'ta Arapça adlar Geeza Pro ile (RN ile aynı).
  private static let arabicFont = "GeezaPro"

  var body: some View {
    let dark = tokens.isDark
    let isArabic = Localizer.shared.language == .ar
    let filtered = EsmaLibrary.filter(EsmaLibrary.names, query: query)

    VStack(spacing: 0) {
      StandardHeader(title: t("esma.title"))

      HStack(spacing: 7) {
        Ionicon("search", size: 16, color: dark ? Forest.s400 : Forest.s500)
        TextField("", text: $query, prompt: Text(t("esma.search")).foregroundStyle(dark ? Forest.s600 : Forest.s400))
          .font(.system(size: 12.25))
          .foregroundStyle(dark ? .white : Forest.s900)
          .tint(tokens.accent)
          .autocorrectionDisabled()
        if !query.isEmpty {
          Button {
            query = ""
          } label: {
            Ionicon("close-circle", size: 16, color: dark ? Forest.s600 : Forest.s400)
          }
          .buttonStyle(PressableStyle())
          .accessibilityLabel(t("esma.clearSearch"))
        }
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 8.75)
      .background(tokens.surface, in: .rect(cornerRadius: 21))
      .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
      .padding(.horizontal, 14)
      .padding(.top, 7)
      .padding(.bottom, 7)

      ScrollView {
        LazyVStack(alignment: .leading, spacing: 10.5) {
          Text(t("esma.count", ["count": filtered.count]))
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(tokens.textSecondary)
            .padding(.leading, 3.5)

          ForEach(filtered) { n in
            Button {
              Haptics.impact(.light)
              selected = n
            } label: {
              HStack(spacing: 0) {
                NumberMedallion(label: "\(n.id)", color: dark ? Gold.s400 : Gold.s500, accent2: dark ? Gold.s300 : Gold.s400, size: 44)
                VStack(alignment: .leading, spacing: 1.75) {
                  Text(n.name).font(.system(size: 14, weight: .bold)).foregroundStyle(dark ? .white : Forest.s900)
                  if !n.meaning.isEmpty {
                    Text(n.meaning).font(.system(size: 10.5)).foregroundStyle(tokens.textSecondary).lineLimit(2)
                  }
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 14)
                if !isArabic {
                  Text(n.arabic)
                    .font(.custom(Self.arabicFont, size: 17.5))
                    .foregroundStyle(dark ? .white : Forest.s900)
                    .padding(.leading, 7)
                }
              }
              .padding(14)
              .background(tokens.surface, in: .rect(cornerRadius: 21))
              .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
            }
            .buttonStyle(PressableStyle(pressedOpacity: 0.85))
          }

          if filtered.isEmpty {
            VStack(spacing: 10.5) {
              Ionicon("search-outline", size: 36, color: dark ? Forest.s600 : Forest.s400)
              Text(t("esma.empty")).font(.system(size: 12.25)).foregroundStyle(tokens.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 42)
          }
        }
        .padding(16)
        .padding(.bottom, 32)
      }
      .scrollIndicators(.hidden)
      .scrollDismissesKeyboard(.interactively)
    }
    .background(tokens.canvas)
    .toolbar(.hidden, for: .navigationBar)
    .overlayModal(isPresented: Binding(get: { selected != nil }, set: { if !$0 { selected = nil } })) {
      if let n = selected {
        EsmaDetail(name: n, isArabic: isArabic, onClose: { selected = nil }) {
          // Önce ayrıntı kapanır, sonra kart açılır (iki tam ekran pencere üst üste açılamaz).
          Haptics.impact(.light)
          selected = nil
          Task {
            try? await Task.sleep(for: .milliseconds(350))
            sharing = n
          }
        }
        .environment(\.tokens, tokens)
      }
    }
    .fullScreenCover(item: $sharing) { n in
      ShareCardSheet(
        arabic: n.arabic,
        arabicLarge: true,
        text: n.meaning.isEmpty ? n.name : n.meaning,
        source: [isArabic ? nil : n.name, t("esma.nth", ["n": n.id])].compactMap { $0 }.joined(separator: " · "),
        label: t("esma.title")
      )
      .environment(\.tokens, tokens)
    }
  }
}

/// İsim ayrıntısı penceresi. RN: EsmaulHusnaScreen detay `Modal`.
private struct EsmaDetail: View {
  @Environment(\.tokens) private var tokens
  let name: EsmaName
  let isArabic: Bool
  let onClose: () -> Void
  let onShare: () -> Void

  var body: some View {
    let dark = tokens.isDark
    ZStack {
      Color.black.opacity(0.6).ignoresSafeArea().onTapGesture(perform: onClose)
      VStack(spacing: 0) {
        VStack(spacing: 0) {
          Text(t("esma.nth", ["n": name.id]))
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(dark ? Amber.s400 : Amber.s600)
            .padding(.horizontal, 10.5)
            .padding(.vertical, 3.5)
            .background(dark ? Amber.s500.opacity(0.2) : Color(hex: 0xfef3c7), in: .rect(cornerRadius: 14))
          Text(name.arabic)
            .font(.custom("GeezaPro", size: 42))
            .foregroundStyle(dark ? .white : Forest.s900)
            .padding(.top, 14)
          if !isArabic {
            Text(name.name).font(.system(size: 17.5, weight: .semibold)).foregroundStyle(dark ? .white : Forest.s900).padding(.top, 10.5)
          }
        }
        .padding(.horizontal, 21)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
        .background(alignment: .top) {
          DecorPattern(color: dark ? Amber.s400 : Amber.s600, opacity: dark ? 0.1 : 0.08, size: 220).offset(y: -40)
        }
        .background(dark ? Amber.s500.opacity(0.15) : Amber.s50)
        .clipped()

        if !name.meaning.isEmpty {
          VStack(alignment: .leading, spacing: 3.5) {
            Text(t("esma.meaning")).font(.system(size: 12, weight: .medium)).foregroundStyle(tokens.textSecondary)
            Text(name.meaning).font(.system(size: 12.25)).lineSpacing(6).foregroundStyle(dark ? Forest.s300 : Forest.s700)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(21)
        }

        HStack(spacing: 0) {
          Button(action: onClose) {
            HStack(spacing: 7) {
              Ionicon("close", size: 16, color: dark ? Forest.s400 : Forest.s500)
              Text(t("common.close")).font(.system(size: 12.25, weight: .bold)).foregroundStyle(dark ? Forest.s300 : Forest.s600)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
          }
          .buttonStyle(PressableStyle())
          Rectangle().fill(dark ? Forest.s800 : Forest.s100).frame(width: 1)
          Button(action: onShare) {
            HStack(spacing: 7) {
              Ionicon("share-outline", size: 16, color: dark ? Accent.s400 : Accent.s600)
              Text(t("common.share")).font(.system(size: 12.25, weight: .bold)).foregroundStyle(dark ? Accent.s300 : Accent.s700)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
          }
          .buttonStyle(PressableStyle())
        }
        .fixedSize(horizontal: false, vertical: true)
        .overlay(alignment: .top) { Rectangle().fill(dark ? Forest.s800 : Forest.s100).frame(height: 1) }
      }
      .background(tokens.surface)
      .clipShape(.rect(cornerRadius: 14))
      .padding(.horizontal, 21)
    }
  }
}
