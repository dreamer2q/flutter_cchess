# Architecture Notes

## Runtime Flow

```text
main.dart
  -> MyApp (MaterialApp)
    -> NewChessPage
      -> ChessPage
        -> ThemeBloc + ChessBloc
          -> ChessState / ChessBoard widgets
          -> chess game and engine layers
```

`MyApp` configures the global theme, system UI, orientation, and BLoC observer.
`NewChessPage` is the entry screen. Its human-vs-computer action navigates to
`ChessPage`, which creates the theme and chess BLoCs for that game screen.

## State Ownership

`ChessBloc` owns the current board, side to move, selected piece, legal move
selection, animation move, and play status. UI events become `ChessEvent` values;
the BLoC emits a new `ChessState` rather than mutating widgets directly.

`ThemeBloc` owns the selected board theme. `Ticker` supplies time signals for
engine/search work. The chess model and engine code should remain independent of
Flutter widgets so that move rules can be tested without a rendered screen.

## Domain Boundaries

- `models/`: value objects such as pieces, positions, boards, and actions.
- `utils/`: FEN parsing and board conversion helpers.
- `chess/game/`: game orchestration and engine-facing game state.
- `engine/xqlite/`: search and low-level engine structures, including FFI types.
- `chess/bloc/`: application state transitions for a chess screen.
- `chess/view/` and `chess/widget/`: Flutter presentation and interaction.

When adding a rule, put it in the model/game/engine layer first, then expose it
through a BLoC event and state if the UI needs it. Avoid embedding legality or
turn logic in a widget callback.

## Platform Boundary

The engine currently imports `dart:ffi`, so native targets are the supported
runtime boundary. Android, iOS, and macOS share the Dart UI and engine code but
keep their runner/build configuration under their respective platform folders.
Web support would require an explicit conditional implementation of the engine;
it is not enabled by the current project.

## Assets and Generated Files

Asset directories are declared in `pubspec.yaml` and are loaded by the Flutter
asset pipeline. Do not rename or move an asset without updating both its callers
and `pubspec.yaml`.

Flutter, Xcode, CocoaPods, Gradle, and FVM may generate files while preparing a
build. Keep generated output out of feature commits unless the change is an
intentional platform migration.
