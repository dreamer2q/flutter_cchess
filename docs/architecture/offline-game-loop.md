# Offline game loop

The offline game is split into three layers. Keep this boundary when adding a
rule, animation, sound, or command.

## Authoritative rules

`ChessBloc` owns the current `Board`, `GamePhase`, result, command permissions,
AI request generation, and persistence revision. A legal move is committed to
the board and queued for persistence immediately. No widget callback may apply,
undo, or otherwise change a rule move.

AI and hint futures return through internal events carrying a generation. A
new game, undo, resignation, or retry increments that generation so an old
future cannot mutate the current game.

## Presentation queue

Every visible change creates a `PresentationEffect` with a monotonic ID and
before/after board snapshots. The board consumes effects in FIFO order:

1. Render `beforeBoard` and animate the moving piece.
2. For a capture, fade and compress the target during the move.
3. If the move checks or mates, switch the effect to `feedback` and render the
   declarative overlay.
4. Acknowledge the effect ID and show the next queued effect.

Acknowledgement only advances presentation. Stale or repeated IDs are ignored.
Reduced-motion mode follows the same state transitions with zero-duration
animations.

`GamePresentationCoordinator` consumes a completed effect once and selects the
side-specific sound and haptic. Lifecycle suspension stops transient playback;
resuming never replays an earlier effect.

## Input and persistence

Widgets use the derived permissions on `ChessState` (`canInteractBoard`,
`canUndo`, `canHint`, `canPause`, `canRetryAi`, and `canFlip`). Do not duplicate
these conditions in a screen.

Game saves are serialized. `flushPersistence()` is awaited before leaving a
game, while save failures remain non-destructive and visible in state. Restored
AI games that stop on the computer turn immediately resume AI calculation.

## Verification checklist

- Add rule and race tests in `test/chess_bloc_test.dart`.
- Add animation/coordinator tests for unique effect IDs and reduced motion.
- Add viewport coverage when changing layout policy.
- Run analyze, all tests, and Android/iOS/macOS builds before merging.
