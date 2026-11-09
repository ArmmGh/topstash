/// The panel changes views ask for. Implemented by `NotchPanelController`, which owns the window,
/// so each action can change the panel's mode together with the window's key status and event
/// monitors. Views never assign `PanelModel.mode` themselves.
@MainActor
protocol PanelActions: AnyObject {
    /// "Show all": expands the panel into search mode (#5) with the search field focused.
    func showAll()
    /// Esc in search mode: closes the panel and hands keyboard focus back to the frontmost app.
    func closeSearch()
    /// Closes the panel after an action such as Open in Editor (#6). The cursor still over the
    /// fading panel doesn't bring it back.
    func dismissAfterAction()
}
