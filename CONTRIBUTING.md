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

## Test

Tests use [Swift Testing](https://developer.apple.com/documentation/testing).

```sh
xcodebuild test -scheme Topstash -destination 'platform=macOS'
```

Model tests run `NotesStore` against a real temporary folder. Nothing is mocked. UI, window, and clipboard code is checked by running the app.

## Spec and tickets

The product spec is [`docs/SPEC.md`](docs/SPEC.md), and work is tracked in GitHub Issues. Read the spec before starting larger changes, and open an issue to discuss anything that isn't already covered by one.

## Pull request checklist

- [ ] The change is focused and linked to an issue or ticket, if there is one.
- [ ] `xcodegen generate` and `xcodebuild` build without errors or new warnings.
- [ ] `xcodebuild test` passes, and new behavior in `NotesStore` has tests.
- [ ] No generated files (`.xcodeproj`, build products) are committed.
- [ ] UI changes were tried on a notched screen and, where relevant, on an external display. Screenshots are attached.
- [ ] The README or spec is updated if behavior changed.

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE) and that you will follow the [Code of Conduct](CODE_OF_CONDUCT.md).
