# Topstash v1 — save clipboard text from the notch


## Problem Statement

I keep finding useful one-off prompts (mostly on Twitter) that I want to run against a codebase later. When I save them in Telegram or Apple Notes they get buried among everything else, and when I actually need one I can't find it. Saving takes too many steps, and finding takes even more. I want one obvious place for these snippets that I can save to in a single click and search through quickly.

## Solution

A small macOS app that lives in the MacBook notch. When I hover over the notch, a panel drops down. It shows a preview of the text currently on my clipboard, and one click saves it as a note. The same panel lists my newest notes; clicking a note copies it back to the clipboard, ready to paste into Claude Code or Cursor. A search button beside the notch expands the panel into full-text search across every note. Notes are plain Markdown files in a folder I choose, so I (and my coding agents) can also grep, edit, sync, or version them outside the app. On screens without a notch, an invisible area at the top center of the screen behaves the same way. A global keyboard shortcut saves the clipboard without using the mouse, and another opens search, where the arrow keys and Return find and copy a note without the mouse.

## User Stories

### Opening the panel
1. As a user, I want a panel to appear from the notch when I hover over it, so that saving and finding notes is always one gesture away.
2. As a user, I want the panel to open only after the cursor rests on the notch for a short moment (~250 ms by default), so that it doesn't open when I'm reaching for browser tabs or the menu bar.
3. As a user, I want the hover area to fit tightly around the notch width, so that the rest of the top edge stays usable.
4. As a user, I want the panel to close as soon as my cursor leaves it, so that it never gets in my way.
5. As a user on an external monitor or with my laptop closed, I want an invisible hover area at the top center of the screen to open the same panel, so that the app works without a notch.
6. As a user, I want no fake notch pill drawn on screens without a notch, so that my screen stays clean.
7. As a user with several displays, I want the panel to open on the screen I'm hovering, so that it appears where I'm looking.
8. As a user, I want the panel to work on every Space and over full-screen apps, so that I can save from anywhere.
9. As a user, I want opening the panel not to take focus from the app I'm using, so that my typing and selection aren't disturbed.
10. As a user, I want the panel to follow changes to my screen setup (plugging in or unplugging displays, changing resolution), so that the hover areas are always in the right place.

### Saving
11. As a user, I want the panel to show a preview of my clipboard text (the first ~3 lines plus a character count), so that I know what I'm about to save.
12. As a user, I want one click on the save card to save my clipboard as a note, so that saving takes no effort.
13. As a user, I want the note saved instantly, with no title or tag prompt, so that I don't get slowed down.
14. As a user, I want the note's title to come from its first non-empty line, so that notes are recognizable without me naming them.
15. As a user, I want the save card to tell me when the clipboard text is already saved, so that I don't create duplicates.
16. As a user, I want clicking an "Already saved" card to do nothing, so that duplicates are never created.
17. As a user, I want the save card to show "Nothing to save" in grey when the clipboard is empty or doesn't hold text, so that I understand why I can't save.
18. As a user, I want short confirmation feedback after saving, so that I know it worked.
19. As a user, I want a global keyboard shortcut (⌥⌘S by default) that saves the clipboard without opening the panel, so that I can save without the mouse.
20. As a user, I want brief visual feedback when the shortcut saves something (or finds it already saved, or finds nothing), so that I know what happened.
21. As a user, I want the saved text kept exactly as copied (whitespace, code fences, Markdown), so that prompts work when I paste them later.

### Clipboard privacy
22. As a user who has set this app to "Always allow" paste access, I want the full clipboard preview on hover, so that I see exactly what I'm saving.
23. As a user who hasn't granted paste access, I want the hover card to show "Text ready to save" without reading my clipboard, so that I don't get a system privacy alert every time I hover.
24. As a user without paste access, I want a hint with a link to the Paste privacy setting, so that I can turn on the preview if I want it.
25. As a user without paste access, I want clicking the save card to still save the text, so that the main feature works on a fresh install's default settings.

### Browsing and reusing
26. As a user, I want the panel to show my 5 newest notes below the save card, so that recently saved prompts are reachable in one hover.
27. As a user, I want clicking a note to copy its full text to the clipboard, so that I can paste it straight into my coding agent.
28. As a user, I want a "Copied" confirmation after clicking a note, so that I know the copy worked.
29. As a user, I want a search button in the header beside the notch that expands the panel into a search field and the full list of notes, so that I can reach older notes.
30. As a user, I want search to match every word I type, case-insensitively, across the full text of each note, so that I can find a prompt from any phrase I remember.
31. As a user, I want results to update as I type, so that searching feels instant.
32. As a user, I want the notes in the list sorted newest first, so that the order is predictable.
33. As a user, I want each row to show the title, a short preview of the text, and how long ago the note was saved, so that I can tell similar notes apart. In search results, the preview shows the part of the note that matched, with the matched words in bold, so that I can see why it's in the list.
34. As a user, I want the panel to stay open while I type in the search field, so that searching isn't interrupted.

### Managing notes
35. As a user, I want to right-click a note and choose "Open in editor", so that I can edit it in my default Markdown editor.
36. As a user, I want to right-click a note and choose "Delete", so that I can remove notes I no longer need.
37. As a user, I want edits I make to note files outside the app to show up in the app automatically, so that the app and the folder never disagree.
38. As a user, I want files I add to or delete from the notes folder (by hand, through git, or through iCloud/Dropbox sync) to show up in the app automatically, so that the folder is the single source of truth.
39. As a user, I want Markdown files without frontmatter that I drop into the folder to still appear as notes, so that I can import existing prompts by copying files in.
40. As a user, I want broken or unrelated files in the folder to be skipped without crashing the app, so that a stray file doesn't break anything.

### Storage
41. As a user, I want each note stored as its own `.md` file in a normal folder, so that my notes are readable, greppable, and never locked inside the app.
42. As a user, I want filenames that start with the date and include a slug of the title, so that the folder is browsable in Finder and the terminal.
43. As a user, I want a minimal frontmatter block (`id`, `created`, `type`), so that metadata travels with the note without cluttering it.
44. As a developer of future versions, I want a `type` field on every note, so that non-text note types can be added without migrating old notes.
45. As a user, I want my coding agents to be able to read the notes folder directly, so that I can say "use the refactor prompt from my notes".

### App shell and settings
46. As a user, I want no Dock icon, so that the app stays out of my way.
47. As a user, I want a menu bar icon with Settings, Open notes folder, and Quit, so that I can always configure or quit the app. The icon is the SF Symbol `tray.and.arrow.up`, pointing the way a save goes.
48. As a user, I want the app to launch at login (with a toggle), so that it's always available.
49. As a user, I want to choose the notes folder in Settings (default `~/Documents/Topstash/`), so that I can put it in a synced or versioned place.
50. As a user, I want to set the global shortcuts (save, and search) in Settings, so that they don't clash with my other shortcuts.
51. As a user, I want to adjust the hover delay in Settings, so that I can tune how sensitive the panel is.
52. As a user, I want the notes folder created automatically if it doesn't exist, so that the first save just works.
53. As a user switching notes folders, I want the app to load notes from the new folder right away, so that the change takes effect immediately.

### Open source
54. As a potential contributor, I want the Xcode project generated from a readable `project.yml`, so that pull requests don't fight over the generated project files.
55. As a potential contributor, I want the project to build from the terminal, so that I can work without clicking through Xcode.

### Keyboard retrieval
56. As a user, I want a global shortcut that opens the panel straight into search with the field focused, so that I can find a note without the mouse. It has no default, because the likely combinations are standard macOS commands or common editor shortcuts; I set it in Settings. Esc closes the panel and leaves me in the app I was using.
57. As a user, I want "Search Notes…" in the menu bar menu, showing the shortcut if I've set one, so that I can open search from the menu bar and learn its shortcut.
58. As a user searching, I want the first result selected as I type and ↑/↓ to move the selection, while the search field keeps focus, so that I can pick a note without the mouse.
59. As a user, I want Return to copy the selected note and close the panel, so that I can paste it right away.
60. As a user, I want to turn on, in Settings, ⌥Return copying the selected note and pasting it into the app I was using, so that one keystroke puts the prompt where I need it. Topstash asks for Accessibility permission the first time I use it, and never if I leave it off.
61. As a user, I want a line of key hints under the search results (⏎ Copy, ⌥⏎ Paste when it's on, ↑↓ Move), so that I learn the keys.
62. As a user, I want the panel to close shortly after I click a note to copy it, once "Copied" has shown, so that I can paste right away.

### Clipboard markers
63. As a user of a password manager, I want text marked as concealed (`org.nspasteboard.ConcealedType`, or the legacy `com.agilebits.onepassword`) never shown on the save card and never saved, by click or shortcut, so that passwords don't appear in the notch or on disk. The card reads "Hidden content".
64. As a user, I want text marked as temporary (`org.nspasteboard.TransientType`, or the legacy `de.petermaurer.TransientPasteboardType`, `com.typeit4me.clipping`, and `Pasteboard generator type`) treated as nothing to save, so that it never ends up in my notes.
65. As a user, I want text marked as auto-generated (`org.nspasteboard.AutoGeneratedType`) still shown and saveable, so that Topstash, which saves only when I ask, doesn't hide something I chose to keep.

## Implementation Decisions

- **Platform:** macOS 14+ (Sonoma). Swift with SwiftUI for views and AppKit for the window, mouse, clipboard, and screen work. Not sandboxed. MIT license.
- **Project setup:** XcodeGen (`project.yml`) generates the Xcode project, and the app builds with `xcodebuild`.
- **Dependencies:** only `KeyboardShortcuts` (sindresorhus, MIT) for the global shortcut and its recorder control in Settings. Launch at login uses the built-in `SMAppService`. Frontmatter is parsed by hand (only three fields), with no YAML library. No notch library: DynamicNotchKit and NotchKit were evaluated, but they target showing content from the notch when the app decides to, not opening on hover after a delay, and their fallback for screens without a notch is a visible pill, which is out of scope.
- **App shell:** the app is an agent app (`LSUIElement`), so it has no Dock icon. A SwiftUI `MenuBarExtra` provides Settings, Open notes folder, and Quit. A SwiftUI `Settings` scene stores the notes folder and the hover delay with `@AppStorage`. Launch at login is not stored: its state is always read from `SMAppService.mainApp.status`, because the user can also change it in System Settings.
- **Architecture:** plain Model + View with `@Observable`, with no MVVM layer. The Model (`Note`, `NotesStore`, `NoteFile`) lives in a `TopstashCore` framework (Foundation and CryptoKit only, no AppKit or SwiftUI; logging via `os.Logger`), so tests use only its public API and never launch the app. Everything UI-facing is `@MainActor`. Ticket #1 has the full file layout and signatures. Modules:
  - **NotesStore** (`@Observable`, deep module, the main seam): owns the in-memory list of notes for one folder. Its interface:
    - `notes`: all notes, newest first.
    - `recent(limit)`: the newest notes, up to the limit.
    - `search(query)`: matches every word, ignores case, looks at the full text.
    - `contains(text)`: whether that exact text is already saved.
    - `save(text)`: returns `saved(note)`, `alreadySaved(note)`, or `empty`.
    - `delete(note)`.
    - `reload()`.
    - The folder location is passed in when the store is created, along with an injectable clock and time zone for tests.
  - **AppModel** (`@Observable`): the composition root. It owns the current `NotesStore` (replaced when the folder changes), the `FolderWatcher`, the `Clipboard`, and `PanelModel`. It holds the actions shared by the save card, the menu bar, and the shortcut: save clipboard, copy, delete, open in editor, and set folder.
  - **PanelModel** (`@Observable`): UI state of the panel: mode (closed, open, search, feedback), save card state, search query, and the "Copied" row.
  - **NoteFile:** turns a note into Markdown with frontmatter and back, and builds filenames. Used only by NotesStore.
  - **FolderWatcher:** watches the notes folder with FSEvents (file-level events; a directory `DispatchSource` would miss in-place edits) and calls `NotesStore.reload()` when anything changes. The stream latency (0.3 s) is the debounce.
  - **Clipboard:** a thin wrapper around `NSPasteboard.general`. It provides:
    - `hasText()` via `availableType(from: [.string])`, which inspects types, not contents. The `detect` APIs only recognize patterns such as URLs and numbers, not "any text", so they can't answer this.
    - `readText()`.
    - `access` (`allowed`, `wouldPrompt`, `denied`) based on `accessBehavior` on macOS 15.4 and later; always `allowed` before that.
    - `write(text)`.
    - `marker`: whether the clipboard is marked concealed, transient, or auto-generated ([nspasteboard.org](http://nspasteboard.org)), read from `types` like `hasText()`, so it never reads the contents. Concealed and transient text never reaches `readText()`.
  - **NotchPanelController:** for each screen, works out the hover area: the notch rectangle when there is one (from `safeAreaInsets` and the auxiliary top areas), otherwise a notch-sized strip at the top center. It tracks the mouse with global and local `mouseMoved` event monitors (no Accessibility permission, and no invisible window over the menu bar), applies the hover delay, places and shows or hides the panel, and rebuilds the hover areas when the screen setup changes.
  - **NotchPanel:** a borderless `NSPanel` that doesn't activate the app or take focus. It sits above the menu bar, appears on all Spaces and over full-screen apps, and hosts SwiftUI content. It becomes key only while the search field needs typing.
  - **Views:** `PanelView`, which contains `SaveCard`, the recent list, an expanded search view, and `NoteRow`.
- **Note model:** identity (`Identifiable.id`) is the file URL, because frontmatter ids repeat when a user copies a file. The frontmatter id is stored as `noteID` (a short random hex string), `created` (an ISO-8601 date with time-zone offset), `type` (`text` for now), `body` (the exact clipboard text), `title` (worked out from the first non-empty line, never stored), and the file URL.
- **File format:** one `.md` file per note, with frontmatter followed by the body exactly as saved:
  ```
  ---
  id: 7f3a9c2e
  created: 2026-11-08T19:52:14+04:00
  type: text
  ---
  <clipboard text, verbatim>
  ```
  - Filenames follow `yyyy-MM-dd-HHmm-<slug>.md`. The slug comes from the title (lowercase, ASCII, hyphenated, length-limited). If the name is already taken, a numeric suffix keeps it unique.
  - Files without frontmatter are read with fallbacks: `created` comes from the file's creation date, `type` is `text`, and `id` is derived from the path. The app doesn't rewrite them.
- **Duplicate detection:** an exact match on the body text. Comparison may ignore leading and trailing whitespace only.
- **Ordering:** by `created`, newest first, with ties broken by filename (descending) so the order is always the same. No usage tracking: copying a note doesn't reorder it and no copy count is kept.
- **Save card states:**
  - Has text and can read: preview plus character count; clicking saves.
  - Has text but reading would trigger the alert: "Text ready to save" plus a hint linking to `x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Pasteboard`. Clicking reads the clipboard and saves.
  - Has text but paste access is denied: "Topstash can't read the clipboard" plus the same link; clicking does nothing.
  - Already saved: a label only; clicking does nothing.
  - Hidden content (concealed): a label only, no preview; clicking and the shortcut do nothing.
  - Nothing to save: greyed out.
- **Hover delay:** 250 ms by default, adjustable in Settings.
- **Delete:** moves the file to the Trash. No confirmation dialog.
- **Copying:** clicking a note copies it, shows "Copied" for about 0.5 s, then closes the panel as a dismissal (it stays closed until the cursor leaves). Return in search copies and closes at once. Copying leaves the save card as it is until the panel next opens: switching it to the shorter "Already saved" would move the list, and the row just clicked, out from under the cursor.
- **Keyboard in search:** the search field keeps focus; `onKeyPress` (macOS 14+) handles ↑/↓ and ⌥Return. Plain Return goes through the field's `onSubmit`, because the field takes it before `onKeyPress` sees it. The selection is an index into the results, reset to the first result whenever the query changes (not when the field sets the same text again), and scrolled only as far as needed to keep it in view.
- **Search shortcut:** a second `KeyboardShortcuts` name with no default, recorded in Settings under the save shortcut. It opens the panel in search mode on the screen with the cursor, and the panel becomes key so the field can take typing. If the panel is already in search, the shortcut closes it.
- **Paste (opt-in):** off by default. When on, ⌥Return copies the note, closes the panel, then posts ⌘V with `CGEvent`. Before the first paste it checks `CGPreflightPostEventAccess()` and asks with `CGRequestPostEventAccess()`; without access it copies only and says so. Because `NotchPanel` doesn't activate the app, the previous app should still be frontmost; verify this.
- **Titles:** the first non-empty line, skipping lines that are only a code fence and removing leading `#` heading markers.
- **Unknown note types:** files whose `type` isn't `text` are skipped by v1, not shown as text.
- **Folder scanning:** top level only, not recursive. Hidden files are skipped.

## Design & Motion

Decided after researching open-source notch apps (NotchKit and DynamicNotchKit, both MIT; boring.notch is GPL-3.0, read only, never copied; NotchDrop, MIT) and Apple's HIG and the WWDC23 session "Animate with springs".

- **Look:** a single black shape that grows out of the notch, the same in light and dark mode. Its top corners curve outward (reverse fillets) so it looks like part of the hardware notch. Collapsed, it is 4 pt narrower and shorter than the notch, with no outward corners (radii 0/14), so it hides behind the hardware notch on the first and last frames; expanded, its radii are 15/20 pt, clamped so the path never crosses itself. An oversized black backing is masked by the shape so spring overshoot never shows a gap.
- **Window:** a fixed-size transparent `NSPanel` in which only the SwiftUI shape animates; the window frame is never animated. The panel is ordered out while closed, so it never blocks clicks. While open, it takes mouse events only while the cursor is over the visible shape (`ignoresMouseEvents` follows the cursor), so clicks around the shape reach the windows below. `hasShadow = false` and `animationBehavior = .none` (the system's fade on ordering out showed a translucent ghost of the closed shape), and the shadow is drawn in SwiftUI with padding. The first click on a card must register (`acceptsFirstMouse`). Collection behavior: `[.fullScreenAuxiliary, .canJoinAllSpaces, .stationary, .ignoresCycle]`.
- **Shape motion:** expanding uses `.snappy(duration: 0.4)` (bounce about 0.15); collapsing uses `.smooth(duration: 0.3)` with no bounce. The shadow is drawn only while open and fades with the shape, since the hardware notch casts none (`docs/research/notch-animation.md`).
- **Content:** comes in with opacity, blur 8→0, and scale 0.96→1 anchored at the top, using `.easeOut(0.22).delay(0.07)`. All content is masked by the animated shape, so nothing (in particular the still-blurred card and rows) draws outside it while it grows. It leaves with opacity only, `.easeIn(0.12)`, before the shape closes. Rows are not staggered.
- **Save feedback (about 0.6 s total):** the card dips to scale 0.96 on press. On save, the card shrinks and flies up into the notch, the notch does a small "gulp" bump (`.spring(response: 0.3, dampingFraction: 0.5)`, scale 1.04), a checkmark appears with `.symbolEffect(.bounce)`, and a trackpad haptic fires.
- **Reduce Motion:** the shape expands and collapses with a plain `.easeOut(0.2)` and no bounce, content only fades (no blur or scale), and saving cross-fades a checkmark and fires the haptic.

## Visual Design

Decided after a research pass against primary sources (`docs/research/notch-panel-design.md`) and a rendered prototype (branch `prototype/notch-panel-design`). The panel stays black and white, with no accent color.

- **Type:** SF Pro, default design, with the system's own tracking. Two sizes and two weights, matching macOS Body (13) and Subheadline (11):
  - `title`, 13 medium: row titles, the header label, the card's labels, "Saved".
  - `body`, 13 regular: the clipboard preview, the search field, empty states.
  - `meta`, 11 regular with monospaced digits: row previews, ages, counts, hints.
  - `metaMatch`, 11 semibold: the query's words in a search result's preview, in the primary color, so a match stands out by weight, not color alone.
  - `metaKey`, 11 medium: the keys in the search's key hints ("⏎", "↑↓"), in the secondary color.

  `metaMatch` and `metaKey` are the two exceptions to two weights, both at 11 pt.

  Symbols take their size from the text beside them. The "Saved" checkmark is the one larger symbol (about 22 pt).
- **Text colors:** white at 1.0 / 0.6 / 0.5 (primary / secondary / tertiary). 0.5 is the floor: anything lower fails WCAG AA (4.5:1) for 11–13 pt text on black.
- **Fills:** white 0.06 for hover and 0.10 for surfaces (the save card, the search field, the header button). 0.10 matches the system's `systemFill` in dark mode.
- **Increase Contrast:** when `colorSchemeContrast` is `.increased`, each text and fill level steps up. The values are picked on the device.
- **Keyboard selection:** a 1.5 pt ring of white 0.6 (the secondary level, so 0.8 with Increase Contrast) on the hover fill. VoiceOver's focus stays in the search field, so the selected row's title is announced when ↑/↓ move it and, at low priority, when typing selects the first result. This clears WCAG 1.4.11's 3:1 for state indicators while staying black and white; a fill-only highlight doesn't (0.16 on 0.10 is 1.2:1).
- **Spacing:** a 4 pt grid and one 12 pt inset, used from the shape's edge to the card and rows and again inside each card and row. Every text edge and the card's icon sit 24 pt from the shape's edge. Rows are 40 pt tall, and the search field 36. The save card fits its text, so its height follows the text's lines rather than the grid: 12 pt, the preview's lines (16 pt each), 4 pt, the 13 pt hint, 12 pt. A card with only a label is 40 pt.
- **Radii:** the shape is 15 (outward top) / 20 (bottom); the card is 12; the search field is 10; rows are 8, which is 20 − 12, so they nest inside the bottom corners. The radii are set by hand, because `ConcentricRectangle` needs macOS 26.
- **Width:** 400 pt in both the list and search. Switching modes changes only the height.
- **Search height:** fits its content: the header, the search field, the results (or "No matches" in one row's height), and the key hints, with `sectionSpacing` (8 pt) between them and the 12 pt inset below. It grows and shrinks with the shape's spring as the results change, up to 520 pt, where the results scroll. The results are masked by the animated shape, so rows never show outside it while it grows.
- **Header:** a band beside the notch, as tall as the notch (`safeAreaInsets.top`; the menu bar's height on screens without one), but never shorter than its 28 pt button. It replaces the fixed 38 pt clearance and the "Show all" bar. Its content sits one `inset` (12 pt) from the shape's edge, not 24 like the text below it, and each side stops at the notch.
  - Left: "Recent", or "Search" in search mode, in `title` and the secondary color.
  - Right: the note count in `meta` and the tertiary color ("4 of 12" in search), then a 28 × 28 pt circular button on the surface fill: search in the list; in search, close the panel, like Esc.
  - The search field below it shows a magnifier at its left and "esc" at its right in `meta` and the tertiary color.
- **Save card:** the `tray.and.arrow.up` symbol, up to 3 lines of preview in `body`, and a `meta` line such as "Click to save · 1,284 characters". The preview starts at the clipboard's first visible character, so its first line isn't indented; the saved note keeps the text as it is.
- **Rows:** title and preview on the left, and the age on the right in `meta` and the tertiary color ("2h", "3d", "Oct 28"). Clicking a row gives the save's feedback in the row's own size: the row dips to 0.96 while pressed, the trackpad haptic fires, and "Copied" with the save's `checkmark.circle.fill` in the primary color rises 6 pt into the preview line with blur 4 while the preview rises out (`.snappy(0.22)`). The checkmark bounces, again on every copy, and the row keeps its fill while "Copied" shows. With Reduce Motion, the lines only cross-fade and nothing dips or bounces.
  - In search, the preview is a snippet of the text after the title line: it starts about 24 characters before the first match, on a word boundary, with a leading "…", and every query word in it is in `metaMatch`. The row truncates its end with "…". A match only in the title, or an empty query, shows the normal preview.
  - In search, the selected row has the keyboard selection ring; hovering another row shows its hover fill and leaves the selection where it is.
- **Key hints:** under the search results, "⏎ Copy" and "↑↓ Move": each key in `metaKey` and the secondary color, 4 pt before its label in `meta` and the tertiary color, the hints 16 pt apart, with text edges 24 pt from the shape's edge like the rows. "⌥⏎ Paste" joins them when paste is on. Hidden when nothing matches, since the keys do nothing then.
- **Menu bar icon:** the SF Symbol `tray.and.arrow.up`, which the HIG suggests over a custom image. Make a custom SF Symbol only if a brand mark is needed later.

## Testing Decisions

- **One seam: `NotesStore`, pointed at a real temporary folder.** Nothing is mocked: no fake file system and no fake clipboard. Tests call only the public interface and check two things: what the store returns and which files are on disk. Implementation details, such as NoteFile's internals or private helpers, are never tested directly. The one exception to "nothing is mocked": `NotesStore.init(trash:)` takes the function that moves a file to the Trash (the real `trashItem` by default), so delete tests move files into a second temporary folder and never touch the user's real Trash.
- **Framework:** Swift Testing, in a `TopstashTests` bundle with no test host that links only `TopstashCore`.
- **Behaviors covered:**
  - Saving creates exactly one `.md` file with valid frontmatter, and its body is identical to the input, including whitespace and code fences.
  - Filenames follow the pattern. Two saves with the same slug in the same minute produce two distinct files.
  - The title comes from the first non-empty line, with sensible handling of leading blank lines and very long lines.
  - Saving existing text returns `alreadySaved` and writes nothing. Saving empty or whitespace-only text returns `empty`.
  - `notes` and `recent(limit)` are newest first.
  - Search matches every word, ignores case, looks at the full text, and an empty query returns everything.
  - A search result's snippet (`SearchSnippet`) starts near the first match and marks every query word, matching like search.
  - `delete` removes the file and the note.
  - After files are added, edited, or deleted directly on disk, `reload()` reflects the change.
  - Files without frontmatter load with fallback values. Malformed or non-Markdown files are skipped without crashing.
  - A store pointed at a missing folder creates it on the first save.
- **Not unit-tested:** `FolderWatcher` (it only triggers `reload()`), `Clipboard` (a thin wrapper around `NSPasteboard`), `NotchPanelController`, `NotchPanel`, and the SwiftUI views. These are checked by running the app on a Mac with a notch and on an external display.
- **Prior art:** none. The repo has no code yet, so these tests set the pattern.

## Out of Scope

- Note types other than text (images, rich text, files, links with previews). The `type` field is reserved for them.
- Usage tracking: copy counts, last-used time, and sorting by "recent" or "most used".
- Editing inside the panel. Editing happens in an external editor.
- Tags, folders, titles typed at save time, and pinning.
- A clipboard history or automatic capture of everything copied.
- A fake notch pill or other visible trigger on screens without a notch.
- A separate library window.
- Fuzzy search.
- App Store distribution and sandboxing. Notarized downloads and auto-update (Sparkle) are deferred until the project is open-sourced.
- Sync built into the app. Users can place the folder in iCloud or Dropbox, or under git, themselves.
- Support for macOS 13 and earlier.

## Further Notes

- **Clipboard privacy is uncertain.** macOS 15.4 introduced a preview of alerts when an app reads the clipboard programmatically, and it's unconfirmed whether those alerts are on by default in the shipping macOS 26. Verify on first run. The fallback built into the save card covers both outcomes.
- **Hardware check:** the developer's machine is a MacBook Pro (Mac15,6) with a notch, Xcode 27.1, and Swift 6.4. Test the screens-without-a-notch path on an external display.
- **Build order:**
  1. The Model layer and its tests.
  2. The notch panel and hover behavior.
  3. Saving, the list, and search.
  4. Settings, the shortcut, and launch at login.
- **Name:** Topstash. topstash.app was unregistered on 2026-11-08; topstash.com has been registered by a third party since 2011 (expires 2027-07-27).
