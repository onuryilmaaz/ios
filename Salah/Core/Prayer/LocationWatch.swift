import CoreLocation
import Foundation

/// Kullanıcı şehir değiştirdiğinde namaz vakitlerinin kendiliğinden güncellenmesi.
/// Android `LocationWatch.kt` ile aynı kurallar (RN services/locationWatch.service.ts).
///
/// Arka planda konum izlenmez; uygulama öne geldiğinde ucuz bir kontrol yapılır:
/// en fazla 30 dakikada bir, yalnız izin ZATEN verilmişse (sormadan), 25 km'den az hareket
/// ve aynı ilçede ters coğrafi kodlama bile yapılmaz. İlçe değiştiyse: otomatik seçilmişse
/// sessizce güncellenir, elle seçilmişse sorulur.
@MainActor
enum LocationWatch {
  static let lastCheckKey = "@salah_location_last_check"
  /// Son ters coğrafi kodlamanın sonucu: {lat, lon, districtId}.
  static let lastResolvedKey = "@salah_location_last_resolved"
  /// Reddedilen öneriyi tekrar tekrar sormamak için.
  static let declinedDistrictKey = "@salah_location_declined_district"
  static let checkInterval: TimeInterval = 30 * 60
  nonisolated static let minMoveKm = 25.0

  struct Resolved: Codable, Equatable {
    let lat: Double
    let lon: Double
    let districtId: String
  }

  enum Action: Equatable { case none, silentUpdate, ask }

  /// İki koordinat arası kuş uçuşu mesafe (km).
  nonisolated static func distanceKm(_ aLat: Double, _ aLon: Double, _ bLat: Double, _ bLon: Double) -> Double {
    let r = 6371.0
    let dLat = (bLat - aLat) * .pi / 180
    let dLon = (bLon - aLon) * .pi / 180
    let h = pow(sin(dLat / 2), 2) + pow(sin(dLon / 2), 2) * cos(aLat * .pi / 180) * cos(bLat * .pi / 180)
    return 2 * r * asin(sqrt(h))
  }

  /// Pahalı ters coğrafi kodlama gerekli mi? İkisi birden gerekir ki atlansın: kayda değer hareket yok
  /// VE seçili ilçe en son çözümlenenle aynı (kullanıcı yerinden kıpırdamadan başka şehir seçtiyse fark edilir).
  nonisolated static func needsResolve(_ prev: Resolved?, lat: Double, lon: Double, currentDistrictId: String?) -> Bool {
    guard let prev else { return true }
    let moved = distanceKm(prev.lat, prev.lon, lat, lon) >= minMoveKm
    return moved || currentDistrictId != prev.districtId
  }

  /// Kaynağı bilinmeyen eski kurulumlar elle seçilmiş sayılır (RN `getDistrictSource`).
  nonisolated static func decide(currentDistrictId: String?, resolvedDistrictId: String, source: String?, declinedDistrictId: String?) -> Action {
    if currentDistrictId == resolvedDistrictId { return .none }
    if source == "auto" { return .silentUpdate }
    if declinedDistrictId == resolvedDistrictId { return .none }
    return .ask
  }

  private static var running = false

  static func check() async {
    guard !DebugLaunch.isIsolated, !running else { return }
    running = true
    defer { running = false }

    let lastCheck = LocalStore.string(lastCheckKey).flatMap(Double.init) ?? 0
    guard Date().timeIntervalSince1970 * 1000 - lastCheck >= checkInterval * 1000 else { return }
    // İzin istemeden yalnız mevcut durum: bu kontrol kullanıcıya görünmez olmalı.
    let service = LocationService.shared
    guard service.hasPermission, let location = await service.currentLocation() else { return }
    // Damga konum GERÇEKTEN alındıktan sonra: alınamazsa bir sonraki açılışta yeniden denenir.
    LocalStore.set(String(Int64(Date().timeIntervalSince1970 * 1000)), for: lastCheckKey)

    // Ham değer: hiç seçilmemişse nil (varsayılan ilçe sayılmaz).
    let currentId = LocalStore.string(Locations.districtIdKey)
    let lat = location.coordinate.latitude
    let lon = location.coordinate.longitude
    guard needsResolve(LocalStore.decode(Resolved.self, lastResolvedKey), lat: lat, lon: lon, currentDistrictId: currentId),
      let (state, district) = await service.resolve(location)
    else { return }
    LocalStore.encode(Resolved(lat: lat, lon: lon, districtId: district._id), for: lastResolvedKey)

    switch decide(
      currentDistrictId: currentId, resolvedDistrictId: district._id,
      source: LocalStore.string(Locations.sourceKey), declinedDistrictId: LocalStore.string(declinedDistrictKey)
    ) {
    case .none: break
    case .silentUpdate:
      apply(stateId: state._id, districtId: district._id, source: "auto")
      Toast.info(t("location.updatedTitle"), t("location.updatedBody", ["name": Locations.displayName(state.name)]))
    case .ask:
      ask(currentId: currentId, next: state, district: district)
    }
  }

  private static func apply(stateId: String, districtId: String, source: String) {
    Locations.select(stateId: stateId, districtId: districtId, source: source)
    LocalStore.set(nil, for: declinedDistrictKey)
  }

  private static func ask(currentId: String?, next: Locations.State, district: Locations.District) {
    let currentName = (currentId.flatMap { Locations.district($0)?.name } ?? Locations.selectedStateId.flatMap { Locations.state($0)?.name })
      .map(Locations.displayName) ?? t("location.currentFallback")
    let nextName = Locations.displayName(next.name)
    AppAlert.show(.confirm, t("location.changedTitle"), t("location.changedBody", ["current": currentName, "next": nextName]), buttons: [
      .init(text: t("location.keep"), style: .cancel) { LocalStore.set(district._id, for: declinedDistrictKey) },
      .init(text: t("location.update")) {
        apply(stateId: next._id, districtId: district._id, source: "manual")
        Toast.success(t("location.updated"), t("location.updatedBody", ["name": nextName]))
      },
    ])
  }
}
