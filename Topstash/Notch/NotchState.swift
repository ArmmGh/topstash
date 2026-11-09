import AppKit

/// What the open/close rules look at when the mouse moves, a timer ends, or the screens change.
struct NotchSurroundings {
    /// In global screen coordinates, as `NSEvent.mouseLocation` reports it.
    var cursor: NSPoint
    /// One per connected screen.
    var hoverAreas: [HoverArea]
    /// The visible shape of the panel while its window is ordered in, else `.zero`.
    var visibleShape: NSRect
    var mode: PanelModel.Mode
    /// True while any menu of the app is open. The menu is its own window, so the cursor on it
    /// would count as outside the panel; mouse moves are ignored until it closes.
    var isMenuTracking: Bool
}

/// What `NotchPanelController` does after a transition of `NotchState`.
enum NotchEffect: Equatable {
    /// Waits for the hover delay on that screen, replacing any running delay, then reports
    /// `hoverDelayEnded(on:)`.
    case startHoverDelay(CGDirectDisplayID)
    case cancelHoverDelay
    /// Places the window on the screen and opens the panel as `.open`, ending a running close.
    case open(CGDirectDisplayID)
    /// Places the window on the screen and opens the panel as `.search`, which makes it key so the
    /// field takes typing. From any mode, ending a running close.
    case openSearch(CGDirectDisplayID)
    /// Switches to `.closed` and runs the close animation, then reports `closeAnimationEnded()`.
    case close
    /// Ends a running close, refreshes the save card, and switches to `.open`: the cursor is back
    /// over a closing panel, or over the panel when the shortcut's feedback ends.
    case switchToOpen
    /// The close animation has run: orders the window out.
    case orderOut
    /// Places the window again on its screen, whose frame or hover area may have changed.
    case place(CGDirectDisplayID)
    /// The window's screen is gone: switches to `.closed` and orders the window out without the animation.
    case closeAtOnce
}

/// The notch panel's open/close state. The methods are pure: each takes the state and what happened,
/// moves to the next state, and returns what the controller must do. No windows or timers involved.
///
/// The panel's `PanelModel.Mode` (open, search, feedback) is what the panel shows while `.shown`;
/// the state is about the window and the cursor.
enum NotchState: Equatable {
    /// Closed, window ordered out.
    case idle
    /// The cursor is over that screen's hover area and the hover delay is running. `fadingOn` is the
    /// screen where the panel is still running its close animation, if any.
    case hovering(CGDirectDisplayID, fadingOn: CGDirectDisplayID?)
    /// The window is ordered in on that screen, in any mode other than `.closed`.
    case shown(CGDirectDisplayID)
    /// Mode `.closed`, the close animation running on that screen. The cursor coming back reopens it.
    case closing(CGDirectDisplayID)
    /// Closed by the user (Esc, a click outside search, an action). Stays closed until the cursor
    /// leaves the hover area and the fading shape. `fadingOn` is the screen where the close
    /// animation is still running, if any.
    case dismissed(fadingOn: CGDirectDisplayID?)

    /// The screen the window is ordered in on, if any.
    var windowDisplayID: CGDirectDisplayID? {
        switch self {
        case .idle: nil
        case .hovering(_, let fading), .dismissed(let fading): fading
        case .shown(let displayID), .closing(let displayID): displayID
        }
    }

    mutating func mouseMoved(_ surroundings: NotchSurroundings) -> [NotchEffect] {
        guard !surroundings.isMenuTracking else { return [] }
        let hovered = surroundings.hoverAreas.first { $0.rect.containsMouseLocation(surroundings.cursor) }
        let overWindow = isOverWindow(surroundings)

        switch self {
        case .idle:
            guard let hovered else { return [] }
            self = .hovering(hovered.displayID, fadingOn: nil)
            return [.startHoverDelay(hovered.displayID)]

        case .hovering(let pending, let fading):
            if let fading, overWindow {
                self = .shown(fading)
                return [.cancelHoverDelay, .switchToOpen]
            }
            guard let hovered else {
                self = fading.map(NotchState.closing) ?? .idle
                return [.cancelHoverDelay]
            }
            // Keep a running delay for the same screen; restart it when the cursor moves to another one.
            guard hovered.displayID != pending else { return [] }
            self = .hovering(hovered.displayID, fadingOn: fading)
            return [.startHoverDelay(hovered.displayID)]

        case .shown(let displayID):
            // Search stays open when the cursor leaves (the controller closes it on Esc or a click
            // outside), and the shortcut's feedback ends with `feedbackEnded(_:)`.
            guard surroundings.mode == .open, !overWindow else { return [] }
            self = .closing(displayID)
            return [.close]

        case .closing(let displayID):
            if overWindow {
                self = .shown(displayID)
                return [.switchToOpen]
            }
            guard let hovered else { return [] }
            self = .hovering(hovered.displayID, fadingOn: displayID)
            return [.startHoverDelay(hovered.displayID)]

        case .dismissed(let fading):
            // After the cursor leaves, hovering opens the panel again.
            if hovered == nil, !overWindow {
                self = fading.map(NotchState.closing) ?? .idle
            }
            return []
        }
    }

    mutating func hoverDelayEnded(on displayID: CGDirectDisplayID) -> [NotchEffect] {
        guard case .hovering(displayID, _) = self else { return [] }
        self = .shown(displayID)
        return [.open(displayID)]
    }

    mutating func closeAnimationEnded() -> [NotchEffect] {
        switch self {
        case .closing:
            self = .idle
        case .hovering(let pending, .some):
            self = .hovering(pending, fadingOn: nil)
        case .dismissed(.some):
            self = .dismissed(fadingOn: nil)
        case .idle, .hovering(_, nil), .shown, .dismissed(nil):
            return []
        }
        return [.orderOut]
    }

    /// Closes the panel so the cursor still over it doesn't bring it back.
    mutating func dismiss() -> [NotchEffect] {
        self = .dismissed(fadingOn: windowDisplayID)
        return [.close]
    }

    /// The search shortcut: closes search as a dismissal if it's open, like Esc; otherwise opens it
    /// like `openSearch(on:mode:)`.
    mutating func toggleSearch(on displayID: CGDirectDisplayID, mode: PanelModel.Mode) -> [NotchEffect] {
        isSearchOpen(mode) ? dismiss() : openSearch(on: displayID, mode: mode)
    }

    /// "Search Notes…" in the menu bar: opens search on `displayID`, the screen with the cursor, from
    /// any state, dropping a running hover delay. Leaves search that's already open as it is.
    mutating func openSearch(on displayID: CGDirectDisplayID, mode: PanelModel.Mode) -> [NotchEffect] {
        guard !isSearchOpen(mode) else { return [] }
        let effects: [NotchEffect] = if case .hovering = self { [.cancelHoverDelay] } else { [] }
        self = .shown(displayID)
        return effects + [.openSearch(displayID)]
    }

    private func isSearchOpen(_ mode: PanelModel.Mode) -> Bool {
        if case .shown = self { mode == .search } else { false }
    }

    /// The shortcut's feedback is up: switches to `.open` if the cursor is over the panel or its
    /// hover area, else closes. From then on the normal hover rules apply.
    mutating func feedbackEnded(_ surroundings: NotchSurroundings) -> [NotchEffect] {
        guard case .shown(let displayID) = self, surroundings.mode == .feedback else { return [] }
        if isOverWindow(surroundings) {
            return [.switchToOpen]
        }
        self = .closing(displayID)
        return [.close]
    }

    /// Displays were added or removed, or their resolution or arrangement changed. `surroundings`
    /// has the new hover areas.
    mutating func screensChanged(_ surroundings: NotchSurroundings) -> [NotchEffect] {
        var effects: [NotchEffect] = []
        if case .hovering(_, let fading) = self {
            self = fading.map(NotchState.closing) ?? .idle
            effects.append(.cancelHoverDelay)
        }
        guard let displayID = windowDisplayID else { return effects }

        if surroundings.hoverAreas.contains(where: { $0.displayID == displayID }) {
            return effects + [.place(displayID)]
        }
        // Closing search counts as a dismissal, like Esc.
        if case .dismissed = self {
            self = .dismissed(fadingOn: nil)
        } else {
            self = surroundings.mode == .search ? .dismissed(fadingOn: nil) : .idle
        }
        return effects + [.closeAtOnce]
    }

    /// Whether the cursor is over the hover area or the visible shape of the screen the window is on.
    private func isOverWindow(_ surroundings: NotchSurroundings) -> Bool {
        guard let windowDisplayID else { return false }
        let area = surroundings.hoverAreas.first { $0.displayID == windowDisplayID }
        let overArea = area.map { $0.rect.containsMouseLocation(surroundings.cursor) } ?? false
        return overArea || surroundings.visibleShape.containsMouseLocation(surroundings.cursor)
    }

}
