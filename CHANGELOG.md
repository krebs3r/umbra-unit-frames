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
- `/uuf auras umbra` puts away the game's own buff and debuff frames, `/uuf
  auras both` brings them back
- `/uuf` on its own lists the commands one to a line, with what each does
- `Layouts/` split into widgets, tags, auras and the style that assembles them
- Packages for Retail (`_Mainline`) and WoW: Forever (`_Camelot`) from one source
- `Compat/Forever.lua` for the deviations found on the Forever beta client
- MIT license, packaging and lint workflows
