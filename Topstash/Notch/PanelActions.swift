import TopstashCore

/// The panel changes views ask for. `NotchPanelController`, which owns the window, supplies them,
/// so each action can change the panel's mode together with the window's key status and event
/// monitors. Views never assign `PanelModel.mode` themselves.
@MainActor
struct PanelActions {
    /// The header's search button: expands the panel into search mode with the search field focused.
    var openSearch: () -> Void
    /// Esc, or the header's close button, in search mode: closes the panel and hands keyboard
    /// focus back to the frontmost app.
    var closeSearch: () -> Void
    /// Closes the panel after an action such as Open in Editor. The cursor still over the
    /// fading panel doesn't bring it back.
    var dismissAfterAction: () -> Void
    /// A click copied a note: closes the panel, as `dismissAfterAction` does, once "Copied" has shown.
    var dismissAfterCopy: () -> Void
    /// ⌥Return in search: copies the note, and, with the Settings toggle on, closes the panel and
    /// pastes it into the frontmost app. With the toggle off it does what Return does.
    var pasteFromSearch: (Note) -> Void
}
