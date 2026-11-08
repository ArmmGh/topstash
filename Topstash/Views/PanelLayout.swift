import CoreGraphics

/// Size constants for the notch panel. All sizes live here.
enum PanelLayout {
    /// The fixed window frame. It never changes or animates; only the SwiftUI content does.
    static let windowSize = CGSize(width: 480, height: 240)

    /// The visible black shape when the panel is open.
    static let panelSize = CGSize(width: 380, height: 130)
    static let bottomCornerRadius: CGFloat = 20

    /// Space kept clear at the top of the shape for the hardware notch.
    static let notchClearance: CGFloat = 38
    static let contentPadding: CGFloat = 14

    static let cardCornerRadius: CGFloat = 12

    /// How long the content takes to fade out before the window is ordered out.
    static let fadeDuration: Double = 0.2
}
