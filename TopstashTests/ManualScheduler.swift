@testable import Topstash

/// Stands in for real time: scheduled work runs only when a test calls `advance(by:)`, so delays
/// can be tested without waiting.
@MainActor
final class ManualScheduler: Scheduler {
    private final class Entry: ScheduledRun {
        let due: Double
        let action: @MainActor () -> Void
        var isCancelled = false

        init(due: Double, action: @escaping @MainActor () -> Void) {
            self.due = due
            self.action = action
        }

        func cancel() {
            isCancelled = true
        }
    }

    private(set) var now: Double = 0
    private var entries: [Entry] = []

    func schedule(after seconds: Double, _ action: @escaping @MainActor () -> Void) -> any ScheduledRun {
        let entry = Entry(due: now + seconds, action: action)
        entries.append(entry)
        return entry
    }

    /// Moves time forward, running every uncancelled action that falls due, earliest first.
    func advance(by seconds: Double) {
        let end = now + seconds
        while let next = entries.filter({ !$0.isCancelled && $0.due <= end }).min(by: { $0.due < $1.due }) {
            entries.removeAll { $0 === next }
            now = next.due
            next.action()
        }
        now = end
        entries.removeAll { $0.isCancelled }
    }
}
