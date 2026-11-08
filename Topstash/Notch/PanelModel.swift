import CoreGraphics
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
}
