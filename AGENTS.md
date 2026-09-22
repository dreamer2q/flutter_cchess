# AI Contribution Guide

## Project Scope

`flutter_cchess` is a Chinese chess application built with Flutter and Dart. The
repository targets Android, iOS, and macOS. Web is currently out of scope because
the chess engine imports `dart:ffi`.

The project uses FVM. Run Flutter commands through `fvm flutter` so the command
uses the repository's configured SDK.

## Repository Map

- `lib/main.dart`: application bootstrap, global `BlocObserver`, and `MyApp`.
- `lib/chess/`: chess screen, BLoC events/states, board rendering, and game flow.
- `lib/models/`: immutable chess model types and value objects.
- `lib/engine/xqlite/`: engine/search implementation and FFI-facing structures.
- `lib/theme/`: theme BLoC and board themes.
- `lib/timer/` and `lib/timer_page.dart`: timer state and timer UI.
- `lib/utils/`: FEN parsing and board utilities.
- `assets/`: board skins, images, engines, and sounds declared in `pubspec.yaml`.
- `test/`: Flutter widget tests.
- `android/`, `ios/`, `macos/`: native runner projects and platform build settings.

See [`docs/architecture.md`](docs/architecture.md) for the runtime flow and
ownership boundaries.

## Development Commands

Run these from the repository root:

```sh
fvm flutter pub get
fvm flutter analyze --no-fatal-infos
fvm flutter test
fvm flutter build apk --debug
fvm flutter build ios --debug --no-codesign
fvm flutter build ios --simulator --debug
fvm flutter build macos --debug
```

Do not use `flutter` directly when comparing results with CI or another agent;
use `fvm flutter` to avoid silently selecting a different SDK.

## Change Guidelines

- Keep domain rules in the chess model/engine layers, not in widget build methods.
- Keep BLoC events and state transitions explicit and testable.
- Preserve FEN behavior and asset paths when changing board rendering.
- Use the existing `bloc`/`flutter_bloc` patterns before introducing a new state
  management library.
- Treat Android/iOS/macOS project files as generated or tool-managed where
  possible. Make platform edits only when required by a Flutter/Xcode/Gradle
  migration or a platform feature.
- Do not hand-edit `.dart_tool/`, `build/`, `ios/Flutter/ephemeral/`, or generated
  plugin registrants.
- Do not add Web-only code paths without first isolating the `dart:ffi` engine
  imports behind a platform boundary.
- Add or update a focused test for behavior changes. The smoke test should keep
  validating that the Chinese chess home page renders.

## Validation Expectations

At minimum, run `fvm flutter test` and `fvm flutter analyze --no-fatal-infos`.
For platform or dependency changes, run the affected native build as well.
Report warnings separately from errors; existing lint warnings are not a reason
to hide a new compile or test failure.

## Known Constraints

- The current Android toolchain requires Java 17 and Android SDK 36.
- iOS builds require an installed Xcode iOS platform and use an iOS 15 minimum
  deployment target.
- The macOS chess page can overflow vertically at the default desktop window
  size; treat this as a UI issue to fix separately from SDK migrations.
- The application title currently contains the existing `Chinses Chess` spelling;
  changing user-visible copy should be an intentional product change.
