# Offline Game UI

This design covers the offline AI and local two-player game screens. It does
not include accounts, networking, rankings, chat, or monetization.

Companion specifications:

- `game-interaction-spec.md`: state transitions, input, motion, lifecycle, and
  accessibility.
- `game-audio-spec.md`: sound cues, music direction, mixing, and audio
  lifecycle.

## Responsive Layout

- Mobile (`< 720dp`): opponent status, board, player status, and a fixed bottom
  command bar are stacked vertically.
- Desktop (`>= 720dp`): the board remains the dominant left pane while status,
  move history, evaluation, and commands move into a right console.
- The board always keeps a stable 9:10 aspect ratio. Dynamic labels, clocks,
  hints, and loading states must not resize it.

## Command Hierarchy

- Persistent commands: menu, undo, hint, and settings.
- Contextual commands: pause/resume and start a new game.
- Destructive commands: resign and abandon game live inside the menu and
  require confirmation.
- Hint uses an active accent only while a hint is shown or being calculated.
- Disabled actions remain visible but clearly muted.

## Game State

- Each side has a fixed status row containing identity, current state, and
  clock.
- The active side uses a small jade-green status indicator; color is never the
  only state signal.
- Selection, legal destinations, and the previous move use three distinct
  markers.
- Save status is passive feedback and must not interrupt play.

## Visual Direction

- The wooden board is the primary texture; surrounding surfaces remain quiet.
- Follow the system light/dark appearance. The night design uses warm graphite,
  dark walnut, vermilion for red-side identity, ivory for black-side identity,
  jade for active interaction, and amber for previous-move markers.
- Liquid Glass belongs only to the functional layer: navigation, toolbars, and
  the desktop inspector. The board, move table, and status content remain
  stable content surfaces.
- Avoid oversized headings, nested cards, decorative pills, and marketing-style
  copy.

## Theme Asset Contract

Each board theme is a self-contained directory registered in
`assets/skins/catalog.json`. A theme contains:

- `config.json`: theme identity, logical board size, four board anchors, piece
  size, and asset paths.
- One board bitmap containing the complete board surface, frame, grid, palace,
  and river marks. Flutter does not redraw or guess the grid.
- Four anchors (`topLeft`, `topRight`, `bottomLeft`, `bottomRight`) identifying
  the outer playable intersections. All 90 intersections are calculated by
  bilinear interpolation, so slightly skewed or perspective-styled boards
  remain supported.
- Fourteen transparent piece images. Board, pieces, page backgrounds, and
  interaction markers remain separate layers and can be replaced independently.
- Optional mobile and desktop page backgrounds.

Adding or switching a theme must not require changes to board layout or input
handling. The same anchor transform controls both piece placement and tap hit
testing.

Current theme packages:

- `woods`: original classic board.
- `night`: dark walnut board for the night direction.
- `maple`: light maple board based on the low-relief wooden reference style;
  this is the current default while the theme picker is pending.

## V2 Interaction Decisions

- Mobile has one overflow menu in the top bar. It is not duplicated in the
  bottom command group.
- The primary mobile group contains undo, hint, and notation. Settings, sound,
  board flip, new game, and resign are secondary actions.
- Desktop uses a resizable inspector for status and notation rather than a
  mobile-style bottom navigation bar.
- Mobile touch targets are at least 48dp and separated by at least 8dp.
- Glass controls must fall back to an opaque, high-contrast material when the
  platform requests reduced transparency or increased contrast.

## References

- `offline-game-desktop.png`
- `offline-game-mobile.png`
- `offline-game-desktop-v2.png`
- `offline-game-mobile-v2.png`

External guidance:

- Apple Human Interface Guidelines: Materials
  <https://developer.apple.com/design/human-interface-guidelines/materials>
- Apple Human Interface Guidelines: Dark Mode
  <https://developer.apple.com/design/human-interface-guidelines/dark-mode>
- Android accessibility touch target guidance
  <https://support.google.com/accessibility/android/answer/7101858>
