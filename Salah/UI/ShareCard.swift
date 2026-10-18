import SwiftUI

/// Paylaşılabilir görsel kart (ayet, hadis, dua, Esma). Tema her yerde aynı görünsün diye
/// renkler sabittir (koyu zümrüt zemin, altın vurgu). RN: components/share/ShareCardModal.tsx
/// + ShareImageModal.tsx
struct ShareCardSheet: View {
  var arabic: String?
  /// Kısa Arapça (Esma gibi) büyük puntoyla.
  var arabicLarge = false
  var text: String
  var source: String
  var label: String?
  var icon = "chatbubble-ellipses-outline"

  var body: some View {
    ShareImageSheet(fallbackText: "\(text)\n\n\(source)") {
      card
    }
  }

  /// Metin uzadıkça küçülen yazı (RN `textSize`).
  private var card: some View {
    let body = QuranShareText.fit(text)
    let length = body.count + (arabic?.count ?? 0)
    let (size, line): (CGFloat, CGFloat) =
      length <= 160 && arabic == nil ? (18, 30) : length <= 300 ? (16, 27) : length <= 450 ? (15, 24) : (14, 22)
    let arabicSize: CGFloat = arabicLarge ? 48 : (arabic?.count ?? 0) > 180 ? 22 : 28

    return VStack(spacing: 0) {
      ShareCardHeader(label: label)

      if let arabic, !arabic.isEmpty {
        Text(QuranFont.text(arabic))
          .font(.custom(QuranFont.name, size: arabicSize))
          .lineSpacing(arabicSize)
          .foregroundStyle(Forest.s50)
          .multilineTextAlignment(.center)
          .environment(\.layoutDirection, .rightToLeft)
      } else {
        Ionicon(icon, size: 28, color: Gold.s300)
      }

      GoldDivider().padding(.vertical, 17.5)

      Text(body)
        .font(.system(size: size, weight: arabic == nil ? .medium : .regular))
        .lineSpacing(line - size)
        .foregroundStyle(Forest.s100)
        // Uzun paragraf ortalanınca zor okunuyor; kısa alıntılar ortada kalsın.
        .multilineTextAlignment(body.count > 220 ? .leading : .center)
        .frame(maxWidth: .infinity, alignment: body.count > 220 ? .leading : .center)

      Text(source)
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(Gold.s300)
        .multilineTextAlignment(.center)
        .padding(.top, 20)
    }
  }
}

/// Paylaşılabilir görsel kartların ortak kabuğu: karartılmış zemin, yakalanan kart
/// (koyu zümrüt) ve Kapat / Görseli Paylaş. RN: components/share/ShareImageModal.tsx
struct ShareImageSheet<Card: View>: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.tokens) private var tokens
  /// Görsel üretilemezse (ör. simülatör) paylaşılacak metin.
  let fallbackText: String
  @ViewBuilder var card: Card
  @State private var shareItems: ShareItems?

  private struct ShareItems: Identifiable {
    let id = UUID()
    var values: [Any]
  }

  var body: some View {
    GeometryReader { geometry in
      ScrollView {
        VStack(spacing: 17.5) {
          framed
          // RN: Kapat flex-1, Paylaş flex-2.
          let buttonWidth = (geometry.size.width - 40 - 10.5) / 3
          HStack(spacing: 10.5) {
            AppButton(title: t("common.close"), variant: .secondary) {
              Haptics.impact(.light)
              dismiss()
            }
            .frame(width: buttonWidth)
            AppButton(title: t("share.shareImage")) { share(width: geometry.size.width - 40) }
              .frame(width: buttonWidth * 2)
          }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 48)
        .frame(minHeight: geometry.size.height)
      }
      .scrollIndicators(.hidden)
    }
    .background(Color.black.opacity(0.75).ignoresSafeArea())
    .presentationBackground(.clear)
    .sheet(item: $shareItems) { item in ShareSheet(items: item.values) }
  }

  private var framed: some View {
    VStack(spacing: 0) { card }
      .padding(.horizontal, 21)
      .padding(.top, 24.5)
      .padding(.bottom, 21)
      .frame(maxWidth: .infinity)
      .background(Accent.s900, in: .rect(cornerRadius: 21))
  }

  private func share(width: CGFloat) {
    Haptics.notify(.success)
    let renderer = ImageRenderer(
      content: framed.frame(width: width)
        .environment(\.tokens, tokens)
        .environment(\.locale, Localizer.shared.locale)
        .environment(\.layoutDirection, Localizer.shared.layoutDirection))
    renderer.scale = 3
    if let image = renderer.uiImage {
      shareItems = ShareItems(values: [image])
    } else {
      shareItems = ShareItems(values: ["\(fallbackText)\n\n#SalahApp"])
    }
  }
}

/// Kart üst satırı: SALAH logosu (Bungee, amber-500) ve isteğe bağlı etiket.
struct ShareCardHeader: View {
  var label: String?

  var body: some View {
    HStack {
      Text(verbatim: "SALAH").font(.custom("Bungee-Regular", fixedSize: 22)).foregroundStyle(Amber.s500)
      Spacer()
      if let label, !label.isEmpty {
        Text(label)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(Gold.s300)
          .padding(.horizontal, 10.5)
          .padding(.vertical, 3.5)
          .overlay(Capsule().stroke(Gold.s300, lineWidth: 1))
      }
    }
    .environment(\.layoutDirection, .leftToRight)
    .padding(.bottom, 21)
  }
}

/// İnce altın ayraç (çizgi + baklava). RN: ShareImageModal `GoldDivider`.
struct GoldDivider: View {
  var body: some View {
    HStack(spacing: 7) {
      Rectangle().frame(width: 35, height: 1)
      Rectangle().frame(width: 5.25, height: 5.25).rotationEffect(.degrees(45))
      Rectangle().frame(width: 35, height: 1)
    }
    .foregroundStyle(Gold.s300)
  }
}
