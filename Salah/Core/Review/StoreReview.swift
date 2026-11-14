import StoreKit
import UIKit

/// App Store değerlendirme penceresi. Yalnız olumlu bir anda istenir: en az 7 günlük seri kutlaması kapanınca,
/// hatim tamamlanınca ya da yıl özeti paylaşılınca. En fazla 120 günde bir; Apple ayrıca yılda 3 gösterim sınırı uygular.
/// Android StoreReview ile aynı anahtar ve kurallar.
enum StoreReview {
  static let lastRequestKey = "@salah_review_last_request"
  static let hatimsSeenKey = "@salah_review_hatims_seen"
  static let minStreak = 7
  static let minInterval: TimeInterval = 120 * 24 * 60 * 60

  /// `streak` nil: seriye bakılmayan an (hatim, yıl özeti).
  static func shouldRequest(streak: Int?, lastRaw: String?, now: Date) -> Bool {
    if let streak, streak < minStreak { return false }
    let last = lastRaw.flatMap(Double.init).flatMap { $0.isFinite ? $0 : nil } ?? 0
    return now.timeIntervalSince1970 * 1000 - last >= minInterval * 1000
  }

  @MainActor
  static func maybeRequest(streak: Int? = nil, now: Date = Date()) async {
    guard !DebugLaunch.isIsolated, shouldRequest(streak: streak, lastRaw: LocalStore.string(lastRequestKey), now: now) else { return }
    try? await Task.sleep(for: .milliseconds(600))
    guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first(where: { $0.activationState == .foregroundActive }) else { return }
    LocalStore.set(String(Int(now.timeIntervalSince1970 * 1000)), for: lastRequestKey)
    AppStore.requestReview(in: scene)
  }

  /// Tamamlanan hatim sayısı arttıysa (ilk görülüşte yalnız kaydedilir) değerlendirme anıdır.
  @MainActor
  static func hatimsChanged(_ completed: Int) {
    // Hesaba bağlı: başka hesaba geçince yanlışlıkla "hatim bitti" sayılmasın.
    let key = "\(hatimsSeenKey)_\(AuthStore.shared.user?.id ?? "-")"
    let seen = LocalStore.string(key).flatMap(Int.init)
    LocalStore.set(String(completed), for: key)
    if let seen, completed > seen { Task { await maybeRequest() } }
  }
}
