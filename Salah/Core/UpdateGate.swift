import SwiftUI

/// Sunucu sürüm politikası (saf). Android `UpdatePolicy` ile aynı hesap.
enum UpdatePolicy {
  static let defaultStoreURL = "https://apps.apple.com/app/id6785200246"

  struct Server: Decodable, Equatable, Sendable {
    var minVersion: String?
    var latestVersion: String?
    var storeUrl: String?
  }

  enum Status: Equatable {
    case none
    case optional(version: String, storeURL: String)
    case required(storeURL: String)
  }

  /// "1.0.10" > "1.0.9" gibi sayısal karşılaştırma. a<b: -1, a=b: 0, a>b: 1.
  static func compare(_ a: String, _ b: String) -> Int {
    let pa = a.split(separator: ".", omittingEmptySubsequences: false).map(leadingInt)
    let pb = b.split(separator: ".", omittingEmptySubsequences: false).map(leadingInt)
    for i in 0..<max(pa.count, pb.count) {
      let left = i < pa.count ? pa[i] : 0, right = i < pb.count ? pb[i] : 0
      if left != right { return left < right ? -1 : 1 }
    }
    return 0
  }

  private static func leadingInt(_ part: Substring) -> Int {
    Int(part.trimmingCharacters(in: .whitespaces).prefix { $0.isNumber }.prefix(9)) ?? 0
  }

  static func evaluate(current: String, _ server: Server) -> Status {
    let url = server.storeUrl.flatMap { $0.isEmpty ? nil : $0 } ?? defaultStoreURL
    if let min = server.minVersion, !min.isEmpty, compare(current, min) < 0 { return .required(storeURL: url) }
    if let latest = server.latestVersion, !latest.isEmpty, compare(current, latest) < 0 { return .optional(version: latest, storeURL: url) }
    return .none
  }
}

/// Zorunlu sürümde kapatılamayan ekran, önerilen sürümde her yeni sürüm için bir kez pencere.
/// Yalnız sunucudan yeni okunan değerle çalışır: ağ yoksa kapı açılmaz, uygulama kilitlenmez.
@MainActor
@Observable
final class UpdateGate {
  static let shared = UpdateGate()
  private static let dismissedKey = "@salah_update_dismissed_version"

  private(set) var requiredStoreURL: String?
  @ObservationIgnored private var pending: (version: String, storeURL: String)?
  @ObservationIgnored private var prompted: String?

  static var currentVersion: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0" }

  func apply(_ status: UpdatePolicy.Status) {
    pending = nil
    switch status {
    case .required(let url):
      requiredStoreURL = url
    case .optional(let version, let url):
      requiredStoreURL = nil
      if LocalStore.string(Self.dismissedKey) != version, prompted != version { pending = (version, url) }
    case .none:
      requiredStoreURL = nil
    }
  }

  /// Başka pencere açıkken bekler; sıradaki kontrolde gösterilir.
  func presentPending() {
    guard let item = pending, AlertCenter.shared.current == nil else { return }
    pending = nil
    prompted = item.version
    AppAlert.show(.info, t("update.optionalTitle"), t("update.optionalMessage", ["version": item.version]), buttons: [
      .init(text: t("update.later"), style: .cancel) { LocalStore.set(item.version, for: Self.dismissedKey) },
      .init(text: t("update.update")) { Self.openStore(item.storeURL) },
    ])
  }

  static func openStore(_ raw: String) {
    if let url = URL(string: raw) { UIApplication.shared.open(url) }
  }
}

struct UpdateRequiredView: View {
  @Environment(\.tokens) private var tokens
  let storeURL: String

  var body: some View {
    VStack(spacing: 0) {
      Spacer()
      EmptyState(icon: "arrow-up-circle-outline", title: t("update.requiredTitle"), message: t("update.requiredMessage")) {
        AppButton(title: t("update.openStore"), variant: .primary) {
          Haptics.impact(.medium)
          UpdateGate.openStore(storeURL)
        }
      }
      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(tokens.canvas)
    .contentShape(.rect)
    .accessibilityAddTraits(.isModal)
  }
}
