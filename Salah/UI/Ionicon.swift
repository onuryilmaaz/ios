import SwiftUI

/// RN'deki `<Ionicons>` ile aynı glifler: aynı font dosyası ve glyph haritası
/// (@expo/vector-icons). Görünüm birebir aynı kalsın diye SF Symbols yerine kullanılır.
struct Ionicon: View {
  let name: String
  var size: CGFloat = 24
  var color: Color = .primary

  init(_ name: String, size: CGFloat = 24, color: Color = .primary) {
    self.name = name
    self.size = size
    self.color = color
  }

  var body: some View {
    Text(Ionicon.glyph(name))
      .font(.custom("Ionicons", fixedSize: size))
      .foregroundStyle(color)
      .accessibilityHidden(true)
  }

  private static let glyphs: [String: Int] = {
    guard let url = Bundle.main.url(forResource: "Ionicons.glyphmap", withExtension: "json"),
      let data = try? Data(contentsOf: url),
      let map = try? JSONDecoder().decode([String: Int].self, from: data)
    else { return [:] }
    return map
  }()

  static func glyph(_ name: String) -> String {
    guard let cp = glyphs[name] ?? glyphs["help-outline"], let scalar = Unicode.Scalar(cp) else { return "" }
    return String(Character(scalar))
  }
}

/// Yön ikonu (ileri/geri) RTL'de aynalanmış hâliyle. RN: src/i18n/direction.ts
func dirIcon(_ name: String) -> String {
  guard Localizer.shared.language.isRTL else { return name }
  let mirror = [
    "chevron-forward": "chevron-back", "chevron-back": "chevron-forward",
    "arrow-forward": "arrow-back", "arrow-back": "arrow-forward",
  ]
  return mirror[name] ?? name
}

/// Vakit ikonları; kaynak Shared/mobile/src/constants/prayerIcons.json (widget tarafı PrayerIcons.generated.swift elle eşlenir; Android kopyası assets/data).
/// Anahtar olarak tracker kimliği (`fajr`), görünen ad (`İmsak`) ya da widget anahtarı (`sabah`).
func prayerIcon(_ keyOrName: String) -> String {
  PrayerIcons.byAlias[keyOrName] ?? "time-outline"
}

private enum PrayerIcons {
  struct File: Decodable {
    struct Prayer: Decodable {
      let key: String
      let aliases: [String]
      let ionicon: String
    }
    let prayers: [Prayer]
  }

  static let byAlias: [String: String] = {
    guard let url = Bundle.main.url(forResource: "prayerIcons", withExtension: "json"),
      let data = try? Data(contentsOf: url),
      let file = try? JSONDecoder().decode(File.self, from: data)
    else { return [:] }
    var map: [String: String] = [:]
    for p in file.prayers {
      for alias in [p.key] + p.aliases { map[alias] = p.ionicon }
    }
    return map
  }()
}
