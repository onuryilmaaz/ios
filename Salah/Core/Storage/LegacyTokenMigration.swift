import Foundation

/// Salt veri algoritması; testler gerçek Keychain veya App Group'a dokunmaz.
enum LegacyTokenMigration {
  struct Credentials: Equatable {
    var access: String?
    var refresh: String?
    var stamp: Double

    init(access: String? = nil, refresh: String? = nil, stamp: Double = 0) {
      self.access = access.flatMap { $0.isEmpty ? nil : $0 }
      self.refresh = refresh.flatMap { $0.isEmpty ? nil : $0 }
      self.stamp = stamp.isFinite && stamp >= 0 ? stamp : 0
    }

    var hasTokens: Bool { access != nil || refresh != nil }
  }

  struct Result {
    var credentials: Credentials
    var removableSources: Set<Int>
  }

  /// Taze Keychain (çıkış damgası dahil) eski kopyaya karşı korunur. Yazma
  /// okunarak doğrulanmadan kaynak silinmez; hata halinde eski değer okunur.
  static func restore(
    sources: [Credentials], current: Credentials,
    writeAndRead: (Credentials) -> Credentials
  ) -> Result {
    var secure = current
    let candidate = sources.filter(\.hasTokens).max { a, b in
      if a.stamp != b.stamp { return a.stamp < b.stamp }
      return a.refresh == nil && b.refresh != nil
    }
    var attempted = false
    if let candidate, candidate.stamp >= current.stamp,
      !current.hasTokens || candidate.stamp > current.stamp || (current.refresh == nil && candidate.refresh != nil)
        || (current.refresh == candidate.refresh && current.access == nil && candidate.access != nil),
      current.refresh == nil || candidate.refresh != nil
    {
      attempted = true
      secure = writeAndRead(candidate)
    }
    var removable = Set<Int>()
    for (i, source) in sources.enumerated() where source.hasTokens {
      let copied = (source.refresh == nil || secure.refresh == source.refresh) && (source.access == nil || secure.access == source.access)
      let superseded = secure.stamp > source.stamp || (!attempted && secure.hasTokens && secure.stamp == source.stamp)
      if copied || superseded { removable.insert(i) }
    }
    let fallback = candidate.flatMap { source in
      let verified = (source.refresh == nil || secure.refresh == source.refresh) && (source.access == nil || secure.access == source.access)
      return attempted && !verified && source.stamp >= secure.stamp ? source : nil
    }
    return Result(credentials: fallback ?? secure, removableSources: removable)
  }
}
