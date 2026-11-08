import CoreGraphics
import Foundation
import Observation

/// UI state of the notch panel.
@MainActor @Observable
final class PanelModel {
    // #10 adds .feedback.
    enum Mode: Equatable {
        case closed
        case open
        /// The search field and the full list. The panel is key and stays open when the cursor leaves.
        case search
    }

    /// Closing resets `query`, so the next open shows the recent list with an empty query.
    var mode: Mode = .closed {
        didSet {
            if mode == .closed {
                query = ""
            }
            if mode != oldValue {
                onModeChange?(oldValue, mode)
            }
        }
    }
    /// Size of the visible shape, reported by `PanelView`.
    var contentSize: CGSize = .zero
    /// The row showing "Copied", cleared by `AppModel.copy` after a moment.
    var copiedNoteID: URL?
    /// Set by `AppModel.refreshSaveCard()` and by saving from the card.
    var saveCard: SaveCardState = .nothingToSave
    /// The search field's text.
    var query = ""

    /// Called after `mode` changes, with the old and new mode. `NotchPanelController` uses it to
    /// make the window key and watch for closing events while searching. Don't set `mode` from it.
    @ObservationIgnored
    var onModeChange: ((_ old: Mode, _ new: Mode) -> Void)?
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
