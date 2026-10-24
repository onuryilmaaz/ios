import CoreLocation

/// Konum izni + tek seferlik konum + ters coğrafi kodlamayla il tespiti.
/// RN: services/districtResolver.ts (expo-location yerine CoreLocation).
@MainActor
final class LocationService: NSObject, CLLocationManagerDelegate {
  static let shared = LocationService()

  enum Failure: Error { case denied, unavailable, notRecognized }

  private let manager = CLLocationManager()
  private var authContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
  private var locationContinuation: CheckedContinuation<CLLocation, Error>?

  override private init() {
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyKilometer
  }

  /// İzin ister, konumu alır, ili ve o ilin varsayılan ilçesini döndürür.
  func detectDistrict() async throws -> (state: Locations.State, district: Locations.District) {
    var status = manager.authorizationStatus
    if status == .notDetermined {
      status = await withCheckedContinuation { continuation in
        authContinuation = continuation
        manager.requestWhenInUseAuthorization()
      }
    }
    guard status == .authorizedWhenInUse || status == .authorizedAlways else { throw Failure.denied }

    guard locationContinuation == nil else { throw Failure.unavailable }
    let location = try await withCheckedThrowingContinuation { continuation in
      locationContinuation = continuation
      manager.requestLocation()
    }
    guard let found = await resolve(location) else { throw Failure.notRecognized }
    return found
  }

  /// İzin zaten verilmiş mi (sormadan).
  var hasPermission: Bool {
    let status = manager.authorizationStatus
    return status == .authorizedWhenInUse || status == .authorizedAlways
  }

  /// İzin istemeden tek seferlik konum; izin yoksa ya da alınamazsa nil.
  /// Son 10 dakikadaki bilinen konum il tespiti için yeterli (Android `currentLocation`).
  func currentLocation() async -> CLLocation? {
    guard hasPermission else { return nil }
    if let last = manager.location, -last.timestamp.timeIntervalSinceNow < 10 * 60 { return last }
    // Başka bir istek sürüyorsa (ör. Ayarlar'daki konum bulma) çakıştırma; bir sonraki açılışta denenir.
    guard locationContinuation == nil else { return nil }
    return try? await withCheckedThrowingContinuation { continuation in
      locationContinuation = continuation
      manager.requestLocation()
    }
  }

  /// Koordinat → il ve merkez ilçesi; bulunamazsa nil.
  func resolve(_ location: CLLocation) async -> (state: Locations.State, district: Locations.District)? {
    let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "tr_TR"))
    let region = placemarks?.first?.administrativeArea ?? placemarks?.first?.locality ?? ""
    guard let state = Locations.state(matching: region), let district = Locations.defaultDistrict(ofState: state._id) else {
      return nil
    }
    return (state, district)
  }

  nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    let status = manager.authorizationStatus
    Task { @MainActor in
      guard status != .notDetermined, let c = self.authContinuation else { return }
      self.authContinuation = nil
      c.resume(returning: status)
    }
  }

  nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location = locations.last else { return }
    Task { @MainActor in
      self.locationContinuation?.resume(returning: location)
      self.locationContinuation = nil
    }
  }

  nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    Task { @MainActor in
      self.locationContinuation?.resume(throwing: Failure.unavailable)
      self.locationContinuation = nil
    }
  }
}
