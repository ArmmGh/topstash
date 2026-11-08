import AppKit

enum HoverArea {
    /// The notch rectangle in global screen coordinates, or `nil` for a screen without a notch.
    /// #8 adds a fallback strip for those.
    static func rect(for screen: NSScreen) -> NSRect? {
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
}
