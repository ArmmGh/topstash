import SwiftUI

/// The panel's outline: a shape hanging from the top edge whose top corners curve outward
/// (reverse fillets) into the screen edge, so it reads as part of the hardware notch,
/// and whose bottom corners are normally rounded.
///
/// The outward fillets sit inside `rect`: the body is `rect` inset by `topCornerRadius` on each side,
/// so a body of a given size needs a frame `2 * topCornerRadius` wider.
struct NotchShape: Shape {
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topCornerRadius, bottomCornerRadius) }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        guard width > 0, height > 0 else { return Path() }
        let (top, bottom) = Self.clampedRadii(
            top: topCornerRadius, bottom: bottomCornerRadius, width: width, height: height
        )

        let minX = rect.minX
        let minY = rect.minY
        let bodyMinX = minX + top
        let bodyMaxX = rect.maxX - top
        let maxY = rect.maxY

        var path = Path()
        path.move(to: CGPoint(x: minX, y: minY))
        // Top left: concave, from the top edge down into the body's side.
        path.addArc(
            tangent1End: CGPoint(x: bodyMinX, y: minY),
            tangent2End: CGPoint(x: bodyMinX, y: maxY),
            radius: top
        )
        // Bottom left: convex.
        path.addArc(
            tangent1End: CGPoint(x: bodyMinX, y: maxY),
            tangent2End: CGPoint(x: bodyMaxX, y: maxY),
            radius: bottom
        )
        // Bottom right: convex.
        path.addArc(
            tangent1End: CGPoint(x: bodyMaxX, y: maxY),
            tangent2End: CGPoint(x: bodyMaxX, y: minY),
            radius: bottom
        )
        // Top right: concave, from the body's side out along the top edge.
        path.addArc(
            tangent1End: CGPoint(x: bodyMaxX, y: minY),
            tangent2End: CGPoint(x: rect.maxX, y: minY),
            radius: top
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: minY))
        path.closeSubpath()
        return path
    }

    /// Scales both radii down together until `top + bottom <= height` and `2 * (top + bottom) <= width`,
    /// so the path never crosses itself at any size a spring passes through.
    private static func clampedRadii(
        top: CGFloat, bottom: CGFloat, width: CGFloat, height: CGFloat
    ) -> (top: CGFloat, bottom: CGFloat) {
        var top = max(top, 0)
        var bottom = max(bottom, 0)
        let sum = top + bottom
        guard sum > 0 else { return (0, 0) }
        let scale = min(1, height / sum, width / (2 * sum))
        top *= scale
        bottom *= scale
        return (top, bottom)
    }
}
