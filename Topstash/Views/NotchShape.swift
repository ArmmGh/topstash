import SwiftUI

/// The panel's outline: a shape hanging from the top edge whose top corners curve outward
/// (reverse fillets) into the screen edge, so it reads as part of the hardware notch,
/// and whose bottom corners are normally rounded.
///
/// The body is `bodySize`, hanging from the top center of `rect`; the outward fillets add
/// `topCornerRadius` on each side. The size is animatable, together with the radii, so the shape
/// always grows and shrinks around its center: animating a frame's size instead lets the parent
/// move the frame to its final position at once, and the shape drifts sideways while it grows.
struct NotchShape: Shape {
    var bodySize: CGSize
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat

    var animatableData: AnimatablePair<CGSize.AnimatableData, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(bodySize.animatableData, AnimatablePair(topCornerRadius, bottomCornerRadius)) }
        set {
            bodySize.animatableData = newValue.first
            topCornerRadius = newValue.second.first
            bottomCornerRadius = newValue.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let bodyWidth = bodySize.width
        let height = bodySize.height
        guard bodyWidth > 0, height > 0 else { return Path() }
        // The radii are clamped against the whole width, fillets included.
        let (top, bottom) = Self.clampedRadii(
            top: topCornerRadius, bottom: bottomCornerRadius, width: bodyWidth + 2 * max(topCornerRadius, 0),
            height: height
        )

        let minY = rect.minY
        let bodyMinX = rect.midX - bodyWidth / 2
        let bodyMaxX = rect.midX + bodyWidth / 2
        let minX = bodyMinX - top
        let maxX = bodyMaxX + top
        let maxY = minY + height

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
            tangent2End: CGPoint(x: maxX, y: minY),
            radius: top
        )
        path.addLine(to: CGPoint(x: maxX, y: minY))
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
