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
- Use off-white surfaces, charcoal text, vermilion for red-side identity, ink
  black for black-side identity, and jade green for active interaction.
- Avoid gradients, oversized headings, nested cards, decorative pills, and
  marketing-style copy.

## References

- `offline-game-desktop.png`
- `offline-game-mobile.png`
