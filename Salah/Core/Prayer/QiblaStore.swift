import CoreLocation

enum QiblaAuthorization { case pending, allowed, denied }
enum QiblaFailure: String, Equatable {
  case permissionDenied, locationUnavailable, headingUnavailable
  var messageKey: String { "qibla.\(rawValue)" }
}
enum QiblaSensorEvent {
  case authorization(QiblaAuthorization)
  case location(latitude: Double, longitude: Double)
  case heading(trueHeading: Double, magneticHeading: Double, accuracy: Double)
  case failure(QiblaFailure)
}

@MainActor
protocol QiblaSensor: AnyObject {
  var authorization: QiblaAuthorization { get }
  var headingAvailable: Bool { get }
  var onEvent: ((QiblaSensorEvent) -> Void)? { get set }
  func requestAuthorization()
  func start()
  func stop()
}

/// Ayrı yönetici: il/ilçe tespitiyle pusula aboneliği birbirini kesmez.
@MainActor
private final class NativeQiblaSensor: NSObject, QiblaSensor, CLLocationManagerDelegate {
  private let manager = CLLocationManager()
  var onEvent: ((QiblaSensorEvent) -> Void)?
  var headingAvailable: Bool { CLLocationManager.headingAvailable() }
  var authorization: QiblaAuthorization { Self.authorization(manager.authorizationStatus) }

  override init() {
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    manager.headingFilter = 1
    manager.headingOrientation = .portrait
  }
  private static func authorization(_ status: CLAuthorizationStatus) -> QiblaAuthorization {
    switch status {
    case .authorizedAlways, .authorizedWhenInUse: .allowed
    case .notDetermined: .pending
    default: .denied
    }
  }
  func requestAuthorization() { manager.requestWhenInUseAuthorization() }
  func start() { manager.startUpdatingLocation(); manager.startUpdatingHeading() }
  func stop() { manager.stopUpdatingLocation(); manager.stopUpdatingHeading() }

  nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    let status = manager.authorizationStatus
    Task { @MainActor in self.onEvent?(.authorization(Self.authorization(status))) }
  }
  nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location = locations.last, location.horizontalAccuracy >= 0,
      abs(location.timestamp.timeIntervalSinceNow) < 60 else { return }
    let latitude = location.coordinate.latitude, longitude = location.coordinate.longitude
    Task { @MainActor in
      self.manager.stopUpdatingLocation()
      self.onEvent?(.location(latitude: latitude, longitude: longitude))
    }
  }
  nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
    let trueHeading = newHeading.trueHeading, magnetic = newHeading.magneticHeading, accuracy = newHeading.headingAccuracy
    Task { @MainActor in self.onEvent?(.heading(trueHeading: trueHeading, magneticHeading: magnetic, accuracy: accuracy)) }
  }
  nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    let code = (error as? CLError)?.code
    if code == .locationUnknown { return }
    let failure: QiblaFailure = code == .denied ? .permissionDenied : code == .headingFailure ? .headingUnavailable : .locationUnavailable
    Task { @MainActor in self.onEvent?(.failure(failure)) }
  }
}

@Observable
final class QiblaStore {
  static let shared = QiblaStore(sensor: NativeQiblaSensor())
  enum State: Equatable { case locating, ready, failure(QiblaFailure) }
  private(set) var state = State.locating
  private(set) var bearing = 0.0
  private(set) var heading = 0.0
  @ObservationIgnored private let sensor: any QiblaSensor
  @ObservationIgnored private let timeoutAfter: Duration?
  @ObservationIgnored private let emitFeedback: (QiblaMath.Feedback.Event) -> Void
  @ObservationIgnored private var active = false
  @ObservationIgnored private var started = false
  @ObservationIgnored private var hasLocation = false
  @ObservationIgnored private var hasHeading = false
  @ObservationIgnored private var feedback = QiblaMath.Feedback()
  @ObservationIgnored private var timeout: Task<Void, Never>?

  var alignment: QiblaMath.Alignment { .init(delta: QiblaMath.delta(bearing: bearing, heading: heading)) }

  init(sensor: any QiblaSensor, timeoutAfter: Duration? = .seconds(20),
    feedback: @escaping (QiblaMath.Feedback.Event) -> Void = { event in
      switch event {
      case .selection: Haptics.selection()
      case .success: Haptics.notify(.success)
      }
    }) {
    self.sensor = sensor
    self.timeoutAfter = timeoutAfter
    self.emitFeedback = feedback
    sensor.onEvent = { [weak self] in self?.receive($0) }
  }

  func start() {
    guard !active else { return }
    active = true
    state = .locating
    hasLocation = false
    hasHeading = false
    feedback = .init()
    #if DEBUG
    if sensor is NativeQiblaSensor, let preview = DebugLaunch.qibla {
      switch preview {
      case "denied": state = .failure(.permissionDenied)
      case "unavailable": state = .failure(.headingUnavailable)
      case "loading": break
      default:
        bearing = QiblaMath.bearing(latitude: 41.0082, longitude: 28.9784)!
        heading = bearing - (preview == "aligned" ? 0 : preview == "left" ? -32 : 32)
        state = .ready
      }
      return
    }
    #endif
    guard !(sensor is NativeQiblaSensor && DebugLaunch.isIsolated) else { return }
    authorize(sensor.authorization)
  }

  func stop() {
    active = false
    started = false
    timeout?.cancel()
    timeout = nil
    sensor.stop()
  }

  /// İç testler yalnız enjekte edilen sensörle çalışır; gerçek izin veya GPS açmaz.
  func receive(_ event: QiblaSensorEvent) {
    guard active, !(sensor is NativeQiblaSensor && DebugLaunch.isIsolated) else { return }
    switch event {
    case .authorization(let authorization): authorize(authorization)
    case .failure(let error): fail(error)
    case .location(let latitude, let longitude):
      guard started, let angle = QiblaMath.bearing(latitude: latitude, longitude: longitude) else { return }
      bearing = angle
      hasLocation = true
      update()
    case .heading(let trueHeading, let magneticHeading, let accuracy):
      guard started else { return }
      guard let value = QiblaMath.heading(trueHeading: trueHeading, magneticHeading: magneticHeading, accuracy: accuracy) else {
        if hasHeading {
          hasHeading = false
          state = .locating
          feedback = .init()
          waitForReading()
        }
        return
      }
      heading = hasHeading ? QiblaMath.smooth(previous: heading, next: value) : value
      hasHeading = true
      update()
    }
  }

  private func authorize(_ authorization: QiblaAuthorization) {
    switch authorization {
    case .pending: sensor.requestAuthorization()
    case .denied: fail(.permissionDenied)
    case .allowed:
      guard !started else { return }
      guard sensor.headingAvailable else { fail(.headingUnavailable); return }
      started = true
      sensor.start()
      waitForReading()
    }
  }
  private func waitForReading() {
    guard timeout == nil, let timeoutAfter else { return }
    timeout = Task { [weak self] in
      do { try await Task.sleep(for: timeoutAfter) } catch { return }
      guard let self, self.active, self.state == .locating else { return }
      self.fail(self.hasLocation ? .headingUnavailable : .locationUnavailable)
    }
  }
  private func update() {
    guard hasLocation && hasHeading else { return }
    state = .ready
    timeout?.cancel()
    timeout = nil
    for event in feedback.update(alignment) { emitFeedback(event) }
  }
  private func fail(_ error: QiblaFailure) {
    stop()
    state = .failure(error)
  }
}
