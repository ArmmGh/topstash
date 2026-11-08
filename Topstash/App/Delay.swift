extension Task where Success == Void, Failure == Never {
    /// Runs `action` on the main actor after `seconds`, unless the task is cancelled first.
    /// Every "wait, then reset or close" in the app uses it; keep the task to cancel or replace it.
    @MainActor
    static func afterDelay(_ seconds: Double, perform action: @escaping @MainActor () -> Void) -> Task<Void, Never> {
        Task {
            try? await Task<Never, Never>.sleep(for: .seconds(seconds))
            guard !Task<Never, Never>.isCancelled else { return }
            action()
        }
    }
}
