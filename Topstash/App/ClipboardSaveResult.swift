import TopstashCore

/// What saving the clipboard did, from a click on the save card or the global shortcut.
/// `AppModel.saveClipboard` returns it, and the card and the search view's status show it.
enum ClipboardSaveResult: Equatable, Sendable {
    /// The clipboard text is now a note.
    case saved(Note)
    /// A note already holds the clipboard text; nothing was written.
    case alreadySaved
    /// The clipboard holds no text, or only whitespace.
    case nothingToSave
    /// The clipboard holds text that Topstash isn't allowed to read (paste access denied).
    case accessDenied
    /// Writing the note failed. `AppModel.saveClipboard` has logged the error.
    case failed
}

@MainActor
extension ClipboardSaveResult {
    /// The save card while it shows this result.
    var cardState: SaveCardState {
        switch self {
        case .saved: .saved
        case .alreadySaved: .alreadySaved
        case .nothingToSave: .nothingToSave
        case .accessDenied: .accessDenied
        case .failed: .failed
        }
    }

    /// How long the card shows this result before returning to the clipboard's state, or `nil`
    /// when the result is the clipboard's state anyway.
    var cardRevertDelay: Double? {
        switch self {
        // The checkmark shows for the save feedback's length (#11), then the card returns.
        case .saved: Motion.saveFeedbackDuration
        case .nothingToSave: Motion.nothingToSaveDuration
        case .failed: Motion.failedDuration
        case .alreadySaved, .accessDenied: nil
        }
    }
}
