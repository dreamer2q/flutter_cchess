# Flutter Chinese Chess

`flutter_cchess` is a Flutter Chinese chess app with BLoC-based game state,
board themes, timers, and a native chess engine.

## Requirements

- Flutter SDK managed by FVM (`fvm flutter`)
- Java 17 and Android SDK 36 for Android builds
- Xcode with an installed iOS platform for iOS builds

## Quick Start

```sh
fvm flutter pub get
fvm flutter run
```

Useful checks and builds:

```sh
fvm flutter analyze --no-fatal-infos
fvm flutter test
fvm flutter build apk --debug
fvm flutter build ios --debug --no-codesign
fvm flutter build macos --debug
```

The supported runtime targets are Android, iOS, and macOS. Web is not currently
supported because the chess engine uses `dart:ffi`.

## Project Guide

- [`AGENTS.md`](AGENTS.md) contains contributor and AI-agent instructions.
- [`docs/architecture.md`](docs/architecture.md) describes runtime flow,
  state ownership, and platform boundaries.
