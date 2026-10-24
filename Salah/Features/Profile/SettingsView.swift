import SwiftUI

/// Uygulama ayarları. RN: screens/user/SettingsScreen.tsx
struct SettingsView: View {
  @Environment(\.tokens) var tokens
  @State var requestingNotifications = false
  @State private var detecting = false
  @State private var exporting = false
  @State private var legal: LegalSheet.Doc?
  @State private var shareURL: URL?

  /// Dil adları her dilde kendi yazımıyla gösterilir.
  private static let languageNames: [AppLanguage: String] = [.tr: "Türkçe", .en: "English", .ar: "العربية"]

  var body: some View {
    let l10n = Localizer.shared
    let _ = LocationChanges.shared.nonce
    let stateName = Locations.selectedStateId.flatMap { Locations.state($0) }?.name
    let districtName = Locations.district(Locations.selectedDistrictId)?.name

    VStack(spacing: 0) {
      StandardHeader(title: t("settings.title"))
      ScrollViewReader { proxy in
       ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          SectionLabel(t("settings.location.section")).padding(.leading, 10.5)
          group {
            row(
              "location-outline", t("settings.location.prayerLocation"),
              sub: stateName.map { s in districtName.map { "\(s), \($0)" } ?? s } ?? districtName ?? t("settings.location.notSelected"),
              chevron: true
            ) {
              HomeNavigation.shared.path.append(.location)
            }
            row("navigate-outline", t("settings.location.auto"), sub: t(detecting ? "settings.location.detecting" : "settings.location.autoSub"), trailing: detecting ? "sync-outline" : nil, chevron: !detecting, last: true) {
              guard !detecting else { return }
              Task { await autoDetect() }
            }
          }

          if OzelGunStore.shared.gender == "kadin" || OzelGunStore.shared.isActive {
            SectionLabel(t("settings.personal.section")).padding(.leading, 10.5)
            group {
              row("heart-outline", t("settings.personal.ozelGun"), sub: t(OzelGunStore.shared.isActive ? "settings.personal.ozelGunActive" : "settings.personal.ozelGunSub"), chevron: true, last: true) {
                HomeNavigation.shared.path.append(.ozelGun)
              }
            }
          }

          notificationSections

          SectionLabel(t("settings.data.section")).padding(.leading, 10.5)
          group {
            row("cloud-download-outline", t(exporting ? "settings.data.preparing" : "settings.data.export"), sub: t("settings.data.exportSub"), trailing: exporting ? "hourglass-outline" : "share-outline", last: true) {
              guard !exporting else { return }
              Task { await export() }
            }
          }

          AppIconPicker().id("appIcon")

          SectionLabel(t("settings.app.section")).padding(.leading, 10.5)
          group {
            let current = Self.languageNames[l10n.language] ?? ""
            row(
              "language-outline", t("settings.language.title"),
              sub: l10n.preference == .system ? "\(t("settings.language.system")) (\(current))" : current,
              chevron: true
            ) { chooseLanguage() }
            row("map-outline", t("tour.replay"), sub: t("tour.replaySub"), chevron: true) {
              TourStore.shared.replayAll()
              HomeNavigation.shared.path.removeAll()
            }
            row("shield-checkmark-outline", t("settings.app.privacy"), sub: t("settings.app.privacySub"), chevron: true) { legal = .privacy }
            row("document-text-outline", t("settings.app.terms"), sub: t("settings.app.termsSub"), chevron: true) { legal = .terms }
            row("information-circle-outline", t("settings.app.version"), sub: Self.versionText)
            row("heart-outline", t("settings.app.developer"), sub: t("settings.app.developerSub"), last: true)
          }
        }
        .padding(16)
        .padding(.bottom, 24)
      }
      .scrollIndicators(.hidden)
       .task {
         if let target = DebugLaunch.notifications {
           try? await Task.sleep(for: .milliseconds(200))
           proxy.scrollTo(target, anchor: .top)
         }
       }
      }
    }
    .background(tokens.canvas)
    .toolbar(.hidden, for: .navigationBar)
    .task(id: AuthStore.shared.user) { if DebugLaunch.ozelGun == nil { await OzelGunStore.shared.fetch() } }
    .sheet(item: $legal) { doc in
      LegalSheet(initial: doc).environment(\.tokens, tokens)
    }
    .sheet(item: $shareURL) { url in
      ShareSheet(items: [url]).presentationDetents([.medium, .large])
    }
  }

  private static var versionText: String {
    let info = Bundle.main.infoDictionary
    let version = info?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    let build = info?["CFBundleVersion"] as? String
    return "Salah v\(version)" + (build.map { " (\($0))" } ?? "")
  }

  // MARK: - Satırlar

  func group<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    VStack(spacing: 0) { content() }
      .background(tokens.surface, in: .rect(cornerRadius: 21))
      .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
      .clipShape(.rect(cornerRadius: 21))
      .padding(.bottom, 21)
  }

  /// RN `Row`: ikon dairesi, etiket, alt etiket, sağda ikon. Dokunulabilir değilse düz satır.
  func row(
    _ icon: String, _ label: String, sub: String? = nil, trailing: String? = nil, chevron: Bool = false,
    last: Bool = false, toggle: Binding<Bool>? = nil, action: (() -> Void)? = nil
  ) -> some View {
    let dark = tokens.isDark
    let teal = dark ? Accent.s400 : Accent.s600
    let subColor = dark ? Forest.s500 : Forest.s400
    let content = HStack(spacing: 0) {
      Ionicon(icon, size: 17, color: teal)
        .frame(width: 31.5, height: 31.5)
        .background(dark ? Accent.s900 : Accent.s50, in: .circle)
        .padding(.trailing, 10.5)
      VStack(alignment: .leading, spacing: 1.75) {
        Text(label).font(.system(size: 16)).foregroundStyle(tokens.textPrimary)
        if let sub { Text(sub).font(.system(size: 13)).foregroundStyle(tokens.textSecondary) }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      if let toggle {
        Toggle(label, isOn: toggle).labelsHidden().tint(teal).padding(.leading, 12)
      } else if let trailing {
        Ionicon(trailing, size: 16, color: trailing == "sync-outline" ? teal : subColor)
      } else if chevron {
        Ionicon(dirIcon("chevron-forward"), size: 16, color: subColor)
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12.25)
    .contentShape(.rect)
    .overlay(alignment: .bottom) { if !last { RowDivider(leading: 0) } }

    return Group {
      if let action {
        Button {
          Haptics.impact(.light)
          action()
        } label: { content }
        .buttonStyle(PressableStyle())
      } else {
        content
      }
    }
  }

  // MARK: - İşlemler

  private func autoDetect() async {
    detecting = true
    defer { detecting = false }
    do {
      let found = try await LocationService.shared.detectDistrict()
      // Kullanıcı "konumumu bul"a bastı: bilinçli seçim, 'manual'.
      Locations.select(stateId: found.state._id, districtId: found.district._id, source: "manual")
    } catch LocationService.Failure.denied {
      AppAlert.warning(t("settings.location.permission"), t("settings.location.denied"))
    } catch LocationService.Failure.notRecognized {
      AppAlert.warning(t("settings.location.notFound"), t("settings.location.notRecognized"))
    } catch {
      AppAlert.error(t("common.error"), t("settings.location.failed"))
    }
  }

  private func chooseLanguage() {
    func pick(_ p: LanguagePreference) {
      Localizer.shared.setPreference(p)
    }
    AppAlert.show(.confirm, t("settings.language.title"), nil, buttons: [
      .init(text: t("settings.language.system")) { pick(.system) },
      .init(text: Self.languageNames[.tr]!) { pick(.fixed(.tr)) },
      .init(text: Self.languageNames[.en]!) { pick(.fixed(.en)) },
      .init(text: Self.languageNames[.ar]!) { pick(.fixed(.ar)) },
      .init(text: t("common.cancel"), style: .cancel),
    ])
  }

  private func export() async {
    Haptics.impact(.medium)
    exporting = true
    defer { exporting = false }
    do {
      let data = try await UserAPI.exportData()
      // Okunur biçimde (RN: JSON.stringify(data, null, 2)).
      let pretty = (try? JSONSerialization.jsonObject(with: data)).flatMap {
        try? JSONSerialization.data(withJSONObject: $0, options: [.prettyPrinted, .sortedKeys])
      } ?? data
      let url = FileManager.default.temporaryDirectory.appendingPathComponent("salah-yedek-\(localDateString()).json")
      try pretty.write(to: url)
      shareURL = url
    } catch {
      Toast.error(t("common.error"), t("settings.data.failed"))
    }
  }
}

extension URL: @retroactive Identifiable {
  public var id: String { absoluteString }
}

/// Sistem paylaşım sayfası.
struct ShareSheet: UIViewControllerRepresentable {
  let items: [Any]
  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: items, applicationActivities: nil)
  }
  func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// Gizlilik Politikası ve Kullanım Koşulları (TR/EN/AR). Metinler iOS'a özeldir:
/// Shared/mobile/src/constants/legal.ts'ten üretilir (ios/scripts/gen-legal.ts).
/// RN: components/layout/LegalModal.tsx
struct LegalSheet: View {
  enum Doc: String, Identifiable { case privacy, terms; var id: String { rawValue } }

  @Environment(\.tokens) private var tokens
  @Environment(\.dismiss) private var dismiss
  @State private var doc: Doc
  @State private var lang: String

  init(initial: Doc) {
    _doc = State(initialValue: initial)
    _lang = State(initialValue: Localizer.shared.language.rawValue)
  }

  private struct Content: Decodable {
    struct Section: Decodable { let title: String; let body: String }
    let heading: String
    let updated: String
    let sections: [Section]
  }

  private static let all: [String: [String: Content]] = {
    guard let url = Bundle.main.url(forResource: "legal.generated", withExtension: "json"),
      let data = try? Data(contentsOf: url)
    else { return [:] }
    return (try? JSONDecoder().decode([String: [String: Content]].self, from: data)) ?? [:]
  }()

  // Modal kendi etiketlerini taşır (RN'de de böyle; yasal metin dili arayüzden bağımsız).
  private static let labels: [String: (privacy: String, terms: String, close: String)] = [
    "tr": ("Gizlilik", "Koşullar", "Kapat"),
    "en": ("Privacy", "Terms", "Close"),
    "ar": ("الخصوصية", "الشروط", "إغلاق"),
  ]

  var body: some View {
    let content = Self.all[doc.rawValue]?[lang]
    let labels = Self.labels[lang]!
    let dark = tokens.isDark
    VStack(spacing: 0) {
      HStack {
        Text(content?.heading ?? "")
          .font(.system(size: 17.5, weight: .bold))
          .foregroundStyle(dark ? .white : Forest.s900)
        Spacer()
        Button {
          Haptics.impact(.light)
          dismiss()
        } label: {
          Ionicon("close", size: 20, color: dark ? Forest.s200 : Forest.s700)
            .frame(width: 31.5, height: 31.5)
            .background(dark ? Forest.s800 : Forest.s200, in: .circle)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(labels.close)
      }
      .padding(.horizontal, 14)
      .padding(.top, 16)
      .padding(.bottom, 7)

      HStack(spacing: 0) {
        ForEach([Doc.privacy, .terms], id: \.self) { d in
          Button {
            Haptics.impact(.light)
            doc = d
          } label: {
            Text(d == .privacy ? labels.privacy : labels.terms)
              .font(.system(size: 12.25, weight: .bold))
              .foregroundStyle(doc == d ? .white : (dark ? Forest.s300 : Forest.s600))
              .frame(maxWidth: .infinity)
              .padding(.vertical, 7)
              .background(doc == d ? Accent.s600 : .clear, in: .rect(cornerRadius: 10.5))
          }
          .buttonStyle(PressableStyle(pressedOpacity: 0.8))
        }
      }
      .padding(3.5)
      .background(dark ? Forest.s800 : Forest.s200, in: .rect(cornerRadius: 14))
      .padding(.horizontal, 14)
      .padding(.top, 3.5)
      .padding(.bottom, 10.5)

      HStack {
        Text(content?.updated ?? "").font(.system(size: 10.5)).foregroundStyle(tokens.textSecondary)
        Spacer()
        HStack(spacing: 0) {
          ForEach(["tr", "en", "ar"], id: \.self) { l in
            Button {
              Haptics.impact(.light)
              lang = l
            } label: {
              Text(l.uppercased())
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(lang == l ? .white : tokens.textSecondary)
                .padding(.horizontal, 10.5)
                .padding(.vertical, 3.5)
                .background(lang == l ? Accent.s600 : .clear)
            }
            .buttonStyle(PressableStyle(pressedOpacity: 0.8))
          }
        }
        .clipShape(.rect(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(dark ? Forest.s700 : Forest.s300, lineWidth: 1))
      }
      .padding(.horizontal, 14)
      .padding(.bottom, 7)

      ScrollView {
        VStack(alignment: .leading, spacing: 17.5) {
          ForEach(content?.sections ?? [], id: \.title) { s in
            VStack(alignment: .leading, spacing: 5.25) {
              Text(s.title).font(.system(size: 14, weight: .bold)).foregroundStyle(dark ? .white : Forest.s900)
              Text(s.body).font(.system(size: 12.25)).lineSpacing(6).foregroundStyle(dark ? Forest.s300 : Forest.s600)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 40)
        // Metin, arayüz dilinden bağımsız olarak seçilen dilin yönünde akar.
        .environment(\.layoutDirection, lang == "ar" ? .rightToLeft : .leftToRight)
      }
      .scrollIndicators(.hidden)
    }
    .background(tokens.canvas)
  }
}
