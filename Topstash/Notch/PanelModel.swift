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
        /// Only the save card, showing the result of the global shortcut. Never key.
        case feedback
    }

    /// Closing resets `query`, so the next open shows the recent list with an empty query.
    /// Only `NotchPanelController` sets it, together with what the window does in each mode; views
    /// ask for changes through `PanelActions`. Setting it has no effect on windows or focus.
    var mode: Mode = .closed {
        didSet {
            if mode == .closed {
                query = ""
                searchStatus = nil
            } else {
                showsOnlySaveCard = mode == .feedback
            }
        }
    }
    /// The `Note.id` (file URL) of the row showing "Copied", cleared by `AppModel.copy` after a moment.
    var copiedNote: Note.ID?
    /// Set by `AppModel.refreshSaveCard()` and `AppModel.showSaveResult(_:reverts:)`.
    var saveCard: SaveCardState = .nothingToSave {
        didSet {
            // The checkmark takes the place of the card that flew up, so the panel doesn't resize
            // under it; the next card brings its own height.
            if saveCard != .saved { saveCardHeight = PanelLayout.saveCardHeight(for: saveCard) }
        }
    }
    /// The card slot's height, which the shape's height depends on: `PanelLayout.saveCardHeight(for:)`
    /// of the card shown, or of the card before `.saved`.
    private(set) var saveCardHeight = PanelLayout.saveCardHeight(for: .nothingToSave)
    /// The search field's text.
    var query = ""
    /// The shortcut's result while searching, shown next to the search field for a moment.
    var searchStatus: ClipboardSaveResult?
    /// True in `.feedback`, and kept while closing from it, so the list doesn't pop in during the fade.
    private(set) var showsOnlySaveCard = false

    // MARK: Shape and motion

    /// The shape's size while closed: the notch of the screen the panel is on, or, on screens
    /// without one, the hover strip's width with no height, so nothing is drawn.
    /// Set by `NotchPanelController` when it places the window.
    var closedSize = CGSize(width: PanelLayout.fallbackHoverWidth, height: PanelLayout.hiddenMenuBarHoverHeight)
    /// Counts new saves, bumped by `AppModel` with the haptic. Its changes trigger the checkmark
    /// bounce and the notch's gulp.
    var saveCount = 0
}

/// What the save card shows. Only `.preview` and `.readyWithoutPreview` are clickable.
/// After a save it shows the result's `ClipboardSaveResult.cardState`. Its own cases rather than a
/// wrapped `ClipboardSaveResult`: `refreshSaveCard()` reaches most of them without a save, and the
/// card has no use for the saved `Note`.
enum SaveCardState: Equatable {
    /// The clipboard text, unsaved: only the part the card shows (`SaveCard.previewText`), and the
    /// full text's length.
    case preview(text: String, characterCount: Int)
    /// The clipboard has text, but reading it would show the paste privacy alert.
    case readyWithoutPreview
    /// The clipboard has text, but the user denied paste access.
    case accessDenied
    case alreadySaved
    case nothingToSave
    /// Transient, after a successful save.
    case saved
    /// Transient, after a save threw.
    case failed
}
