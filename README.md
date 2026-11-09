# Topstash

Save clipboard text from your MacBook's notch.

Hover over the notch, click once, and the text on your clipboard is saved as a Markdown note. Built for keeping the useful one-off prompts you find online in one place, where you can find them again and paste them into your coding agent.

> **Early development (v0.1.0).** There are no signed or notarized releases yet, so build it from source to try it.

## Features

- **Hover to open.** A panel drops down from the notch after a short hover (about 250 ms, adjustable), and closes when the cursor leaves. It does not take focus from the app you are using.
- **One-click save.** The panel previews your clipboard text. One click saves it as a note. No title or tag prompts. Duplicates are detected.
- **Copy back.** Your 5 newest notes are listed in the panel. Click one to copy it back to the clipboard.
- **Search.** "Show all" expands into full-text search across every note.
- **Plain Markdown files.** Each note is a `.md` file with minimal frontmatter, in a folder you choose (default `~/Documents/Topstash/`). Edit, grep, sync, or version them yourself. Changes made outside the app show up automatically.
- **Works without a notch.** On external displays, an invisible area at the top center of the screen does the same job.
- **Global shortcut.** Press ⌥⌘S anywhere to save without touching the mouse; the panel drops down briefly to show the result. While Topstash runs, ⌥⌘S takes over "Save All" in Xcode and VS Code, so you can change it in Settings.
- **Stays out of the way.** No Dock icon. A menu bar icon gives you Settings, Open notes folder, and Quit. Optional launch at login.
- **Respects clipboard privacy.** Without paste access, the app saves without previewing your clipboard on hover.

## Requirements

- macOS 14 (Sonoma) or later
- Xcode with Swift 6 (to build from source)

## Building from source

The Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen) and is not checked in.

```sh
brew install xcodegen
xcodegen generate
xcodebuild -scheme Topstash -configuration Debug build
```

To run the tests:

```sh
xcodebuild test -scheme Topstash -destination 'platform=macOS'
```

## Usage

Run the app from Xcode or the build folder. Topstash has no Dock icon or main window; look for its icon in the menu bar, where you'll find Settings, Open Notes Folder, and Quit. Hover over the notch (or the top center of a screen without one) to open the panel.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)
