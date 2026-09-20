# Changelog

## Unreleased

First buildable version. Player and target frames, no configuration yet.

- Player and target frames as an oUF layout: class color on a 3px edge, portrait
  in its own column, neutral health bar, power as a hairline, castbar
- Auras with an underline: buffs above the frame, debuffs below, each icon on a
  slim line the client colors by dispel type
- Two layout sets, `/uuf layout classic` and `/uuf layout modern`: top left
  with the pet above the player, or lower third with buffs above the frame.
  Each set remembers its own dragged positions, and switching needs no reload
- Aura duration and stack labels in Umbra's own font, on icons sized to hold
  them
- The power percentage reads in the color of its own bar, which now means the
  same color and not an approximation of it
- Aura icons line up with the left edge of the frame above them
- `/uuf blizzard` hides Blizzard's buff and debuff frames
- `Layouts/` split into widgets, tags, auras and the style that assembles them
- Packages for Retail (`_Mainline`) and WoW: Forever (`_Camelot`) from one source
- `Compat/Forever.lua` for the deviations found on the Forever beta client
- MIT license, packaging and lint workflows
