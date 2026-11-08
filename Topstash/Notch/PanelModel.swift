import CoreGraphics
import Foundation
import Observation
import TopstashCore

/// UI state of the notch panel.
@MainActor @Observable
final class PanelModel {
    enum Mode: Equatable {
        case closed
        case open
        /// The search field and the full list. The panel is key and stays open when the cursor leaves.
        case search
        /// Only the save card, showing the result of the global shortcut (#10). Never key.
        case feedback
    }

    /// Closing resets `query`, so the next open shows the recent list with an empty query.
    var mode: Mode = .closed {
        didSet {
            if mode == .closed {
                query = ""
                searchStatus = nil
            } else {
                showsOnlySaveCard = mode == .feedback
            }
            if mode != oldValue {
                onModeChange?(oldValue, mode)
            }
        }
    }
    /// Size of the visible shape, reported by `PanelView`.
    var contentSize: CGSize = .zero
    /// The `Note.id` (file URL) of the row showing "Copied", cleared by `AppModel.copy` after a moment.
    var copiedNote: Note.ID?
    /// Set by `AppModel.refreshSaveCard()` and `AppModel.showSaveResult(_:reverts:)`.
    var saveCard: SaveCardState = .nothingToSave
    /// The search field's text.
    var query = ""
    /// The shortcut's result while searching (#10), shown next to the search field for a moment.
    /// One of `.saved`, `.alreadySaved`, `.nothingToSave`, `.failed`.
    var searchStatus: SaveCardState?
    /// True in `.feedback`, and kept while closing from it, so the list doesn't pop in during the fade.
    private(set) var showsOnlySaveCard = false

    // MARK: Shape and motion (#11)

    /// The shape's size while closed: the hover area of the screen the panel is on (the notch,
    /// or the strip on screens without one). Set by `NotchPanelController` when it places the window.
    var closedSize = CGSize(width: PanelLayout.fallbackHoverWidth, height: PanelLayout.hiddenMenuBarHoverHeight)
    /// Counts new saves, bumped by `AppModel` with the haptic. Its changes trigger the checkmark
    /// bounce and the notch's gulp (#11).
    var saveCount = 0

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
