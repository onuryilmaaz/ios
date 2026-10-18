import SwiftUI
import UIKit

/// Uygulama ikonu seçimi (iOS alternatif ikonları). Desteklenmiyorsa hiç görünmez.
/// Premium kapalıyken hepsi serbest. RN: components/settings/AppIconPicker.tsx
struct AppIconPicker: View {
  @Environment(\.tokens) private var tokens
  /// Desteklenmiyorsa nil: bölüm hiç gösterilmez.
  @State private var current: String? = {
    guard UIApplication.shared.supportsAlternateIcons else { return nil }
    let name = UIApplication.shared.alternateIconName
    return icons.first { $0.name == name }?.id ?? "default"
  }()

  /// Kimlik, asset catalog'daki alternatif ikon adı (varsayılanda nil) ve etiket anahtarı.
  private static let icons: [(id: String, name: String?, label: String)] = [
    ("default", nil, "appIcon.default"),
    ("classic", "AppIconClassic", "appIcon.classic"),
    ("night", "AppIconNight", "appIcon.night"),
    ("gold", "AppIconGold", "appIcon.gold"),
  ]

  var body: some View {
    Group {
      if let current {
        VStack(alignment: .leading, spacing: 0) {
          SectionLabel(t("appIcon.title")).padding(.leading, 10.5)
          HStack {
            ForEach(Array(Self.icons.enumerated()), id: \.element.id) { i, icon in
              if i > 0 { Spacer(minLength: 0) }
              let selected = icon.id == current
              Button { choose(icon) } label: {
                VStack(spacing: 7) {
                  Image("AppIconThumb-\(icon.id)")
                    .resizable()
                    .frame(width: 49, height: 49)
                    .clipShape(.rect(cornerRadius: 14))
                    .padding(1.75)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(selected ? Gold.s400 : .clear, lineWidth: 2))
                  Text(t(icon.label))
                    .font(.system(size: 12, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? tokens.textPrimary : tokens.textSecondary)
                }
              }
              .buttonStyle(PressableStyle())
              .accessibilityLabel(t(icon.label))
              .accessibilityAddTraits(selected ? .isSelected : [])
            }
          }
          .padding(14)
          .background(tokens.surface, in: .rect(cornerRadius: 21))
          .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
          .padding(.bottom, 21)
        }
      }
    }
  }

  private func choose(_ icon: (id: String, name: String?, label: String)) {
    guard icon.id != current else { return }
    Haptics.impact(.light)
    UIApplication.shared.setAlternateIconName(icon.name) { error in
      Task { @MainActor in
        if error == nil { current = icon.id } else { Toast.error(t("common.error"), t("appIcon.failed")) }
      }
    }
  }
}
