import SwiftUI

/// Every animation curve and duration of the notch panel, in seconds. See docs/SPEC.md, "Design & Motion".
@MainActor
enum Motion {
    // MARK: Durations

    static let expandDuration: Double = 0.4
    static let collapseDuration: Double = 0.3
    static let contentInDuration: Double = 0.22
    static let contentInDelay: Double = 0.07
    static let contentOutDuration: Double = 0.12
    static let reducedDuration: Double = 0.2
    static let pressDuration: Double = 0.15
    static let flyUpDuration: Double = 0.25
    /// The gulp starts as the flying card reaches the notch.
    static let gulpDelay: Double = 0.15

    /// How long the card shows the checkmark after a save before it returns as "Already saved".
    /// Covers the fly-up, the gulp, and the checkmark bounce.
    static let saveFeedbackDuration: Double = 0.6

    /// How long the global shortcut's feedback stays before the panel hides.
    static let feedbackDuration: Double = 1.2

    /// How long a row shows "Copied".
    static let copiedDuration: Double = 1.2
    /// How long the card shows "Nothing to save" after a click before it's refreshed.
    static let nothingToSaveDuration: Double = 1
    /// How long the card shows "Couldn't save" before it's refreshed.
    static let failedDuration: Double = 2

    /// From opening until the shape has settled. The shortcut's save feedback waits for it when it
    /// opens the panel, so the gulp doesn't overlap the expand spring.
    static func expandSettleDuration(reduceMotion: Bool) -> Double {
        reduceMotion ? reducedDuration : expandDuration
    }

    /// From closing to `orderOut`: the content fades out, then the shape collapses.
    static let closeDuration: Double = contentOutDuration + max(collapseDuration, reducedDuration)

    // MARK: Curves

    /// The shape opening, and switching between modes. Its default bounce is about 0.15.
    static let expand: Animation = .snappy(duration: expandDuration)
    /// The shape closing, with no bounce.
    static let collapse: Animation = .smooth(duration: collapseDuration)
    static let contentIn: Animation = .easeOut(duration: contentInDuration).delay(contentInDelay)
    static let contentOut: Animation = .easeIn(duration: contentOutDuration)
    /// The notch's bump when a saved card flies into it.
    static let gulp: Animation = .spring(response: 0.3, dampingFraction: 0.5)
    /// Replaces the shape's springs when Reduce Motion is on. Also fades the shortcut's status in search mode.
    static let reduced: Animation = .easeOut(duration: reducedDuration)
    /// The save card's dip while pressed.
    static let press: Animation = .snappy(duration: pressDuration)
    /// The saved card shrinking up into the notch.
    static let flyUp: Animation = .easeIn(duration: flyUpDuration)

    // MARK: Amounts

    static let contentInBlur: CGFloat = 8
    static let contentInScale: CGFloat = 0.96
    static let pressScale: CGFloat = 0.96
    static let gulpScale: CGFloat = 1.04
    /// How small the saved card gets as it flies into the notch.
    static let flyUpScale: CGFloat = 0.2

    // MARK: Composed

    /// The shape's size and radii. Closing waits for the content to fade out first.
    static func shape(expanding: Bool, reduceMotion: Bool) -> Animation {
        switch (expanding, reduceMotion) {
        case (true, false): expand
        case (false, false): collapse.delay(contentOutDuration)
        case (true, true): reduced
        case (false, true): reduced.delay(contentOutDuration)
        }
    }

    /// Panel content appearing and leaving: in with opacity, blur, and scale from the top;
    /// out with opacity only. Only opacity with Reduce Motion.
    static func content(reduceMotion: Bool) -> AnyTransition {
        .asymmetric(insertion: contentInsertion(reduceMotion: reduceMotion), removal: .opacity.animation(contentOut))
    }

    /// The save card: it flies up into the notch when saved and comes back like panel content.
    /// Only cross-fades with Reduce Motion.
    static func saveCard(reduceMotion: Bool) -> AnyTransition {
        let removal: AnyTransition =
            reduceMotion
            ? .opacity
            : .scale(scale: flyUpScale)
                .combined(with: .offset(y: PanelLayout.saveCardFlyUpOffset))
                .combined(with: .opacity)
        return .asymmetric(
            insertion: contentInsertion(reduceMotion: reduceMotion),
            removal: removal.animation(reduceMotion ? reduced : flyUp)
        )
    }

    private static func contentInsertion(reduceMotion: Bool) -> AnyTransition {
        let transition: AnyTransition =
            reduceMotion
            ? .opacity
            : .opacity
                .combined(with: .modifier(active: Blur(radius: contentInBlur), identity: Blur(radius: 0)))
                .combined(with: .scale(scale: contentInScale, anchor: .top))
        return transition.animation(contentIn)
    }

    private struct Blur: ViewModifier {
        let radius: CGFloat

        func body(content: Content) -> some View {
            content.blur(radius: radius)
        }
    }
}

/// The save card's dip to `Motion.pressScale` while pressed. No dip with Reduce Motion.
struct PressDipButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? Motion.pressScale : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}
