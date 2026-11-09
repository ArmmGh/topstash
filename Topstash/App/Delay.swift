/// Runs an action after a delay, replacing any pending run, and cancellable. Every "wait, then
/// reset or close" in the app uses one, so no caller has to remember to cancel the previous run.
@MainActor
final class DelayedAction {
    private let scheduler: any Scheduler
    private var pending: (any ScheduledRun)?

    /// Tests pass a scheduler they advance by hand; the app uses real time.
    init(scheduler: any Scheduler = TaskScheduler()) {
        self.scheduler = scheduler
    }

    /// True from `schedule` until the action runs or is cancelled.
    var isPending: Bool { pending != nil }

    /// Runs `action` after `seconds`, cancelling any run still pending.
    func schedule(after seconds: Double, _ action: @escaping @MainActor () -> Void) {
        cancel()
        pending = scheduler.schedule(after: seconds) { [weak self] in
            self?.pending = nil
            action()
        }
    }

    /// Stops the pending run, if any.
    func cancel() {
        pending?.cancel()
        pending = nil
    }
}

/// Where `DelayedAction` gets its time from.
@MainActor
protocol Scheduler {
    /// Runs `action` on the main actor after `seconds`, unless the returned run is cancelled first.
    func schedule(after seconds: Double, _ action: @escaping @MainActor () -> Void) -> any ScheduledRun
}

/// A run a `Scheduler` has scheduled.
@MainActor
protocol ScheduledRun {
    func cancel()
}

/// Real time: a task that sleeps, then runs the action unless it was cancelled meanwhile.
struct TaskScheduler: Scheduler {
    func schedule(after seconds: Double, _ action: @escaping @MainActor () -> Void) -> any ScheduledRun {
        Task { @MainActor in
            try? await Task<Never, Never>.sleep(for: .seconds(seconds))
            guard !Task<Never, Never>.isCancelled else { return }
            action()
        }
    }
}

extension Task: ScheduledRun where Success == Void, Failure == Never {}
