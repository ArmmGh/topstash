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
    /// The search field's text.
    var query = ""

    /// Called after `mode` changes, with the old and new mode. `NotchPanelController` uses it to
    /// make the window key and watch for closing events while searching. Don't set `mode` from it.
    @ObservationIgnored
    var onModeChange: ((_ old: Mode, _ new: Mode) -> Void)?
}
