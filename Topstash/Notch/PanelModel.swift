import CoreGraphics
import Foundation
import Observation

/// UI state of the notch panel.
@MainActor @Observable
final class PanelModel {
    // #5 adds .search, #10 adds .feedback.
    enum Mode: Equatable {
        case closed
        case open
    }

    var mode: Mode = .closed
    /// Size of the visible shape, reported by `PanelView`.
    var contentSize: CGSize = .zero
    /// The row showing "Copied", cleared by `AppModel.copy` after a moment.
    var copiedNoteID: URL?
    /// Set by `AppModel.refreshSaveCard()` and by saving from the card.
    var saveCard: SaveCardState = .nothingToSave
}

/// What the save card shows. Only `.preview` and `.readyWithoutPreview` are clickable.
enum SaveCardState: Equatable {
    /// The clipboard text, unsaved.
    case preview(text: String, characterCount: Int)
    /// The clipboard has text, but reading it would show the paste privacy alert (#4).
    case readyWithoutPreview
    /// The clipboard has text, but the user denied paste access (#4).
    case accessDenied
    case alreadySaved
    case nothingToSave
    /// Transient, after a successful save.
    case saved
    /// Transient, after a save threw.
    case failed
}
