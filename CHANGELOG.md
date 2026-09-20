# Changelog

## Unreleased

First buildable version. Player and target frames, no configuration yet.

- Player and target frames as an oUF layout: class color on a 3px edge, portrait
  in its own column, neutral health bar, power as a hairline, castbar
- Auras with an underline: buffs above the frame, debuffs below, each icon on a
  slim line the client colors by dispel type
- Two layout sets, `/uuf layout classic` and `/uuf layout modern`: top left
  with the pet above the player, or lower third with buffs above the frame and
  the pet between the castbar and the debuffs. Each set remembers its own
  dragged positions, and switching needs no reload
- Aura duration and stack labels in Umbra's own font, on icons sized to hold
  them
- The power percentage reads in the color of its own bar, which now means the
  same color and not an approximation of it
- Aura icons line up with both edges of the frame above them: the frame is
  now cut to the width of a row of eight rather than the row to the frame
- The target frame shows its power percentage, the way the player frame does
- `/uuf test` fills every aura slot with stand-ins, to look at a full row
  without waiting for one
- `/uuf unlock` shows every frame, including ones with no unit behind them,
  and fills their aura rows, so what you drag is the whole extent
- Dragged frames snap to each other's matching edges and middles and to the
  middle of the screen, with a guide showing what they are about to line up on
- A frame cannot be dropped on top of what another one draws: dragged onto a
  castbar or an aura row, it moves to the nearest place that covers nothing —
  for the pet, the slot the layout keeps for it under the castbar
- A frame cannot be dragged so far that its castbar or its aura rows leave the
  screen, not just its own box
- Pointing at a frame shows the unit's tooltip, the way pointing at the unit
  in the world does
- `/uuf auras umbra` puts away the game's own buff and debuff frames, `/uuf
  auras both` brings them back
- `/uuf` on its own lists the commands one to a line, with what each does
- `/uuf debug` also hands over what was refused before it was switched on,
  which is where everything interesting happens: during the build at login
- `/uuf check` also reports whether the client can compile secure snippets,
  which decides whether group frames can have a secure header
- `/uuf auras` typed in combat now takes effect when the fight ends, and says
  so, instead of silently doing nothing: the game's two aura frames are
  protected
- `Layouts/` split into widgets, tags, auras and the style that assembles them
- Packages for Retail (`_Mainline`) and WoW: Forever (`_Camelot`) from one source
- `Compat/Forever.lua` for the deviations found on the Forever beta client
- MIT license, packaging and lint workflows
