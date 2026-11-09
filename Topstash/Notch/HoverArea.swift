import AppKit

/// The area of one screen that opens the panel when hovered.
struct HoverArea {
    let displayID: CGDirectDisplayID
    /// In global screen coordinates.
    let rect: NSRect
    /// Whether `rect` is the hardware notch, rather than the invisible strip used without one.
    let isNotch: Bool

    init(displayID: CGDirectDisplayID, rect: NSRect, isNotch: Bool) {
        self.displayID = displayID
        self.rect = rect
        self.isNotch = isNotch
    }

    init(displayID: CGDirectDisplayID, screen: NSScreen) {
        self.displayID = displayID
        if let notch = Self.notchRect(for: screen) {
            rect = notch
            isNotch = true
        } else {
            rect = Self.fallbackRect(for: screen)
            isNotch = false
        }
    }

    /// The notch rectangle, or `nil` for a screen without a notch.
    private static func notchRect(for screen: NSScreen) -> NSRect? {
        let notchHeight = screen.safeAreaInsets.top
        guard notchHeight > 0,
              let left = screen.auxiliaryTopLeftArea,
              let right = screen.auxiliaryTopRightArea
        else { return nil }

        // From the left area's maxX to the right area's minX. Measured with their widths from the
        // screen edges, so the result is global whichever coordinate space the areas are reported in.
        let frame = screen.frame
        let minX = frame.minX + left.width
        let maxX = frame.maxX - right.width
        guard maxX > minX else { return nil }
        return NSRect(x: minX, y: frame.maxY - notchHeight, width: maxX - minX, height: notchHeight)
    }

    /// A strip `fallbackHoverWidth` wide, centered at the top, as tall as the menu bar
    /// (or `hiddenMenuBarHoverHeight` when the menu bar is hidden).
    private static func fallbackRect(for screen: NSScreen) -> NSRect {
        let frame = screen.frame
        let menuBarHeight = frame.maxY - screen.visibleFrame.maxY
        let height = menuBarHeight > 0 ? menuBarHeight : PanelLayout.hiddenMenuBarHoverHeight
        let width = PanelLayout.fallbackHoverWidth
        return NSRect(x: frame.midX - width / 2, y: frame.maxY - height, width: width, height: height)
    }
}
