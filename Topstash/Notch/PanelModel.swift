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
    /// Every change collapses the peek, so each open starts with every row collapsed, and Space types.
    /// Only `NotchPanelController` sets it, together with what the window does in each mode; views
    /// ask for changes through `PanelActions`. Setting it has no effect on windows or focus.
    var mode: Mode = .closed {
        didSet {
            if mode != oldValue {
                peek = nil
                spaceTogglesPeek = false
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
                spaceTogglesPeek = false
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

    /// ↑ (-1) or ↓ (+1): moves the selection among `count` results, stopping at the ends, and
    /// collapses the peek. Space then toggles the selected result's peek.
    func moveSelection(by step: Int, among count: Int) {
        peek = nil
        guard let current = selectedResult(among: count) else { return }
        selection = min(max(current + step, 0), count - 1)
        spaceTogglesPeek = true
    }

    /// Whether Space toggles the selected result's peek rather than typing a space: only right
    /// after ↑/↓, like Quick Look in Finder, so multi-word queries still type.
    private(set) var spaceTogglesPeek = false

    /// Space in search: toggles the selected one of `results`' peek and returns true if ↑/↓ came
    /// last, or returns false so the field types the space.
    func pressSpace(among results: [Note]) -> Bool {
        guard spaceTogglesPeek, let index = selectedResult(among: results.count) else { return false }
        togglePeek(results[index])
        return true
    }

    /// Any key in search but plain Space and ↑/↓: the next Space types a space.
    func pressOtherKey() {
        spaceTogglesPeek = false
    }

    /// Esc in search: collapses the peek and returns true, or returns false with no peek, so Esc
    /// closes the panel.
    func pressEscape() -> Bool {
        guard peek != nil else { return false }
        peek = nil
        return true
    }

    // MARK: Peek

    /// The row expanded in place to show its note's text, if any. At most one row peeks.
    private(set) var peek: NotePeek?
    /// The `Note.id` of the row that peeks.
    var peekedNote: Note.ID? { peek?.note }

    /// Expands the note's row in place, collapsing any other, or collapses it if it already peeks.
    /// Never copies. The text, its search matches and the row's extra height are worked out here,
    /// once per expansion; a new query collapses the peek, so its matches never go stale.
    func togglePeek(_ note: Note) {
        if peek?.note == note.id {
            peek = nil
        } else {
            let text = note.peekText
            let matches = mode == .search ? SearchSnippet.matches(of: query, in: text) : []
            let scrollOffset = matches.first.map { PanelLayout.peekScrollOffset(showing: $0.lowerBound, in: text) }
            peek = NotePeek(
                note: note.id, text: text, lineCount: PanelLayout.peekLineCount(text), matches: matches,
                scrollOffset: scrollOffset ?? 0)
        }
    }

    /// Collapses the row that peeks, if any.
    func collapsePeek() {
        peek = nil
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
    /// In search, every place a query word appears in `text` (`SearchSnippet.matches(of:in:)`),
    /// shown in `metaMatch`. Empty in the recent list.
    var matches: [Range<String.Index>] = []
    /// How far the peek opens scrolled, to show the first of `matches`
    /// (`PanelLayout.peekScrollOffset(showing:in:)`). 0 without matches.
    var scrollOffset: CGFloat = 0
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
