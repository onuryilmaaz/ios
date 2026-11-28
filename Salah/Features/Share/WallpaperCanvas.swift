import Photos
import SwiftUI

/// Duvar kağıdı ve tebrik kartı tasarımları. Renkler yalnız tema skalalarından (uygulama rengini izler); gradyan ve gölge yok.
enum CardDesign: String, CaseIterable, Identifiable {
  case orman, gece, kagit, sade
  var id: String { rawValue }

  var title: String { t("wallpaper.design.\(rawValue)") }

  var background: Color {
    switch self {
    case .orman: Accent.s900
    // Koyu gece mavisi; uygulama rengi lacivertse ikisi aynı olmasın diye nötr koyu.
    case .gece: AppColorStore.shared.current == .navy ? Forest.s950 : RamadanTint.night.hero
    case .kagit: Forest.s50
    case .sade: Forest.s950
    }
  }

  var arabicColor: Color {
    switch self {
    case .orman: Forest.s50
    case .gece: Gold.s300
    case .kagit: Accent.s800
    case .sade: Forest.s50
    }
  }

  var textColor: Color {
    switch self {
    case .orman: Forest.s100
    case .gece: Gold.s300
    case .kagit: Accent.s800
    case .sade: Forest.s200
    }
  }

  var sourceColor: Color {
    switch self {
    case .orman, .gece: Gold.s300
    case .kagit: Gold.s600
    case .sade: Forest.s400
    }
  }

  /// İnce çizgi, çerçeve ve yıldız süsü.
  var ornamentColor: Color { self == .kagit ? Gold.s500 : Gold.s300 }

  // Tebrik kartı (şablon `GreetingShareSheet` ile aynı renk rolleri).
  var greetingTitle: Color {
    switch self {
    case .orman: .white
    case .gece: Gold.s300
    case .kagit: Accent.s800
    case .sade: Forest.s50
    }
  }
}

/// Duvar kağıdına konacak metin: Arapça (isteğe bağlı), anlam ve kaynak.
struct WallpaperContent: Equatable, Identifiable {
  let id: String
  var arabic: String?
  var text: String
  var source: String
  /// Kısa Arapça (Esma gibi) büyük puntoyla.
  var arabicLarge = false
}

/// Sekiz köşeli yıldız (rub'ül-hizb): biri 45° döndürülmüş iki kare.
nonisolated struct OctagramShape: Shape {
  func path(in rect: CGRect) -> Path {
    let c = CGPoint(x: rect.midX, y: rect.midY)
    let r = min(rect.width, rect.height) / 2
    var path = Path()
    for offset in [0.0, 45.0] {
      for k in 0...4 {
        let a = (offset + 45 + Double(k) * 90) * .pi / 180
        let p = CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
        if k == 0 { path.move(to: p) } else { path.addLine(to: p) }
      }
    }
    return path
  }
}

/// Telefon ekranı oranında duvar kağıdı. Üst %35 (kilit ekranı saati) ve alt %12 (kısayollar) boş kalır.
/// Boyuta göre ölçeklenir: önizleme küçük, dışa aktarma cihaz ekranı boyutundadır.
struct WallpaperCanvas: View {
  let content: WallpaperContent?
  let design: CardDesign
  let size: CGSize

  var body: some View {
    let s = size.width / 390
    ZStack {
      design.background
      if design == .orman {
        RoundedRectangle(cornerRadius: 40 * s).inset(by: 16 * s)
          .stroke(design.ornamentColor.opacity(0.75), lineWidth: max(0.6, 1.2 * s))
      }
      VStack(spacing: 0) {
        Color.clear.frame(height: size.height * 0.35)
        if let content {
          ViewThatFits(in: .vertical) {
            block(content, s, 1)
            block(content, s, 0.85)
            block(content, s, 0.7)
            block(content, s, 0.58)
          }.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
          Color.clear.frame(maxHeight: .infinity)
        }
        Color.clear.frame(height: size.height * 0.12)
      }.padding(.horizontal, 38 * s)
    }
    .frame(width: size.width, height: size.height)
    .clipped()
  }

  private func block(_ c: WallpaperContent, _ s: CGFloat, _ k: CGFloat) -> some View {
    let arabicCount = c.arabic?.count ?? 0
    let arabicSize: CGFloat = c.arabicLarge ? 54 : arabicCount > 160 ? 24 : arabicCount > 80 ? 28 : 33
    let textSize: CGFloat = c.text.count > 140 ? 15 : 17
    return VStack(spacing: 16 * s * k) {
      if design == .orman {
        OctagramShape().stroke(design.ornamentColor, lineWidth: max(0.6, 1.2 * s)).frame(width: 30 * s * k, height: 30 * s * k)
      }
      if design == .kagit { rule(s, k) }
      if let arabic = c.arabic, !arabic.isEmpty {
        Text(QuranFont.text(arabic))
          .font(.custom(QuranFont.name, size: arabicSize * s * k))
          .lineSpacing(arabicSize * 0.55 * s * k)
          .foregroundStyle(design.arabicColor)
          .multilineTextAlignment(.center)
          .environment(\.layoutDirection, .rightToLeft)
      }
      if !c.text.isEmpty {
        Text(c.text)
          .font(.system(size: textSize * s * k))
          .lineSpacing(5 * s * k)
          .foregroundStyle(design.textColor)
          .multilineTextAlignment(.center)
      }
      Text(c.source)
        .font(.system(size: 13 * s * k, weight: .medium))
        .foregroundStyle(design.sourceColor)
        .multilineTextAlignment(.center)
      if design == .kagit { rule(s, k) }
    }
  }

  private func rule(_ s: CGFloat, _ k: CGFloat) -> some View {
    Rectangle().fill(design.ornamentColor).frame(width: 72 * s * k, height: max(0.6, 1 * s))
  }
}

enum WallpaperExport {
  enum SaveResult { case saved, denied, failed }

  /// Cihaz ekranı boyutu ve ölçeği (kilit ekranı oranı).
  static var screen: (size: CGSize, scale: CGFloat) {
    let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    let size = scene?.screen.bounds.size ?? CGSize(width: 393, height: 852)
    return (size, scene?.screen.scale ?? 3)
  }

  static func image(_ content: WallpaperContent, design: CardDesign, tokens: Tokens) -> UIImage? {
    let (size, scale) = screen
    let renderer = ImageRenderer(
      content: WallpaperCanvas(content: content, design: design, size: size)
        .environment(\.tokens, tokens)
        .environment(\.locale, Localizer.shared.locale)
        .environment(\.layoutDirection, Localizer.shared.layoutDirection))
    renderer.scale = scale
    renderer.isOpaque = true
    return renderer.uiImage
  }

  /// Fotoğraf arşivine yalnız ekleme izniyle kaydeder.
  static func save(_ image: UIImage) async -> SaveResult {
    let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
    guard status == .authorized || status == .limited else { return .denied }
    do {
      try await PHPhotoLibrary.shared().performChanges { PHAssetChangeRequest.creationRequestForAsset(from: image) }
      return .saved
    } catch {
      return .failed
    }
  }
}
