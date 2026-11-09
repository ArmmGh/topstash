/// Runs `action` after `seconds` and returns a function that cancels it. The app uses
/// `DelayedAction.realTime`; tests pass a clock they advance by hand.
typealias Schedule = @MainActor (_ seconds: Double, _ action: @escaping @MainActor () -> Void) -> @MainActor () -> Void

/// Runs an action after a delay, replacing any pending run, and cancellable. Every "wait, then
/// reset or close" in the app uses one, so no caller has to remember to cancel the previous run.
@MainActor
final class DelayedAction {
    private let scheduleRun: Schedule
    private var cancelPending: (@MainActor () -> Void)?

    init(schedule: @escaping Schedule = DelayedAction.realTime) {
        scheduleRun = schedule
    }

    /// Runs `action` after `seconds`, cancelling any run still pending.
    func schedule(after seconds: Double, _ action: @escaping @MainActor () -> Void) {
        cancel()
        cancelPending = scheduleRun(seconds) { [weak self] in
            self?.cancelPending = nil
            action()
        }
    }

    /// Stops the pending run, if any.
    func cancel() {
        cancelPending?()
        cancelPending = nil
    }

    /// Real time: a task that sleeps, then runs the action unless it was cancelled meanwhile.
    static func realTime(
        _ seconds: Double, _ action: @escaping @MainActor () -> Void
    ) -> @MainActor () -> Void {
        let task = Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            action()
        }
        return { task.cancel() }
    }
}
