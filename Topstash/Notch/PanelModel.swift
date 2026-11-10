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

    /// Closing resets `query` and the selection, so the next open shows the recent list with an empty query.
    /// Every change collapses the peek, so each open starts with every row collapsed.
    /// Only `NotchPanelController` sets it, together with what the window does in each mode; views
    /// ask for changes through `PanelActions`. Setting it has no effect on windows or focus.
    var mode: Mode = .closed {
        didSet {
            if mode != oldValue {
                peek = nil
                // The rows it shows go away without reporting the cursor leaving.
                hoveredNote = nil
            }
            if mode == .closed {
                query = ""
                selection = 0
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
    /// The search field's text. A new query selects the first result.
    var query = "" {
        // The field sets its text again on Return, so only a different query resets the selection.
        didSet {
            if query != oldValue {
                selection = 0
                peek = nil
            }
        }
    }
    /// The keyboard selection: an index into the search results, which may outlast results that
    /// were deleted. Read it through `selectedResult(among:)`.
    private var selection = 0
    /// Shown next to the search field for a moment.
    var searchStatus: SearchStatus?
    /// The selected search result's index among `count` results: the first as you type, and never
    /// past the last. `nil` with no results.
    func selectedResult(among count: Int) -> Int? {
        count > 0 ? min(selection, count - 1) : nil
    }

    /// ↑ (-1) or ↓ (+1): moves the selection among `count` results, stopping at the ends.
    func moveSelection(by step: Int, among count: Int) {
        guard let current = selectedResult(among: count) else { return }
        selection = min(max(current + step, 0), count - 1)
    }

    // MARK: Peek

    /// The row expanded in place to show its note's text, if any. At most one row peeks.
    private(set) var peek: NotePeek?
    /// The `Note.id` of the row that peeks.
    var peekedNote: Note.ID? { peek?.note }

    /// Expands the note's row in place, collapsing any other, or collapses it if it already peeks.
    /// Never copies. The text and the row's extra height are worked out here, once per expansion.
    func togglePeek(_ note: Note) {
        if peek?.note == note.id {
            peek = nil
        } else {
            let text = note.peekText
            peek = NotePeek(note: note.id, text: text, lineCount: PanelLayout.peekLineCount(text))
        }
    }

    /// Collapses the row that peeks, if any.
    func collapsePeek() {
        peek = nil
    }

    // MARK: Force click

    /// The row under the cursor, which a force click peeks. Set by `NoteList` as rows report hover.
    private(set) var hoveredNote: Note?
    /// The row whose next click mustn't copy: the mouse-up that ends a force click.
    private var copySuppressedNote: Note.ID?
    /// Set once a force click has acted during the current press, so the Look up hook and pressure
    /// stage 2 together toggle only once.
    private var pressForceClicked = false

    /// A row reports the cursor entering (`true`) or leaving it. Leaving one row may be reported
    /// after entering the next, so it only clears the row it's about.
    func hover(_ note: Note, _ isHovering: Bool) {
        if isHovering {
            hoveredNote = note
        } else if hoveredNote?.id == note.id {
            hoveredNote = nil
        }
    }

    /// The primary button went down in the panel. A new press starts uncounted, and a force click
    /// released off its row doesn't hold back this click's copy.
    func pressBegan() {
        pressForceClicked = false
        copySuppressedNote = nil
    }

    /// A force click: the Look up hook (`quickLook(with:)`) or pressure stage 2. Toggles the hovered
    /// row's peek. With the button down, it acts once per press and the press's mouse-up then skips
    /// the copy. With it up, it's a three-finger tap: no mouse-up follows, so nothing is held back.
    func forceClick(buttonIsDown: Bool) {
        guard let note = hoveredNote else { return }
        guard buttonIsDown else {
            togglePeek(note)
            return
        }
        guard !pressForceClicked else { return }
        pressForceClicked = true
        togglePeek(note)
        copySuppressedNote = note.id
    }

    /// Whether the click on the note's row should skip its copy. True once after a force click.
    func consumeCopySuppression(_ note: Note.ID) -> Bool {
        defer { copySuppressedNote = nil }
        return copySuppressedNote == note
    }

    /// True in `.feedback`, and kept while closing from it, so the list doesn't pop in during the fade.
    private(set) var showsOnlySaveCard = false

    // MARK: Shape and motion

    /// The shape's size while closed: the notch of the screen the panel is on, or, on screens
    /// without one, the hover strip's width with no height, so nothing is drawn.
    /// Set by `NotchPanelController` when it places the window.
    var closedSize = CGSize(width: PanelLayout.fallbackHoverWidth, height: PanelLayout.hiddenMenuBarHoverHeight)
    /// The header band's height: the notch's, or the menu bar's on screens without one
    /// (`PanelLayout.headerHeight(forHoverAreaHeight:)`). Set by `NotchPanelController` with `closedSize`.
    var headerHeight = PanelLayout.headerHeight(forHoverAreaHeight: PanelLayout.hiddenMenuBarHoverHeight)
    /// The notch's width, which the header keeps clear, or 0 on screens without a notch, where
    /// the closed shape has no height.
    var notchWidth: CGFloat { closedSize.height > 0 ? closedSize.width : 0 }
    /// Counts new saves, bumped by `AppModel` with the haptic. Its changes trigger the checkmark
    /// bounce and the notch's gulp.
    var saveCount = 0
    /// Counts copies, bumped by `AppModel` with the haptic. Its changes bounce the "Copied" checkmark,
    /// also when the row already shows it.
    var copyCount = 0
}

/// A row expanded in place: whose, what it shows, and how much taller than `PanelLayout.rowHeight` it is.
struct NotePeek: Equatable {
    let note: Note.ID
    /// `Note.peekText`.
    let text: String
    /// `PanelLayout.peekLineCount(_:)` of `text`: the lines shown before it scrolls. 0 when it's empty.
    let lineCount: Int
    /// What the peek adds to its row, which the shape's height and the row's follow.
    var extraHeight: CGFloat { PanelLayout.peekExtraHeight(lines: lineCount) }
    /// The height of the peek's text, under the title line.
    var bodyHeight: CGFloat { PanelLayout.peekBodyHeight(lines: lineCount) }
}

/// What the search view shows next to its field for a moment.
enum SearchStatus: Equatable {
    /// The save shortcut's result while searching.
    case saveResult(ClipboardSaveResult)
    /// ⌥Return copied the note but couldn't paste it: Topstash lacks Accessibility access.
    case pasteNeedsAccess
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
    /// The clipboard has text marked concealed, such as a password: "Hidden content", no preview.
    case concealed
    case alreadySaved
    case nothingToSave
    /// Transient, after a successful save.
    case saved
    /// Transient, after a save threw.
    case failed
}
