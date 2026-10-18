import Foundation
import Testing
@testable import Salah

@MainActor
struct OfflineQueueTests {
  private final class Fixture {
    var items: [OfflineQueue.Item] = []
    var sent: [OfflineQueue.Item] = []
    var failure: (any Error)?
    var continuation: CheckedContinuation<Void, Never>?
    var pauseNext = false

    func queue() -> OfflineQueue {
      OfflineQueue(read: { self.items }, write: { self.items = $0 }, send: { item in
        self.sent.append(item)
        if self.pauseNext {
          self.pauseNext = false
          await withCheckedContinuation { self.continuation = $0 }
        }
        if let failure = self.failure { throw failure }
      })
    }

    func waitForSend() async throws {
      for _ in 0..<1000 {
        if continuation != nil { return }
        await Task.yield()
      }
      throw Failure.didNotSuspend
    }

    func resume() {
      continuation?.resume()
      continuation = nil
    }
  }

  private enum Failure: Error { case didNotSuspend, unexpected }

  @Test func decodesAndReplaysRNPersistedQueueInOrder() async throws {
    let fixture = Fixture()
    let raw = #"[{"id":"q_1_abc","method":"post","url":"/gamification/track","body":{"prayerId":"dhuhr","date":"2026-10-17"},"queuedAt":"2026-10-17T09:00:00.000Z"},{"id":"q_2_xyz","method":"delete","url":"/tracker/42","clientRef":"offline-42","queuedAt":"2026-10-17T09:01:00.000Z"}]"#
    fixture.items = try JSONDecoder().decode([OfflineQueue.Item].self, from: Data(raw.utf8))
    let queue = fixture.queue()
    #expect(queue.pendingCount == 2)
    #expect(queue.pendingClientRefs() == ["offline-42"])
    #expect(await queue.flush() == 2)
    #expect(fixture.sent.map(\.id) == ["q_1_abc", "q_2_xyz"])
    #expect(fixture.sent[0].body?["date"]?.stringValue == "2026-10-17")
    #expect(fixture.sent[1].body == nil)
    #expect(queue.pendingCount == 0)
  }

  @Test func newEntryDuringSendSurvivesAndIsSentNext() async throws {
    let fixture = Fixture()
    let queue = fixture.queue()
    queue.enqueue(method: "post", url: "/first", body: nil)
    fixture.pauseNext = true
    let flush = Task { await queue.flush() }
    try await fixture.waitForSend()
    queue.enqueue(method: "delete", url: "/second", body: nil, clientRef: "new")
    #expect(queue.pendingCount == 2)
    fixture.resume()
    #expect(await flush.value == 2)
    #expect(fixture.sent.map(\.url) == ["/first", "/second"])
    #expect(queue.pendingCount == 0)
  }

  @Test func removedWaitingEntryIsNeverReintroduced() async throws {
    let fixture = Fixture()
    let queue = fixture.queue()
    queue.enqueue(method: "post", url: "/first", body: nil)
    queue.enqueue(method: "post", url: "/cancelled", body: nil, clientRef: "cancel")
    fixture.pauseNext = true
    let flush = Task { await queue.flush() }
    try await fixture.waitForSend()
    queue.remove(clientRef: "cancel")
    fixture.resume()
    #expect(await flush.value == 1)
    #expect(fixture.sent.map(\.url) == ["/first"])
    #expect(fixture.items.isEmpty)
  }

  @Test func editedWaitingEntryUsesLatestBody() async throws {
    let fixture = Fixture()
    let queue = fixture.queue()
    queue.enqueue(method: "post", url: "/first", body: nil)
    queue.enqueue(method: "post", url: "/tracker", body: ["notes": "before"], clientRef: "edit")
    fixture.pauseNext = true
    let flush = Task { await queue.flush() }
    try await fixture.waitForSend()
    #expect(queue.update(clientRef: "edit") { _ in ["notes": "after"] })
    fixture.resume()
    #expect(await flush.value == 2)
    #expect(fixture.sent.last?.body?["notes"]?.stringValue == "after")
  }

  @Test func overlappingFlushDoesNotDuplicateRequests() async throws {
    let fixture = Fixture()
    let queue = fixture.queue()
    queue.enqueue(method: "post", url: "/first", body: nil)
    fixture.pauseNext = true
    let flush = Task { await queue.flush() }
    try await fixture.waitForSend()
    #expect(queue.isFlushing)
    #expect(await queue.flush() == 0)
    fixture.resume()
    #expect(await flush.value == 1)
    #expect(fixture.sent.count == 1)
    #expect(!queue.isFlushing)
  }

  @Test func networkFailurePreservesConcurrentEntryAndSurvivesReload() async throws {
    let fixture = Fixture()
    let queue = fixture.queue()
    queue.enqueue(method: "post", url: "/first", body: nil)
    fixture.pauseNext = true
    fixture.failure = APIError.network(URLError(.notConnectedToInternet))
    let flush = Task { await queue.flush() }
    try await fixture.waitForSend()
    queue.enqueue(method: "post", url: "/new", body: nil)
    fixture.resume()
    #expect(await flush.value == 0)
    #expect(queue.pendingCount == 2)
    #expect(!queue.isFlushing)
    fixture.failure = nil
    fixture.sent = []
    let relaunched = fixture.queue()
    #expect(await relaunched.flush() == 2)
    #expect(fixture.sent.map(\.url) == ["/first", "/new"])
  }

  @Test func serverAndUnexpectedFailuresKeepRequestsForRetry() async {
    let fixture = Fixture()
    let queue = fixture.queue()
    queue.enqueue(method: "post", url: "/first", body: nil)
    for error in [APIError.http(status: 503, body: Data()) as any Error, Failure.unexpected] {
      fixture.failure = error
      #expect(await queue.flush() == 0)
      #expect(queue.pendingCount == 1)
      #expect(!queue.isFlushing)
    }
    fixture.failure = nil
    #expect(await queue.flush() == 1)
  }

  @Test func permanentClientFailureDropsOnlyFailedEntryAndContinues() async {
    let fixture = Fixture()
    var sent: [String] = []
    let queue = OfflineQueue(read: { fixture.items }, write: { fixture.items = $0 }, send: { item in
      sent.append(item.url)
      if item.url == "/invalid" { throw APIError.http(status: 400, body: Data()) }
    })
    queue.enqueue(method: "post", url: "/invalid", body: nil)
    queue.enqueue(method: "post", url: "/valid", body: nil)
    var callbackCount: Int?
    queue.onFlushed = { callbackCount = $0 }
    #expect(await queue.flush() == 1)
    #expect(sent == ["/invalid", "/valid"])
    #expect(callbackCount == 1)
    #expect(queue.pendingCount == 0)
  }

  @Test(arguments: [401, 403, 408, 429])
  func recoverableClientFailurePreservesQueue(status: Int) async {
    let fixture = Fixture()
    let queue = fixture.queue()
    queue.enqueue(method: "post", url: "/first", body: nil)
    queue.enqueue(method: "delete", url: "/second", body: nil)
    fixture.failure = APIError.http(status: status, body: Data())
    #expect(await queue.flush() == 0)
    #expect(queue.pendingCount == 2)
    #expect(fixture.sent.map(\.url) == ["/first"])
    fixture.failure = nil
    #expect(await queue.flush() == 2)
  }

  @Test func sessionBecomingUnavailableStopsBeforeNextRequest() async throws {
    let fixture = Fixture()
    var ready = true
    let queue = OfflineQueue(read: { fixture.items }, write: { fixture.items = $0 }, send: { item in
      fixture.sent.append(item)
      await withCheckedContinuation { fixture.continuation = $0 }
    }, canFlush: { ready })
    queue.enqueue(method: "post", url: "/first", body: nil)
    queue.enqueue(method: "post", url: "/second", body: nil)
    let flush = Task { await queue.flush() }
    try await fixture.waitForSend()
    ready = false
    fixture.resume()
    #expect(await flush.value == 1)
    #expect(fixture.sent.map(\.url) == ["/first"])
    #expect(fixture.items.map(\.url) == ["/second"])
    #expect(queue.pendingCount == 1)
  }

  @Test func isolatedQueueDoesNotSendOrRemoveAnything() async {
    let fixture = Fixture()
    var called = false
    let queue = OfflineQueue(read: { fixture.items }, write: { fixture.items = $0 }, send: { _ in called = true }, canFlush: { false })
    queue.enqueue(method: "post", url: "/tracker", body: nil)
    #expect(await queue.flush() == 0)
    #expect(!called)
    #expect(queue.pendingCount == 1)
  }
}
