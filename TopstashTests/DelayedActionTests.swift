import Testing

@testable import Topstash

/// `DelayedAction`: run after a delay, replacing any pending run, cancellable.
@MainActor
struct DelayedActionTests {
    let scheduler = ManualScheduler()

    @Test func runsOnceTheDelayHasPassed() {
        let delayed = DelayedAction(schedule: scheduler.schedule)
        var runs = 0

        delayed.schedule(after: 1) { runs += 1 }
        scheduler.advance(by: 0.9)
        #expect(runs == 0)

        scheduler.advance(by: 0.1)
        #expect(runs == 1)
    }

    @Test func aNewerScheduleReplacesTheOlderOne() {
        let delayed = DelayedAction(schedule: scheduler.schedule)
        var ran: [String] = []

        delayed.schedule(after: 1) { ran.append("first") }
        scheduler.advance(by: 0.5)
        delayed.schedule(after: 1) { ran.append("second") }
        scheduler.advance(by: 0.9)
        #expect(ran.isEmpty)

        scheduler.advance(by: 0.1)
        #expect(ran == ["second"])
    }

    @Test func cancellingStopsThePendingRun() {
        let delayed = DelayedAction(schedule: scheduler.schedule)
        var runs = 0

        delayed.schedule(after: 1) { runs += 1 }
        delayed.cancel()
        scheduler.advance(by: 2)

        #expect(runs == 0)
    }

    /// The real scheduler, with a tiny delay: the kept run happens, the cancelled one never does.
    @Test func realTimeRunsAfterTheDelayAndCancelStopsIt() async throws {
        let kept = DelayedAction()
        let cancelled = DelayedAction()
        var ran: [String] = []

        kept.schedule(after: 0.01) { ran.append("kept") }
        cancelled.schedule(after: 0.01) { ran.append("cancelled") }
        cancelled.cancel()
        try await Task.sleep(for: .milliseconds(200))

        #expect(ran == ["kept"])
    }
}
