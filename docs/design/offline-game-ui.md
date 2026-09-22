# Offline Game UI

This design covers the offline AI and local two-player game screens. It does
not include accounts, networking, rankings, chat, or monetization.

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
