import Foundation
import Testing
@testable import Salah

@MainActor
struct QiblaMathTests {
  /// Değerler doğrudan RN qibla.service.ts çalıştırılarak alındı.
  @Test(arguments: [
    [41.0082, 28.9784, 151.62058989805803],
    [39.9334, 32.8597, 160.16823982747133],
    [51.5074, -0.1278, 118.98722399197209],
    [40.7128, -74.006, 58.48170604619469],
    [-6.2088, 106.8456, 295.15172450019486],
    [-33.8688, 151.2093, 277.4995789550928],
  ]) func matchesRNBearing(input: [Double]) throws {
    #expect(abs(try #require(QiblaMath.bearing(latitude: input[0], longitude: input[1])) - input[2]) < 1e-10)
  }

  @Test func rejectsInvalidAndUndefinedDirections() {
    #expect(QiblaMath.bearing(latitude: .nan, longitude: 0) == nil)
    #expect(QiblaMath.bearing(latitude: 91, longitude: 0) == nil)
    #expect(QiblaMath.bearing(latitude: 0, longitude: .infinity) == nil)
    #expect(QiblaMath.bearing(latitude: 0, longitude: 181) == nil)
    #expect(QiblaMath.bearing(latitude: QiblaMath.latitude, longitude: QiblaMath.longitude) == nil)
    #expect(QiblaMath.bearing(latitude: -QiblaMath.latitude, longitude: QiblaMath.longitude - 180) == nil)
  }

  @Test func turnsAcrossNorthAndRepeatedRotations() {
    #expect(QiblaMath.delta(bearing: 1, heading: 359) == 2)
    #expect(QiblaMath.delta(bearing: 359, heading: 1) == -2)
    #expect(QiblaMath.delta(bearing: 1, heading: 1079) == 2)
    #expect(QiblaMath.delta(bearing: 359, heading: -719) == -2)
    #expect(abs(QiblaMath.smooth(previous: 359, next: 1) - 359.3) < 1e-10)
    #expect(abs(QiblaMath.smooth(previous: 1079, next: 1) - 1079.3) < 1e-10)
    #expect(abs(QiblaMath.smooth(previous: -719, next: 359) + 719.3) < 1e-10)
  }

  @Test func prefersTrueNorthAndRejectsUncalibratedReadings() {
    #expect(QiblaMath.heading(trueHeading: 42, magneticHeading: 50, accuracy: 1) == 42)
    #expect(QiblaMath.heading(trueHeading: -1, magneticHeading: 50, accuracy: 1) == 50)
    #expect(QiblaMath.heading(trueHeading: .nan, magneticHeading: 361, accuracy: 0) == 1)
    #expect(QiblaMath.heading(trueHeading: 42, magneticHeading: 50, accuracy: -1) == nil)
    #expect(QiblaMath.heading(trueHeading: -1, magneticHeading: -1, accuracy: 1) == nil)
  }

  @Test func alignmentThresholdsMatchRNAndDoNotRepeatFeedback() {
    #expect(!QiblaMath.Alignment(delta: 5).aligned)
    #expect(QiblaMath.Alignment(delta: -4.99).aligned)
    #expect(QiblaMath.Alignment(delta: 45).closeness == 0)
    #expect(QiblaMath.Alignment(delta: 0).closeness == 1)
    var feedback = QiblaMath.Feedback()
    #expect(feedback.update(.init(delta: 30)).isEmpty)
    #expect(feedback.update(.init(delta: 24)) == [.selection])
    #expect(feedback.update(.init(delta: 12)).isEmpty)
    #expect(feedback.update(.init(delta: 9)) == [.selection])
    #expect(feedback.update(.init(delta: 4)) == [.success])
    #expect(feedback.update(.init(delta: -4)).isEmpty)
    #expect(feedback.update(.init(delta: 7)).isEmpty)
    #expect(feedback.update(.init(delta: 3)) == [.success])
    #expect(feedback.update(.init(delta: 26)).isEmpty)
    #expect(feedback.update(.init(delta: 24)) == [.selection])
  }
}

@MainActor
private final class FakeQiblaSensor: QiblaSensor {
  var authorization = QiblaAuthorization.allowed
  var headingAvailable = true
  var onEvent: ((QiblaSensorEvent) -> Void)?
  var requests = 0, starts = 0, stops = 0
  func requestAuthorization() { requests += 1 }
  func start() { starts += 1 }
  func stop() { stops += 1 }
  func send(_ event: QiblaSensorEvent) { onEvent?(event) }
  func location() { send(.location(latitude: 41.0082, longitude: 28.9784)) }
  func heading(_ value: Double, accuracy: Double = 1) { send(.heading(trueHeading: value, magneticHeading: value, accuracy: accuracy)) }
}

@MainActor
struct QiblaLifecycleTests {
  @Test func waitsForPermissionThenBothReadings() {
    let sensor = FakeQiblaSensor()
    sensor.authorization = .pending
    var events: [QiblaMath.Feedback.Event] = []
    let store = QiblaStore(sensor: sensor, timeoutAfter: nil, feedback: { events.append($0) })
    store.start()
    #expect(sensor.requests == 1 && sensor.starts == 0 && store.state == .locating)
    sensor.heading(151.62058989805803)
    sensor.location()
    #expect(store.state == .locating && events.isEmpty)
    sensor.send(.authorization(.allowed))
    sensor.heading(151.62058989805803)
    #expect(store.state == .locating && events.isEmpty)
    sensor.location()
    #expect(store.state == .ready && store.alignment.aligned)
    #expect(events == [.selection, .success])
    sensor.heading(151.62058989805803)
    #expect(events == [.selection, .success])
    store.stop()
  }

  @Test func deniedPermissionAndMissingCompassNeverStartSensors() {
    let sensor = FakeQiblaSensor()
    sensor.authorization = .denied
    let store = QiblaStore(sensor: sensor, timeoutAfter: nil, feedback: { _ in })
    store.start()
    #expect(store.state == .failure(.permissionDenied) && sensor.starts == 0)
    sensor.authorization = .allowed
    sensor.headingAvailable = false
    store.start()
    #expect(store.state == .failure(.headingUnavailable) && sensor.starts == 0)
    sensor.headingAvailable = true
    store.start()
    #expect(sensor.starts == 1 && store.state == .locating)
    store.stop()
  }

  @Test func stopsOnceAndIgnoresLateCallbacksUntilResume() {
    let sensor = FakeQiblaSensor()
    let store = QiblaStore(sensor: sensor, timeoutAfter: nil, feedback: { _ in })
    store.start()
    store.start()
    #expect(sensor.starts == 1)
    store.stop()
    sensor.send(.authorization(.allowed))
    sensor.location()
    sensor.heading(151.62058989805803)
    #expect(sensor.starts == 1 && store.state == .locating)
    store.start()
    #expect(sensor.starts == 2)
    sensor.location()
    #expect(store.state == .locating)
    sensor.heading(0)
    #expect(store.state == .ready)
    sensor.send(.authorization(.denied))
    #expect(store.state == .failure(.permissionDenied))
    sensor.send(.authorization(.allowed))
    #expect(sensor.starts == 2)
  }

  @Test func invalidHeadingRemovesAlignmentUntilValidDataReturns() {
    let sensor = FakeQiblaSensor()
    let store = QiblaStore(sensor: sensor, timeoutAfter: nil, feedback: { _ in })
    store.start()
    sensor.location()
    sensor.heading(151.62058989805803)
    #expect(store.state == .ready && store.alignment.aligned)
    sensor.heading(151.62058989805803, accuracy: -1)
    #expect(store.state == .locating)
    sensor.heading(10)
    #expect(store.state == .ready && !store.alignment.aligned && store.heading == 10)
    store.stop()
  }

  @Test func timesOutMissingReadingsAndCanRetry() async throws {
    let sensor = FakeQiblaSensor()
    let store = QiblaStore(sensor: sensor, timeoutAfter: .milliseconds(1), feedback: { _ in })
    store.start()
    try await Task.sleep(for: .milliseconds(30))
    #expect(store.state == .failure(.locationUnavailable))
    store.start()
    sensor.location()
    try await Task.sleep(for: .milliseconds(30))
    #expect(store.state == .failure(.headingUnavailable))
    store.start()
    sensor.location()
    sensor.heading(0)
    try await Task.sleep(for: .milliseconds(30))
    #expect(store.state == .ready)
    store.stop()
  }
}
