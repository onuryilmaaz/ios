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

    let location = try await withCheckedThrowingContinuation { continuation in
      locationContinuation = continuation
      manager.requestLocation()
    }
    let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "tr_TR"))
    let region = placemarks?.first?.administrativeArea ?? placemarks?.first?.locality ?? ""
    guard let state = Locations.state(matching: region), let district = Locations.defaultDistrict(ofState: state._id) else {
      throw Failure.notRecognized
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
