import ActivityKit
import Foundation

public struct SitePongActivityAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    public var prayerName: String
    public var nextPrayer: String
    public var endTimeMs: Double
    /// "current": prayerName vakti içindeyiz, endTimeMs = vaktin çıkışı.
    /// "upcoming": prayerName vakti henüz girmedi, endTimeMs = vaktin girişi.
    public var mode: String
    /// current modda vaktin giriş anı (ilerleme halkası için), yoksa 0.
    public var startTimeMs: Double

    public init(
      prayerName: String, nextPrayer: String, endTimeMs: Double,
      mode: String = "current", startTimeMs: Double = 0
    ) {
      self.prayerName = prayerName
      self.nextPrayer = nextPrayer
      self.endTimeMs = endTimeMs
      self.mode = mode
      self.startTimeMs = startTimeMs
    }
  }

  public init() {}
}
