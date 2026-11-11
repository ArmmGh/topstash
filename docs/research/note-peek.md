# Note peek: force click, expansion, keyboard, and scrolling for an inline preview

Research date: 2026-11-10. Machine: MacBook Pro (Mac15,6), macOS 27.0.1, Xcode 27.1, macOS 27.0 SDK. The deployment target is **macOS 14.0** (`project.yml:11`). Apple documentation was read from the JSON behind each page (`developer.apple.com/tutorials/data/documentation/<path>.json`), so quotes match the live page on that date. The archived AppKit release notes are [RN-AppKitOlderNotes](https://developer.apple.com/library/archive/releasenotes/AppKit/RN-AppKitOlderNotes/index.html) (the 10.8, 10.10.3 and 10.11 sections). SDK claims come from the macOS 27.0 SDK headers and `SwiftUI.swiftinterface`.

Two throwaway prototypes were built in `/tmp` (not in the repo) and driven with events posted through `NSApp.postEvent`:

- **[P1]** A `TextField` in a borderless, non-activating `NSPanel` with `onKeyPress(.space)`, `onKeyPress(.escape)`, a catch-all `onKeyPress(phases:)`, and `onExitCommand`.
- **[P2]** A SwiftUI `Button` with a press-dip `ButtonStyle`, `.contextMenu` and `.onHover`, inside an `NSHostingView` subclass that has `acceptsFirstMouse` = true, in a **non-key** non-activating panel. An `NSGestureRecognizer` subclass is attached to the hosting view.

Posted events go through `NSApp.sendEvent` → `NSWindow.sendEvent`, the same path as hardware events. They can't carry pressure, though, and they don't reproduce input-method or real trackpad behavior. Anything that depends on those is listed under Open risks.

## Summary

| # | Question | Answer | Recommendation |
|---|---|---|---|
| 1 | Force click | SwiftUI has no force-click API on macOS 14. `NSGestureRecognizerRepresentable` is macOS 26+. AppKit offers `quickLook(with:)` (the system "Look up"/Quick Look gesture) and `pressureChange(with:)` with `NSEvent.stage == 2`. | Keep the SwiftUI `Button`. Watch for force clicks once for the whole panel, in `FirstMouseHostingView`: `quickLook(with:)` first, with a stage-2 pressure recognizer as the fallback if the prototype shows `quickLook` isn't delivered. Target the hovered row. Stop the copy with a one-shot "suppress" flag that the row's action checks. |
| 2 | Animation | The shape animates to `appModel.shapeSize`, which is computed before layout (`PanelLayout.swift:177-202`). The hit test reads the same value (`NotchPanelController.swift:175-182`). | Add the peek's extra height to `shapeSize` (computed from a line count, like the save card), and animate rows with `Motion.shape(expanding: true, …)` keyed on the peeked note. The hit test follows on its own. An 11 pt peek of 12 lines fits the current 550 pt window; a 13 pt peek doesn't. |
| 3 | Keyboard | Verified in [P1]: `onKeyPress` on the `TextField` sees Space, ⇧Space and Esc **before** the field editor, and `.handled` stops the space being typed and stops `onExitCommand`. Outer `onKeyPress` modifiers fire first. Every API used is macOS 14+. | `onKeyPress(.space, phases: .down)` gated on an "armed after ↑/↓" flag (or Shift). `onKeyPress(.escape, phases: .down)` returns `.handled` only while a peek is open, otherwise `onExitCommand` closes the panel as today. |
| 4 | Scrolling and highlighting | AppKit/SwiftUI don't document how nested vertical scroll views pass scrolling on. SwiftUI `Text` lays out its whole string. | A SwiftUI `ScrollView` with one `Text`, `.scrollBounceBehavior(.basedOnSize)`, the text capped at a fixed number of characters, and highlight ranges computed once per expansion by a shared `SearchSnippet` range helper. Scroll to the first match by measuring its line with `NSLayoutManager` (the save card's existing approach) and scrolling the inner `NSScrollView` like `RowScroller`. Extend `PanelLayout.scrollOffset` for one taller row. |

---

## 1. Force click

### Findings

- **SwiftUI has no force-click or pressure API that the macOS 14 target can use.** `SwiftUI.swiftinterface` in the macOS 27 SDK has no symbol containing "pressure", "forceClick", "deepClick" or "quickLook". The bridge for AppKit gesture recognizers, [`NSGestureRecognizerRepresentable`](https://developer.apple.com/documentation/swiftui/nsgesturerecognizerrepresentable) with [`gesture(_:)`](https://developer.apple.com/documentation/swiftui/view/gesture(_:)), is **macOS 26.0+**, so it would need `#available` with a fallback. [`onLongPressGesture`](https://developer.apple.com/documentation/swiftui/view/onlongpressgesture(minimumduration:maximumdistance:perform:onpressingchanged:)) is time-based, not pressure-based.
- **Pressure events.** These arrived in 10.10.3: "the pressure gesture is reported as a new event type, NSEventTypePressure, and a new responder method -pressureChangeWithEvent:". There are three ways to receive them: override the responder method, add `NSEventMaskPressure` to a tracking loop, or override `-pressureChangeWithEvent:` "in a NSGestureRecognizer subclass" ([AppKit release notes 10.10.3, Pressure Events](https://developer.apple.com/library/archive/releasenotes/AppKit/RN-AppKitOlderNotes/index.html)). The stage semantics:
  - "Stage 1: Equivalent to a mouse down. NSEventTypePressure events are not posted until the user applies enough pressure that the trackpad will also issue a mouse down."
  - "Stage 2: Equivalent to a force click … Stage 2 should generally be used as the trigger for an additional action. For example, lookup is performed when the pressure stream transitions to stage 2." (same source)
  - The stage can skip values: "ending the gesture with a stage value of 2 may result in an immediate transition to a stage value of 0" ([`NSEvent.stage`](https://developer.apple.com/documentation/appkit/nsevent/stage)).
- **Gesture recognizers see events first.** "A gesture recognizer monitors events that occur in its view (and any subviews) but does not take part in the responder chain itself. The gesture recognizer receives events before any views do." ([`NSGestureRecognizer.pressureChange(with:)`](https://developer.apple.com/documentation/appkit/nsgesturerecognizer/pressurechange(with:))) So one recognizer on the hosting view covers every row.
- **`allowedTouchTypes` doesn't apply.** It is for direct touches only: "Setting this property to include indirect — for touches from a trackpad — isn't supported." ([`allowedTouchTypes`](https://developer.apple.com/documentation/appkit/nsgesturerecognizer/allowedtouchtypes)) Pressure events aren't `NSTouch`es, so nothing needs setting.
- **Pressure configuration.** The default already suits a force click. [`.primaryDefault`](https://developer.apple.com/documentation/appkit/nsevent/pressurebehavior-swift.enum/primarydefault) "defaults to the behavior of NSPressureBehaviorPrimaryDeepClick". [`.primaryDeepClick`](https://developer.apple.com/documentation/appkit/nsevent/pressurebehavior-swift.enum/primarydeepclick) "is ideal for responding to force clicks": it actuates the haptic "when force click is activated and released", and "stage 2 becomes disabled once dragging occurs". The release notes say: "By default, the force touch trackpad is configured for deep click … the user always gets feedback that they have indeed pressed hard enough for a force click even if the app doesn't respond to it." If you set a configuration explicitly, set it on the view (`NSView.pressureConfiguration`, macOS 10.11). That is "the most responsive method": calling `set()` during a click is "racing the user" ([release notes 10.11](https://developer.apple.com/library/archive/releasenotes/AppKit/RN-AppKitOlderNotes/index.html), [`pressureConfiguration`](https://developer.apple.com/documentation/appkit/nsview/pressureconfiguration)). The system plays the haptic itself, so `NSHapticFeedbackManager` isn't needed.
- **`quickLook(with:)` is the system's Look up / Quick Look hook.** It was added in 10.8 as "the Quick Look gesture (also known as the dictionary look up gesture). The user can perform this gesture with a three finger single tap, or the appropriate keyboard shortcut" ([release notes 10.8](https://developer.apple.com/library/archive/releasenotes/AppKit/RN-AppKitOlderNotes/index.html)). "A Quick Look event does not come in through the normal event mechanism … nor should you attempt to look for it in a sendEvent(_:)" ([`quickLook(with:)`](https://developer.apple.com/documentation/appkit/nsresponder/quicklook(with:))). Only `locationInWindow` and `modifierFlags` are valid on it. Apple Support describes the user's side: force click on a Finder file shows a Quick Look preview, and the "Look up & data detectors" setting is either "Force click with one finger" or "Tap with three fingers", where the latter "is available for both Force Touch trackpads and Multi-Touch trackpads" ([Apple Support 102309](https://support.apple.com/en-us/102309)). Two things are inferred, not documented by Apple for AppKit: that `quickLookWithEvent:` is sent on a one-finger force click when the setting is set that way (iTerm2 relies on this; Ghostty instead calls `quickLook` itself from `pressureChange` at stage 2, per [cmux #4344](https://github.com/manaflow-ai/cmux/issues/4344)), and that it is sent to a non-key window. **Unverified.** The release notes also record a bug: "the quickLook responder methods … jump from NSWindow directly to NSApp" (10.8). So override it in the hosting view or the panel, not in a controller.
- **Detecting hardware.** There's no public "has a Force Touch trackpad" API. Each mouse event says whether pressure events accompany it: "[`associatedEventsMask`](https://developer.apple.com/documentation/appkit/nsevent/associatedeventsmask) … determine whether the input device issuing the event can simultaneously issue events of type pressure." Because Preview, the chevron and the keyboard are all alternatives, Topstash doesn't need to detect it. Just don't advertise force click in UI text.
- **Mouse delivery in hover mode.** The panel takes mouse events because `FirstMouseHostingView.acceptsFirstMouse` returns true (`NotchPanel.swift:50-53`; Apple: override it "to allow instances to respond to click-through", [`acceptsFirstMouse(for:)`](https://developer.apple.com/documentation/appkit/nsview/acceptsfirstmouse(for:))). `ignoresMouseEvents` is switched off only while the cursor is over the visible shape (`NotchPanelController.swift:184-193`). [P2] confirmed that in a **non-key, inactive** panel the attached gesture recognizer received `mouseDown`, and the SwiftUI `Button` still fired its action and its press state (`isPressed true` → action → `isPressed false`).
- **Copy suppression.** [P2] also showed that `delaysPrimaryMouseButtonEvents = true` on the recognizer **did not delay SwiftUI's button**: `isPressed` became true on mouse-down either way, and the action still ran. The recognizer's `mouseUp(with:)` was never called, and `reset()` ran after the button action. So the documented "delay until the recognizer fails" ([`NSClickGestureRecognizer`](https://developer.apple.com/documentation/appkit/nsclickgesturerecognizer) overview) can't be relied on to stop the copy inside an `NSHostingView`. The row's action has to check a flag instead.
- **Replacing `Button` with an AppKit control** would lose what `Button` provides for free: its accessibility (button role and press action), and `PressDipButtonStyle`'s `configuration.isPressed` (`Motion.swift:141-150`). Both would have to be rebuilt by hand with `accessibilityRepresentation` and a custom press state. Since one panel-wide recognizer or a `quickLook` override can work alongside the `Button` ([P2]), there's no reason to give it up.

### Recommendation for Topstash

1. **One watcher for the whole panel, not one per row.** In `FirstMouseHostingView` (`NotchPanel.swift:51`), override `quickLook(with:)` and also attach a `ForceClickRecognizer` that fires once when `stage` first reaches 2. Both call one closure, `onForceClick`, and that closure toggles the peek of the **hovered** row. The rows already track hover. Lift it from `NoteRow`'s `@State isHovered` (`NoteRow.swift:21, 76`) into `PanelModel.hoveredNote`, so AppKit doesn't have to map points to rows. Which path to keep depends on the prototype. If `quickLook(with:)` arrives on a force click in the non-key panel, keep it alone: it follows the user's Look up setting and gives three-finger tap for free. Otherwise keep the recognizer, and also keep `quickLook` for three-finger tap. Make sure one press doesn't toggle twice: ignore a second trigger within the same mouse-down.
2. **Stop the copy.** Set `panel.suppressesNextCopy = note.id` only when the primary button is down (`NSEvent.pressedMouseButtons & 1 != 0`). A three-finger tap has no mouse-up, so a flag set then would eat the next real click. The `NoteList` copy closure (`NoteList.swift:55-58`) checks the flag and clears it. Also clear it on the recognizer's next `mouseDown`.
3. Leave `pressureConfiguration` at its default (deep click). Setting `.primaryDeepClick` explicitly on the hosting view is harmless and documents the intent.

```swift
/// Reports a force click (pressure stage 2) once per press. Never recognizes, so the SwiftUI
/// button under it still gets the click.
final class ForceClickRecognizer: NSGestureRecognizer {
    var onForceClick: () -> Void = {}
    private var fired = false

    override func mouseDown(with event: NSEvent) { fired = false }
    override func pressureChange(with event: NSEvent) {
        guard event.stage >= 2, !fired else { return }
        fired = true
        onForceClick()
    }
}

private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    var onForceClick: () -> Void = {}
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    // Force click (if Look up is set to it) or three-finger tap. Unverified in a non-key panel.
    override func quickLook(with event: NSEvent) { onForceClick() }
}
```

The row needs no AppKit at all. It reads `panel.peekedNote == note.id`, and its action becomes `guard panel.consumeCopySuppression(note.id) == false else { return }`.

---

## 2. Animation and sizing

### Findings (codebase)

- **The shape's target height is computed before layout, not measured.** `PanelLayout.shapeSize(for:noteCount:resultCount:)` (`PanelLayout.swift:177-202`) adds up `recentPanelHeight` (`:166-172`) or `searchPanelHeight` (`:214-223`, capped at `maxSearchHeight` 520). Both assume every row is exactly `rowHeight` 40 (`:126`), which `NoteRow` enforces with `.frame(height:)` (`NoteRow.swift:57`). The save card does the same: its height comes from a line count measured with `NSLayoutManager` (`PanelLayout.swift:72-105`), "so the shape can animate to it".
- **Animation.** `PanelView.animatedShape` animates `NotchShape` with `Motion.shape(expanding: isOpen, reduceMotion:)`, keyed on `shapeSize` (`PanelView.swift:36-40`). While open, that's `Motion.expand` = `.snappy(duration: 0.4)`, or `Motion.reduced` = `.easeOut(0.2)` with Reduce Motion (`Motion.swift:50, 58, 80-87`). The recent content uses the same curve, keyed on `saveCardHeight`, "so the list moves with the shape's edge" (`PanelView.swift:128-129`). Content is masked by the same animated shape (`PanelView.swift:107-110`), so a row that grows before the shape would be clipped, not drawn outside it.
- **Reduce Motion is already handled everywhere.** `@Environment(\.accessibilityReduceMotion)` is used in `PanelView`, `NoteRow`, `SearchView` and `PressDipButtonStyle`, and `NSWorkspace.accessibilityDisplayShouldReduceMotion` in the controller (`NotchPanelController.swift:426`). Under Reduce Motion, transitions become `.opacity` (`Motion.swift:91-130`). Apple's guidance under Reduce Motion is to "avoid large animations, especially those that simulate the third dimension" ([`accessibilityDisplayShouldReduceMotion`](https://developer.apple.com/documentation/appkit/nsworkspace/accessibilitydisplayshouldreducemotion)).
- **The hit test follows the shape automatically.** `visibleRect` is built from `appModel.shapeSize` (`NotchPanelController.swift:175-182`). That rect feeds both click-through (`:184-193`) and `NotchState.isOverWindow` (`NotchState.swift:198-204`). Once the peek is part of `shapeSize`, the taller area counts as the panel. The rect jumps to the target size while the shape is still animating, so for about 0.4 s, after expanding, the not-yet-drawn bottom already counts as "over", and after collapsing it no longer does. Two edge cases in open mode, where leaving closes the panel (`NotchState.swift:95-100`):
  - Collapsing from the bottom of a tall peek: the next mouse move outside the new, shorter shape closes the panel. Collapsing from the chevron on the title line keeps the cursor inside. The Preview menu item can't trigger it, because mouse moves are ignored while a menu is tracking (`NotchState.swift:12-14, 71`).
  - `updateClickThrough` runs only on mouse moves and on open (`NotchPanelController.swift:113-116, 225`). After an expansion without a move, the cursor is still over the row, which is inside both rects, so nothing breaks.

### Will the window fit?

The peek should use the preview line's font, `PanelStyle.meta` (11 pt, `PanelStyle.swift:40`). Measured `NSLayoutManager.defaultLineHeight`: **13 pt at 11 pt, 16 pt at 13 pt**. A row is 40 = 16 (title) + 2 + 13 (preview) + 9 of padding. Expanded with 12 lines, it is 16 + 2 + 12 × 13 + 9 = **183 pt, +143**. With 13 pt body text it would be 16 + 2 + 12 × 16 + 9 = **219 pt, +179**.

| | Today | + 11 pt peek (12 lines) | + 13 pt peek (12 lines) |
|---|---|---|---|
| Open, tallest: `maxPanelHeight` = 44 + 8 + 89 + 8 + 5 × 40 + 12 | 361 | 504 | 540 |
| Open + shadow (radius 12, y 6 ≈ 18 below) | 379 | 522 | 558 |
| Window height: `max(361, 520) + 30` (`PanelLayout.swift:8-11`) | 550 | 550: **fits** | 550: **shadow clipped by 8 pt**, and 540 > `maxSearchHeight` |
| Search list viewport at the 520 cap (44 pt header) | 391 | the 183 row fits | the 219 row fits |

So an 11 pt, 12-line peek fits the current window with room for the shadow. If a larger font or more lines are wanted, there are three options:

- (a) Derive the window height from the peek: `windowSize.height = max(maxPanelHeight + maxPeekExtraHeight, maxSearchHeight) + shadowPadding`. The window is transparent and click-through outside the shape (`NotchPanelController.swift:184-193`), so a taller window costs nothing visible.
- (b) Cap the peek's lines in open mode at what fits.
- (c) Make the recent list scroll.

Prefer (a): compute it in `PanelLayout`, so the existing `PanelShapeSizeTests` style can check it.

### Recommendation for Topstash

1. **State.** Add `PanelModel.peekedNote: Note.ID?`, cleared in `mode`'s `didSet` when `.closed`, next to `query` and `selection` (`PanelModel.swift:21-31`). That gives "every reopen starts collapsed". Also clear it when the query changes and when the note leaves the results or is deleted.
2. **Height before layout.** Add `PanelLayout.peekLineCount(_ text:)`, the same as `previewLineCount` (`PanelLayout.swift:92-105`) but with the 11 pt font, the row's text width (`panelWidth − 4 × inset` = 352) and `maximumNumberOfLines = 12`, plus `peekExtraHeight(lines:) = lines × 13 − 13`. Store the extra height in `PanelModel` when the peek opens, as `saveCardHeight` is stored (`PanelModel.swift:35-44`). Add it in `recentPanelHeight` and `searchPanelHeight` (before the 520 cap), and in `NoteRow`'s `.frame(height:)`.
3. **One curve for shape and rows.** Change `peekedNote` inside `withAnimation(Motion.shape(expanding: true, reduceMotion: reduceMotion))`, or key `.animation(…, value: panel.peekedNote)` on `recentContent` and the search `NoteList`, as `PanelView.swift:129` does for the card. Use the *expanding* curve both ways: the collapse curve has a `contentOutDuration` delay meant for closing the panel (`Motion.swift:83`). The peek body replaces the preview line with a transition like `Motion.copiedLine`. Under Reduce Motion it is `.opacity` and the height uses `Motion.reduced`, which matches how the shape already behaves under Reduce Motion. If the user wants no size animation at all under Reduce Motion, pass `nil` for the height and keep only the fade. That would be the only place the panel jumps, so check it on the device.
4. **Chevron.** Rotate it with `.rotationEffect` on the same curve, and only fade it under Reduce Motion. Put it in an `.overlay(alignment: .topTrailing)` on the row's `Button`, not inside its label, so it is a sibling with its own hit area and doesn't copy. Nested `Button`s in a `Button` label aren't documented on macOS (unverified).
5. **Press dip.** `Motion.pressScale` 0.96 on a 183 pt row moves its bottom edge about 7 pt. Consider skipping the dip while the row is peeked (`PressDipButtonStyle` could take an `isEnabled` flag).

---

## 3. Keyboard (search mode)

### Findings

- **Availability.** [`onKeyPress(_:phases:action:)`](https://developer.apple.com/documentation/swiftui/view/onkeypress(_:phases:action:)), [`onKeyPress(phases:action:)`](https://developer.apple.com/documentation/swiftui/view/onkeypress(phases:action:)) and [`KeyPress`](https://developer.apple.com/documentation/swiftui/keypress) are **macOS 14.0+**, which matches the deployment target. [`onExitCommand`](https://developer.apple.com/documentation/swiftui/view/onexitcommand(perform:)) is 10.15+ ("the escape key on macOS"). `KeyEquivalent.space` is 11.0+. Nothing needs macOS 15. Return `.handled` "to consume the event or ignored to let other views receive it" ([`KeyPress`](https://developer.apple.com/documentation/swiftui/keypress)). The default phases for `onKeyPress(keys:…)` are `[.down, .repeat]`, so holding Space would toggle over and over. Pass `phases: .down`.
- **[P1] results**, with the field editor (`SystemTextFieldFieldEditor`) as first responder in a key, non-activating panel:
  - Space and ⇧Space reach `onKeyPress(.space)` **before** the field inserts them. Returning `.handled` stopped the space being typed, for both. Returning `.ignored` let it be typed. So Space is not like Return, which the field takes as submit first (`SearchView.swift:49`).
  - Esc reaches `onKeyPress(.escape)` first. Returning `.handled` **stopped `onExitCommand`**; `.ignored` let `onExitCommand` run. Putting Esc handling first is therefore just a matter of the return value.
  - With several `onKeyPress` modifiers on the field, the **outermost** (the last one written) was called first: a catch-all `onKeyPress(phases:)` ran before `onKeyPress(.space)`.
  - Typing "a" went only through the catch-all, so a catch-all can disarm the Space gesture on any other key.
- **Not tested:** input methods. With a CJK input method, Space chooses candidates while text is marked. A field that intercepts Space could break composition (unverified; see Open risks).

### Recommendation for Topstash

Add `PanelModel.spaceTogglesPeek: Bool`. `moveSelection` sets it to true, and any other key, a query change, or a toggle sets it to false. ↑/↓ also collapse the peek. The spec doesn't say whether the first ↑/↓ with a peek open only collapses or also moves; the sketch below collapses and moves.

```swift
TextField("Search notes", text: $panel.query)
    // …existing modifiers…
    .onKeyPress(.space, phases: .down) { press in
        guard selectedNote != nil,
              press.modifiers.contains(.shift) || panel.spaceTogglesPeek else { return .ignored }
        togglePeek()            // keeps spaceTogglesPeek armed, so Space toggles back
        return .handled
    }
    .onKeyPress(.escape, phases: .down) { _ in
        guard panel.peekedNote != nil else { return .ignored }   // falls through to onExitCommand
        collapsePeek()
        return .handled
    }
    // Outermost, so it runs first: any key but Space (and the arrows, which re-arm) disarms.
    .onKeyPress(phases: .down) { press in
        if press.key != .space { panel.spaceTogglesPeek = false }
        return .ignored
    }
```

`moveSelection` (`SearchView.swift:126-130`) sets `spaceTogglesPeek = true` after it runs, and its handlers sit inside the catch-all, so they re-arm after the disarm. `onExitCommand` (`SearchView.swift:86`) stays as it is for the second Esc. Announce the peek for VoiceOver the way `announceSelection` does (`SearchView.swift:133-140`), and add a "⇧Space Preview" key hint (`SearchView.swift:96-111`).

**Watch out for ⇧Space.** People often still hold Shift when typing the space after a capital letter ("New York"). If ⇧Space always toggles, that space would be eaten from the query. Consider making ⇧Space toggle only when the query is empty or the selection was moved, or test it with real typing first.

---

## 4. Scrolling and highlighting

### Findings

- **Nested scroll views.** Neither Apple's AppKit nor SwiftUI documentation says what a vertical `ScrollView` inside another vertical one does with scrolling at its ends (chaining or rubber-banding) or with trackpad momentum. **Unverified; prototype it.** What *is* documented: [`scrollBounceBehavior(.basedOnSize)`](https://developer.apple.com/documentation/swiftui/view/scrollbouncebehavior(_:axes:)) (macOS 13.3+) bounces "only … if its content is large enough to require scrolling", so a short peek won't capture scrolling at all. It passes "through the Environment", so apply it to the inner `ScrollView` only, or the outer results list changes too. [`scrollIndicators`](https://developer.apple.com/documentation/swiftui/view/scrollindicators(_:axes:)) is 13.0+. With legacy (always-shown) scrollers, the inner scroller takes width, so the text wraps narrower than the `NSLayoutManager` measurement in §2 (inference).
- **Scrolling to an element.** [`ScrollViewReader`](https://developer.apple.com/documentation/swiftui/scrollviewreader) (11.0+) scrolls to *views by ID*. A single `Text` can't report where a character range is, so this would need one `Text` per paragraph with IDs, and only gets to the right paragraph. [`scrollPosition(id:)`](https://developer.apple.com/documentation/swiftui/view/scrollposition(id:anchor:)) (14.0+) "will attempt to keep the view with the identity … visible", which is the sticky behavior `NoteList` already avoids for the outer list (`NoteList.swift:63-65`). For a read-only `NSTextView`, [`scrollRangeToVisible(_:)`](https://developer.apple.com/documentation/appkit/nstext/scrollrangetovisible(_:)) "scrolls the receiver in its enclosing scroll view so the first characters of aRange are visible", and TextKit only lays out what it needs ([noncontiguous layout](https://developer.apple.com/documentation/appkit/nslayoutmanager/allowsnoncontiguouslayout)). But an `NSView` inside the row's `Button` label takes the clicks (they would select text, not copy), and scroll events are routed by the same hit test, so it can't simply pass clicks through (inference).
- **Matching to reuse.** `SearchSnippet` works on one collapsed line of at most `previewLength` 140 characters (`SearchSnippet.swift:16-29`). Its range logic, `ranges(of:in:)` (every word, case-insensitive, overlaps merged), is `private static` (`:43-64`). The words come from `NotesStore.searchWords` and `searchOptions` (`NotesStore.swift:148-153`). The highlight is built by `NoteRow.snippetText` (`NoteRow.swift:86-102`), which takes a `SearchSnippet`. `NoteRow.previewText` runs on every body evaluation (`:80-84`), so anything that scans the full text there would run again on every hover change.
- **Peek text.** `NoteFile.textAfterTitleLine` returns everything after the title line, starting with its newline (`NoteFile.swift:148-150, 177-189`). The title is cut at 80 characters with `…` (`:191-195`), so when `titleLine.count > 80` the peek should start with the full title line.
- **`RowScroller`.** `PanelLayout.scrollOffset(showingRow:offset:viewportHeight:)` assumes uniform `rowHeight` rows (`PanelLayout.swift:138-148`; tests in `TopstashTests/SelectionScrollTests.swift`). With a peek open, every row below the peeked one is `extra` lower, and the peeked row is `extra` taller.

### Recommendation for Topstash

1. **Structure.** Use a SwiftUI `ScrollView` with one `Text(AttributedString)`, `.frame(height: lines × 13)` taken from the §2 count, `.scrollBounceBehavior(.basedOnSize)`, and `.textSelection` off (`Button` doesn't support it anyway: "Button views don't support text selection", [`textSelection`](https://developer.apple.com/documentation/swiftui/view/textselection(_:))). A click on the peek still copies through the row's `Button`. Fall back to an `NSTextView` only if the prototype shows SwiftUI `Text` is too slow with the capped text.
2. **Cap the text.** Add `PanelLayout.maxPeekCharacters`, for example 10 000 (a placeholder; measure on the device), ending in "…". Open in Editor is there for the rest. A match beyond the cap isn't highlighted. Say so, or move the cap's window to start before the first match, like `SearchSnippet.start`.
3. **Matching in TopstashCore.** Make the range helper reusable, for example `public static func matches(of query: String, in text: String) -> [Range<String.Index>]` in `SearchSnippet`, plus a `PeekText(body:query:)` that returns `text` (the full title line when cut, then the rest, newlines kept, trimmed, capped) and `matches`. Make `NoteRow.snippetText` take `(text, matches)` so the snippet and the peek share it. Compute the attributed string **once per expansion** (in the toggle action, or in a `@State` updated with `.onChange(of: query)`), not in `body`. Then add unit tests in the style of `NotesStoreSearchTests`.
4. **Scroll to the first match.** Get the line of the first match from the same `NSLayoutManager` used for the count (`lineFragmentRect(forGlyphAt:)`). Then scroll the peek's inner `NSScrollView` to `y = line × 13 − 13` (one line of context), found the way `EnclosingScrollView` finds the outer one (`NoteList.swift:83-92`). This keeps to the codebase's "no SwiftUI scrollTo" rule. If SwiftUI and TextKit wrap differently in practice, use per-paragraph IDs with `ScrollViewReader` instead (paragraph precision).
5. **Keep the expanded row in view.** Generalize the offset function and call it after the peek opens:

```swift
/// Like `scrollOffset(showingRow:…)`, with the row at `peeked` taller by `extra`. A row taller
/// than the viewport is brought to the top.
static func scrollOffset(
    showingRow index: Int, peeked: Int?, extra: CGFloat, offset: CGFloat, viewportHeight: CGFloat
) -> CGFloat? {
    let shift = (peeked.map { $0 < index } ?? false) ? extra : 0
    let top = CGFloat(index) * (rowHeight + rowSpacing) + shift
    let bottom = top + rowHeight + (peeked == index ? extra : 0)
    if top < offset || bottom - top > viewportHeight { return top }
    if bottom > offset + viewportHeight { return bottom - viewportHeight }
    return nil
}
```

The outer `NSScrollView`'s document view probably only grows after SwiftUI lays out the taller row, and a scroll past the old height may be clamped. So call `scroller.show` on the next turn of the run loop after `peekedNote` changes, or again once the expand curve has settled (`Motion.expandSettleDuration`). Unverified; see Open risks.

---

## Recommendations

1. **Keep `NoteRow` a SwiftUI `Button`.** Add a panel-wide force-click watcher in `FirstMouseHostingView`: `quickLook(with:)`, plus a stage-2 `NSGestureRecognizer` if the prototype needs it. It acts on `PanelModel.hoveredNote`. A one-shot `suppressesNextCopy` flag, set only while the mouse button is down, keeps the force click from copying.
2. Add `PanelModel.peekedNote` (reset on close) and a peek extra height measured with `NSLayoutManager` before layout. Add the height to `shapeSize`, so the shape, the rows and the hit test all follow one value. Animate it with `Motion.shape(expanding: true, …)` both ways, and use `Motion.reduced` with an opacity body under Reduce Motion.
3. Use 11 pt `meta` text, at most 12 lines (183 pt rows). That fits the current 550 pt window. For anything larger, derive `windowSize` from `maxPanelHeight + maxPeekExtraHeight`.
4. Keyboard: `onKeyPress(.space, phases: .down)` gated on an armed flag or Shift; `onKeyPress(.escape)` handled only while a peek is open; an outermost catch-all `onKeyPress` that disarms. All macOS 14+, and checked in [P1].
5. Peek content: a SwiftUI `ScrollView` + `Text` with `.scrollBounceBehavior(.basedOnSize)`, the text capped (about 10k characters, to be tuned), and match ranges from a public `SearchSnippet` helper, computed once per expansion. Scroll to the first match by its measured line. Generalize `PanelLayout.scrollOffset` for one taller row.
6. Put the chevron in an overlay outside the `Button` label. Add `.accessibilityAction(named: "Preview")` (macOS 13+, [docs](https://developer.apple.com/documentation/swiftui/view/accessibilityaction(named:_:))) to the row for VoiceOver, alongside the context menu's Preview item.

## Open risks

- **Force click in the non-key, inactive panel (hover mode).** Does it deliver `pressureChange(with:)` to the hosting view's recognizer, and does it send `quickLook(with:)` at all? Synthetic events can't carry pressure, so this needs a real trackpad. Also check that `quickLook` doesn't fire *as well as* stage 2 (double toggle), and what three-finger tap does when the Look up setting is set to it.
- **The force click's mouse-up.** With deep click, a mouse-up still follows the force click. Confirm the suppress flag is set (on stage 2) before SwiftUI's `Button` action runs (on mouse-up). [P2] only showed the order *recognizer `mouseDown` → button action*.
- **Nested scrolling.** Does the inner peek pass scrolling on to the results list at its ends, or rubber-band and swallow it? And does momentum leak from the inner view to the outer one? This needs a trackpad.
- **A `ScrollView` inside a `Button` label.** Scroll wheel and scroller dragging over the peek must scroll it, not press the row. This is undocumented.
- **`RowScroller` timing.** Whether scrolling right after `peekedNote` changes is clamped by the old document height while the row is still animating.
- **Wrapping in SwiftUI vs. TextKit.** The 12-line height and the first-match scroll assume SwiftUI `Text` wraps like `NSLayoutManager`, which the save card already relies on. Also check with legacy scrollers, where the inner scroller takes width.
- **⇧Space eating spaces** while typing capitalized queries, and Space during **input-method composition** (marked text). Test with real typing and a CJK input method.
- **Performance of `Text` with long text** at the chosen cap, and of measuring it with `NSLayoutManager` on every toggle. Measure on the device.
- **Open-mode collapse from inside a tall peek.** The cursor ends up outside the shorter shape, and the next mouse move closes the panel (`NotchState.swift:95-100`). Decide whether that's acceptable.
