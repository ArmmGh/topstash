# Contributing

Thanks for your interest. The project is in early development, so expect things to move.

## Build

You need macOS 14 or later, Xcode, and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
xcodegen generate
xcodebuild -scheme Topstash -configuration Debug build
```

The `.xcodeproj` is generated and git-ignored. Change `project.yml`, not the project file, then run `xcodegen generate` again.

## Format

Code is formatted with Apple's [swift-format](https://github.com/swiftlang/swift-format), which ships with Xcode. The settings are in `.swift-format`, and CI fails if a file isn't formatted.

```sh
xcrun swift-format format --in-place --recursive Topstash TopstashCore TopstashTests
```

## Test

Tests use [Swift Testing](https://developer.apple.com/documentation/testing).

```sh
xcodebuild test -scheme Topstash -destination 'platform=macOS'
```

Tests run hosted in the app and reach its internals with `@testable import Topstash`. `NotesStore` tests still use real temporary folders. App logic such as saving the clipboard, the save card's states, and the notch's open and close rules is tested with fakes: `FakeClipboard` stands in for the system clipboard and `ManualScheduler` runs delays without waiting. Window, focus, and drawing behaviour is still checked by running the app.

## Spec and tickets

The product spec is [`docs/SPEC.md`](docs/SPEC.md), and work is tracked in GitHub Issues. Read the spec before starting larger changes, and open an issue to discuss anything that isn't already covered by one.

## Pull request checklist

- [ ] The change is focused and linked to an issue or ticket, if there is one.
- [ ] `xcodegen generate` and `xcodebuild` build without errors or new warnings, and `swift-format` reports nothing.
- [ ] `xcodebuild test` passes, and new behavior in `NotesStore` or app logic has tests.
- [ ] No generated files (`.xcodeproj`, build products) are committed.
- [ ] UI changes were tried on a notched screen and, where relevant, on an external display. Screenshots are attached.
- [ ] The README or spec is updated if behavior changed.

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE) and that you will follow the [Code of Conduct](CODE_OF_CONDUCT.md).
