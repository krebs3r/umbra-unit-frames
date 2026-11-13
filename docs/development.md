# Development notes

Working notes for Umbra Unit Frames: what the client actually does, what is
built, and what comes next. The six design principles in the
[README](../README.md) are the product definition; this file is about making
them work against the API.

## Decisions

1. **Retail, WoW: Forever and the three Classic clients are one codebase.**
   Forever runs the Mainline UI (interface 16001, the 12.1.5 API set), not
   the Classic API. It reported `WOW_PROJECT_MAINLINE` until 1.60.1.70170 and
   `WOW_PROJECT_CAMELOT` (18) since — see *What the Forever client actually
   did*. Mists reports itself as a Classic
   client and carries almost all of the Midnight API anyway — see *Mists of
   Pandaria Classic*. The Anniversary realms and Classic Era turned out to
   be the same case. Five TOCs, one source tree, one oUF.
2. **oUF as the framework**, embedded through `.pkgmeta` rather than declared
   as a dependency.
3. **MIT licensed.** ShadowedUnitFrames carries no license file, so none of
   its code is used here.
4. **The design adapts to the API**, and the deviations get documented.

## Status

Done: the project foundation, and every single frame — player, target, pet,
target-of-target and the boss column — the first three verified inside an
instance under the restricted-value regime with error capture installed, and **loading and drawing on Forever, on the beta and on the release
client** — see *Forever*.

**The party column is built**, on the client's own secure header, with a
debuff row, a cast bar and a role marker — see *Group and raid frames*.

**On Retail, and on Forever's release client.** The first `/uuf dev header`
on the beta, 22 September 2026, came back in the error log rather than in the
report window: that client's own restricted environment cannot compile the
snippet its own header machinery runs on a new child, so no secure group
header worked there on that build, by oUF or by anyone — see *The secure
header does not work on Forever*. On the release client, 8 November 2026, it
built and configured a child, and the column drew a real group; the note on
build 70009 under that heading says what may have changed it.

All six design principles are implemented — class color at the edge, the
portrait column, power as a hairline, auras with an underline, hatched absorbs
with ghosted incoming healing, and range shown through fading, which arrived
with the group frames it was waiting for. Alongside them: two layout sets and
a switch that puts the debuffs over the buffs in either, the
class-power row, a cast bar, a frame mover, a switch for Blizzard's own aura
display, one for its group panel, a switch for class-colored health bars, a
theme that gives Forever its own look, an addon-list icon and packaging.

The aura underline is **verified in the open world and inside an instance**,
geometry and color both, by sampling screenshots pixel by pixel — the
measurements are under *Auras*. Nothing about the containers is refused where
they gain forbidden aspects; `/uuf dev debug` came back silent on a build run from
inside *Der Flammenschlund*.

**Range fading is confirmed in the client.** Group members out of range were
seen fading on 21 September 2026, inside an instance — the sixth principle,
and the last one that was only written. oUF's own element gates on party
membership, which is why it waited for the group header rather than being
half-built on the single frames; see *Range fading belongs to the group
frames*.

The absorbs have been seen drawing in an instance, on both the player and the
target frame, but only as stand-ins — see *Waiting to be looked at* for what
that does and does not settle.

**The portrait column came up empty on a target that answered for it.** Open
world, identity in the clear, a model file id in hand, and 1183 of 1680 pixels
one flat color — see *A file id is not a drawn model* for what that report was
and was not saying, and `/uuf dev portrait` for the box that asks the four
questions that separate what is left.

One fault has been found in use, fixed and **confirmed in the client**: the
target-of-target frame threw 716 errors in one delve run, out of oUF's own
unit comparison. See *Permission to compare two units is not an answer* — it
is also the first thing group frames would have walked into, and the finding
under it has a longer reach than the bug did.

### Slash commands

`/uuf` on its own opens the options window (since 0.6); `/uuf help` prints
the version and the list.

| | |
| :--- | :--- |
| `layout classic` · `layout modern` | switch the whole arrangement |
| `debuffs below` · `debuffs above` | whether the debuff row goes under the buff row or over it, in either set |
| `unlock` · `lock` · `reset` | move frames, per layout set; unlocking shows and fills every frame, and a group column against stand-ins for every slot |
| `auras umbra` · `auras both` | who shows your buffs and debuffs |
| `group umbra` · `group both` | whether the client's group manager — the panel on the left edge with the markers — is put away or kept |
| `health class` · `health plain` | whether the health bar takes the unit's color too, or leaves it to the edge |
| `level portrait` · `level name` · `level off` | where the level stands, or whether it does |
| `theme auto` · `theme umbra` · `theme forever` | the interface's colors, and on Forever the windows' frame; `auto` is Forever's on Forever and Umbra's everywhere else |
| `setup` | the onboarding, the questions of the first login |
| `dev` | the measurements, listed behind that word |

**The measurements moved behind `/uuf dev` on 21 September 2026.** None of them
changes how anything looks; they report, and the list someone reaches for when
they have forgotten a command should be about the frames.

| | |
| :--- | :--- |
| `dev test` | fill every aura slot with stand-ins, and the health bar's prediction; show the rest indicator |
| `dev check` | opens a report window: which unit values this client hides, the theme in force, the aura duration format, what the class-power row found, which art the rest indicator was given, whether a pet's mood can be told, and what the two say now, and per frame whether the unit's identity is secret, what its portrait could load and how many models it has loaded since the last reload |
| `dev header` | whether a secure group header works on this client, layer by layer |
| `dev party` | what the party column is made of, child by child, with each top edge in screen coordinates |
| `dev portrait` | a box with four attempts at the portrait per unit, for when the column is empty and every value says it should not be |
| `dev debug` | print what was refused while building, including before it was on |

A bare `/uuf check` and its four neighbours answer with their new address
rather than with the whole list, because five commands moved at once and the
old ones are in the fingers of the only person who uses this. The changelog
keeps the old names throughout: that is what those releases shipped.

`/uuf` closes with a line naming the author, which it reads from the TOC
rather than repeating. The heart in it is U+2665 written as itself: the
source is UTF-8 and the em dashes beside it already render in the client,
whereas a texture path has no reliable way of being asked whether it still
exists after a patch and prints nothing at all when it does not.

---

## What the client actually does

Several of these contradict the patch notes and were established by testing.

### Hidden values reach further than documented

`UnitHealth` is hidden from addons **in the open world**, not only inside
instances, Mythic+ and PvP. Arithmetic, comparison and `tostring` on a hidden
value throw.

**`UnitHealthMax` is not hidden**, and **`UnitHealthPercent` is** — both the
other way round from what this file claimed until the `/uuf dev check` run of
20 September 2026, standing in the open world on Retail 120100:

```
issecretvalue: true
UnitHealth: hidden
UnitHealthMax: readable — 405959
UnitHealthPercent: hidden
```

That is coherent once stated correctly: maximum health is static and says
nothing about the unit's current state, while a percentage is derived from the
current value and inherits its hiding.

**`string.format` does not throw on a hidden value.** It returns a hidden
string, the same way `AbbreviateNumbers` does. This matters because oUF writes
`[perhp]` as `string.format('%d', UnitHealthPercent(u, true, ScaleTo100))` and
does not wrap tag functions in `pcall`, so a throw there would take down every
health tick. It does not:

```
tag [perhp]: hidden
tag [perpp]: hidden
```

### What still works

- `FontString:SetFormattedText` **renders** hidden values. Displaying is
  allowed; reading is not.
- `StatusBar:SetValue` and `SetMinMaxValues` accept hidden numbers.
- `SetStatusBarColor` accepts a hidden color, such as the one
  `C_ClassColor.GetClassColor` returns for a hidden class. `SetColorTexture`
  and `SetVertexColor` carry no such guarantee, which is why every surface in
  Umbra that shows class color is a StatusBar rather than a texture.
- `FontString:SetFormattedText` and `string.format` both take hidden values, so
  a percentage can be displayed without ever being read.
- **`AbbreviateNumbers(value)` handles hidden values**, because the client does
  the work natively. It also takes a second argument,
  `AbbreviateNumbers(value, options)`, where `options.breakpointData` overrides
  the locale's own breakpoints. Locales without a thousands step — German among
  them — otherwise return five-digit numbers unchanged. Umbra supplies its own
  breakpoints for K and M.
- Further formatters from 12.0.5:
  `C_StringUtil.CreateAbbreviatedNumberFormatter`, `CreateNumericRuleFormatter`,
  `CreateSecondsFormatter`, `C_StringUtil.GetDefaultAbbreviationBreakpoints`
  and `CreateAbbreviateConfig`.

### Colors that name their own source

A value reads in the color of the bar it belongs to, and that color is never
read out of a hidden value. oUF's `[powercolor]` tag opens a color escape
through `GenerateHexColorMarkup`, the same route `[umbra:identity]` takes for
a class color. So the power percentage is tagged `[powercolor][perpp]%|r`
rather than colored with `SetTextColor`, which carries no guarantee for a
hidden color.

**That only matches if both surfaces read the same entry**, which rules out
`colorPowerAtlas`. With it set, the Power element paints the bar with one of
Blizzard's textures and never calls `SetStatusBarColor`, so there is no color
for the number to agree with: measured on a mana bar, the hairline rendered at
`35/106/196` while the percentage above it read `0/0/255` — which is what
`PowerBarColor` holds for mana. At four pixels tall the texture is not visible
anyway, so the atlas is off and the bar takes the color.

The target carries the same percentage, for the same reason: how much the
other side has left to spend with is worth as much as reading it about
yourself. It is not free — the number takes `valueWidth` plus a gap out of the
name column, and the frame width was chosen for the length of an NPC name in
the first place. The party column carries it too: whether the healer can still
heal is what a member's frame is read for. Pet, target of target and boss are
glanced at, not read, and keep the name's full width.

`Umbra.power` then restates the entries where Umbra disagrees with the client,
by calling `SetRGB` on oUF's existing color object rather than replacing it:
`colors.power.MANA` and `colors.power[Enum.PowerType.Mana]` are the same
object, so one write reaches every alias. Mana is the only measured entry so
far; anything not named keeps the client's color, and costs nothing, because
whatever the table says both surfaces now say the same thing.

### Layout sets

Two whole arrangements, `classic` and `modern`, switched with `/uuf layout`.
A set decides three things at once because they only hold together as a set:
where the frames sit on screen, which side of a frame each aura row hangs on,
and whether the pet sits above the player or below it. The pet can only go
above when nothing else is up there, so the aura rows move with it.

| | classic | modern |
| :--- | :--- | :--- |
| Anchored | top left | lower third, centered |
| Pet | above the player | below the castbar |
| Buffs | below, nearest the frame | above the frame |
| Debuffs | below, outside the buffs | below the pet |

Two things follow from having sets at all:

- **Saved positions are keyed by set.** The same frame dragged in one
  arrangement has nothing to say about where it belongs in the other, and
  `/uuf reset` only forgets the set in force.
- **Switching needs no reload.** Aura containers are created once and placed
  separately, so `Umbra:AnchorAuras` can run again on frames that already
  exist. A row moving from one side to the other also has to be turned round:
  a row above the frame fills from its bottom edge upwards, one below from its
  top edge downwards, through `SetFlowLayoutAnchorPoint` and
  `SetFlowLayoutGrowthDirection`.

The metrics table is `Umbra.metrics`; `Umbra.layouts` holds the sets. It used
to be `Umbra.layout`, which would have read as the singular of the other.

### Debuffs above the buffs

Asked for in issue #4 by a player who keeps the frames right above the action
bars, and added in 0.8 as `/uuf debuffs above` and a *Debuffs* switch in the
window. In `modern` the debuffs hang under the pet, 83 below the player frame
and 80 below the target. Blizzard's bottom bars stack from 45 upwards, each
about 45 tall with 5 between them (`MAIN_ACTION_BAR_DEFAULT_OFFSET_Y`,
`BOTTOM_ACTION_BARS_SPACER_Y` in the Edit Mode presets, live 12.1.5), so a
third bar reaches about 190 — and from the default point at 260 the debuff
rows already come down to 177 and 180.

**It is not a third set.** It moves one entry and no frame: each set's
variant is derived once at load (`set.debuffsAbove`) by one rule — the
debuffs go next to the buffs, outside them above the frame and between them
and the frame below it — so `modern` becomes `above = {targettarget, helpful,
harmful}`, `below = {pet}`, and `classic` becomes `below = {harmful, helpful}`.
Positions stay keyed by the set, so a dragged frame stays where it was.

**It is resolved per frame.** `Umbra:Stack(config, set)` hands out the variant
only to a frame that carries both rows. A party member has debuffs and no
buffs to put them over, so its row stays below, and the header's spacing,
the column's height and the stand-ins never see the switch. StackOffset walks
`Stack`, and so do the four places that walk a side themselves: `AnchorAuras`,
the mover's `Slots` and `Bands`, and the onboarding's miniature, which
re-places its rows on every refresh because its screens are built once.

**The points are not derived again**, and that was checked rather than
assumed: `tools/mockups.py`'s arithmetic, run with `DEBUFFS_ABOVE` on and
off, gives every set the same points, party slot and boss column.
Each point reads an entry the rule does not move — the pet and the target's
target stay first on their side — or, for the classic party column, the whole
reach below the player, which is a sum. What does change is the reach:

| `modern` | above, off → on | below, off → on |
| :--- | :--- | :--- |
| player | 64 → 96 | 83 → 51 |
| target | 67 → 131 | 80 → 16 |

From the default point that puts the top of the target's stack at 432, above
the middle of a 768-unit screen and clear of the party and boss columns at
16:9 and 16:10.

The switch goes through `ApplyLayout`, because a reach that changes means new
clamp insets, and `SetClampRectInsets` on a secure frame is refused in a
fight. Those insets are also why a frame dragged right against the top of
the screen moves down when its stack grows: the clamp keeps the whole stack
on screen. A frame that was snapped against the old over-line is not moved off
the rows that now stand there; the mover only asks at the end of a drag.

### Themes

Added in 0.9: `/uuf theme auto|umbra|forever` and a *Theme* switch in the
window. The code is `Core/Theme.lua`, and its comment block is the design. Two
palettes for the interface around a unit: `umbra`, the slate and teal every
release has worn, and `forever`. `auto`, the default, picks `forever` on WoW:
Forever and `umbra` everywhere else. A save from before 0.9 has no `theme` and
is given `auto` like a fresh one, so on Forever the update changes the colors;
the changelog says so rather than leaving it to be noticed.

**It exists for Forever's look.** That client's own art — the tooltip, the
zone plaque, the minimap ring — is flat dark panels with a one-pixel bronze
line, lit from the top left, and under `forever` a frame body wears the same.
The values were sampled rather than chosen, on 7 November 2026, off lossless
screenshots of that art: the plaque measured `#110D09` and the tooltip
`#161017`, and the plate is a touch lighter than either, without the
tooltip's violet, at Umbra's own 0.96 opacity; the
panel lines run from `#9A846B` at the top to `#8B6E4A` at the bottom, so the
rim is a step darker on the right than on top and darker again at the bottom;
the accent comes from the specular highlights on the minimap ring's lip and
the plaque's corner; and the title is `NORMAL_FONT_COLOR`, measured off
*Aktive Quests* as `#FFD200`. The title is only ever a window's: on a frame,
that yellow is the target level's difficulty color.

| | `umbra` | `forever` |
| :--- | :--- | :--- |
| `background` | `20/25/37` at 0.96 | `21/18/15` at 0.96 |
| `border` | `11/14/21` | `10/8/6`, the black band under every bronze line |
| `portraitGround` | `35/43/60` | `38/34/28` |
| `text` | `230/233/240` | `240/233/218` |
| `muted`, `auraHelpful` | `141/151/171` | `166/160/148` |
| `accent` | `117/220/196` | `240/204/140` |
| `cast` | `168/124/51` | `186/104/22` |
| `title` | the text color | `255/209/0` |
| `rimTop` · `rimRight` · `rimBottom` | the border color, and not shown | `154/128/92` · `128/104/72` · `104/80/52` |

**Under `umbra` nothing looks different.** The four keys only `forever` needed
are there too: the title is the text color the windows' titles always had, the
three rim keys are the border color the windows' outer line always had, and a
frame body does not show its rim at all. The options window and the onboarding
take `rimTop` on the border that already lay outside them, and `title` for
their title — except on Forever itself under `forever`, where they wear the
client's own window frame instead (*The windows in Forever's own frame*
below). That border is one unit wide under `umbra`, as it always was,
and one physical pixel under `forever`: a unit renders as one pixel on one
side and two on the next, which a near-black line hid and a bronze one does
not. `Umbra:Outline` places it, and places it again on a switch or a new
scale. The report window is the client's own template
wherever the client has one, which is not ours to color; only its fallback
takes the rim, and keeps the accent on its title.

**A second pass tried to break the palette, and moved three things.** The
CIEDE2000 distances below are worked out from the values (sRGB, D65), not
measured off a screen:

- **The warrior.** The rim, the accent and the muted text all sat within 10 of
  the warrior's class color, `198/155/109`, so a warrior's edge read as one
  more side of a bronze frame. Now the nearest is the rim's top line at 11.2;
  the accent is 13.6 away, the muted text 14.6, and the darker right and bottom
  lines 20.5 and 31.3. The rim draws no line down the left side, which stays
  the class edge's. Its top and bottom lines first started where the edge
  ends. Seen in the game on 8 November 2026, with the rim still a pixel
  outside the body, an edge that stopped a pixel short of the lines read as
  standing outside the frame, so the two lines were run over it as well.
  Once the rim moved inside, the edge reaches the body's first and last row
  just as the lines do and stands as the left side on its own, so the lines
  went back to starting where it ends. Laid side by side on the lossless
  screenshots, that capped the two-unit gap between the edge and the
  portrait at both ends and boxed it in, so the lines now start where the
  portrait begins: the left side is the edge and its gap, both on the whole
  height, and the bronze frames the portrait and the bars. Tan and bronze no
  longer touch, but a warrior's edge still stands two units from the line,
  and the 11 CIEDE2000 stay for that.
- **The cast bar.** Under bronze chrome, the gold it had read as more chrome,
  and a cast is unit information — the reason `Core/Defaults.lua` gives for the
  cast color in the first place. It is an amber now: 4.13:1 under white, 3.42:1
  under the theme's text color. For scale, Umbra's own `168/124/51` is 8.7 from
  the rim's top line, and the amber 15.1.
- **One physical pixel, not one unit.** At 1.3125 pixels per unit, the scale of
  the 7 November screenshots, a one-unit line renders as one pixel in one place
  and two in the next. So each line is `PixelUtil.GetPixelToUIUnitFactor()`
  over the frame's effective scale, and one unit where a client has no
  `PixelUtil`.

**The rim lies inside the body, on its outermost pixels.** It began a pixel
outside, and seen in the game on 8 November 2026 two things came apart that
Umbra had kept exact. The frame stood a pixel wider on the right than the cast
bar under it and the aura row over it, which are cut to the same 222 units —
the width the aura row sets, as *The right edge lines up too* says. And where
two frames are stacked two units apart, the target of the target over the
target, the upper frame's bottom line and the lower one's top line filled the
gap like a groove. Both variants were laid side by side on the lossless
screenshots before the move. Inside, every edge is where the metrics put it,
stacked frames keep their gap, and the line belongs to the plate as the line on
Forever's own tooltip belongs to the tooltip. It costs the outermost pixel of
whatever touches the edge: the last row of the power hairline or the
class-power pips, the first and last row of the portrait, the last row of the
level plate, and on a party member the first row of the role mark.

The three lines are textures of a child frame five levels above the frame,
over the portrait, its 2D stand-in and the level plate and under the mover's
overlay. As regions of the frame itself they would draw under every child and
be covered wherever the portrait or a bar touches the edge. The right line runs
the full height and owns both corners; the top and bottom start where the
portrait begins and end where the right line begins, so nothing is drawn
twice. `Layouts/Shared.lua` builds one on every frame, `Umbra:Rim(self,
l.classEdge + l.gap, width, height)`, and the theme only shows or hides it, so
a switch builds nothing.

**Switching repaints what is already built.** Every setting takes effect where
you stand, and colors are no exception, so whatever is painted from the
palette at build time is painted through `Umbra:Paint(region, color, alpha,
method)`, which remembers it in a table with weak keys. The type picks the
call — `SetColorTexture`, `SetTextColor` for a FontString or an EditBox,
`SetStatusBarColor` — and `method = 'vertex'` is for a texture that carries
art of its own, which is the helpful underline. The last call for a region
wins, which is what lets a label `Widgets.Text` built in the text color be
repainted muted by its owner.

**The palette is rewritten in place, never replaced.** Six files hold
`Umbra.colors` in a local of their own, `local colors = Umbra.colors`, and
their hover scripts read `colors.accent` or `colors.text` out of it when the
pointer arrives; `Umbra:Paint` remembers the palette's own inner table for a
region, not a copy. A new table at either level would leave all of them on
the old colors. So `Umbra:ApplyTheme()` copies four numbers into each table
that is already there. Both palettes carry all twelve keys in `THEMED`, so
every table exists from the first load and a switch back leaves nothing of the
other palette behind; `umbra` itself is copied out of `Core/Defaults.lua` at
load, so the slate and teal are written down once.

`ApplyTheme` runs at the end of `ADDON_LOADED`, before any frame is built —
which repaints the mover's snap guides, painted at file load before the saved
choice could be read — and again on every switch. It repaints every
remembered region, each inside a `pcall`: inside an instance a region can
carry an aspect the client will not let an addon recolor, so the first refusal
goes to `/uuf dev debug` as `theme repaint refused:` and the rest carry on.
Then it shows or hides the rims, throws away the cached escape the level in
front of the name is colored with (`Umbra.ResetTagColors`) and asks every
frame's tags again, has the Classic clients' own aura rows color their
dispellable underlines again, and ends on `Umbra:ApplyHealthStyle()`, because
the repaint put the muted placeholder back on every class edge and portrait
tint and that puts the unit's color back wherever there is a unit.

**What oUF colors is deliberately not repainted.** The health fill, incoming
healing and the absorbs, the power hairline, the class-power pips, the dispel
color the client lays over an underline, and `auraHarmful` never go through
`Paint`: a runtime path colors each of them on its own, and remembering one
would have a switch paint over the unit's color. Some surfaces carry a unit's
color over a palette placeholder — the class edge and the portrait tint, the
power percentage, a helpful underline on the Classic rows. The placeholder is
remembered, so a frame with no unit shows the new palette too, and the owner
puts the unit's color back straight after the repaint: `ApplyHealthStyle`,
the tag's own escape, `RefreshOwnAuras`. Leaving `auraHarmful` out also
keeps the preview's cycled dispel colors on its harmful stand-ins from being
painted over. That is the README's *accent color belongs to the interface* in
code: a theme can only reach what the interface owns. The cast bar does go
through `Paint`, because oUF never recolors one, so the theme's color is the
one that stays.

**A new UI scale is measured again at once.** A frame's own scale is set
before its rim is measured and never changes after — the onboarding's
preview, at 1.15, is the one that has one — so the UI scale or the screen's
resolution is the only thing that moves the pixel answer, and `UI_SCALE_CHANGED` and `DISPLAY_SIZE_CHANGED` measure
every rim and window border again — in a fight as much as out of one: the
lines are textures of the rim's own plain frame, only anchored to the unit's
button, and a party member's frame built mid-fight already sizes its rim the
same way. The colors themselves are not protected either, so a switch should
be a result in a fight as much as out of one, like `/uuf health`; none has
been tried in one yet (*Waiting to be looked at*, the theme).

**Chat keeps Umbra's accent.** `Core/Init.lua` writes the prefix and every
value in its replies in its own `ACCENT`, `|cff75dcc4`, and that is left alone
under `forever` on purpose. Chat is the addon speaking, not frame chrome: the
same name in the same color in every chat frame, on every client, whichever
palette the frames happen to wear.

`assets/design/forever.svg` draws the player and target blocks in both
palettes, from `tools/mockups.py`'s own copy of the values — change one,
change both.

### The windows in Forever's own frame

**Status: proposed on 11 November 2026, approved as recommended the same day
after a montage, and built (`Core/Window.lua`). Both windows were seen in
the game that evening and measured, the options window under all three
themes, switched while it was open (*Seen in the game* at the end of this
section).**
The montage was cut from in-game screenshots — the frame, the dropdown field
and the inset from Hourstone's of 10 November 2026, the red buttons and
Forever's checkbox from Forever's own options of 8 November — with the rock
drawn in its measured tone, and stays outside the repository. Every position
below is computed — from Soundstone's measurements of the client's art and
from this repository's own numbers — and none of it has been seen in the
game. Where a value is Soundstone's or Hourstone's, it says so. *As built*
at the end of this section records where the build details the plan.

**Why.** Soundstone 0.4.0 and Hourstone 0.4.0, both released on 10 November
2026, put their windows on WoW: Forever into the client's own window frame:
Blizzard's `ButtonFrameTemplateNoPortrait`, with its bronze metal, the rock
ground under a dark title strip and the red close button — what Forever's
character frame, its settings and Baganator's bags wear. Next to them Umbra's
two windows are the last flat ones there. Under `forever` they wear a
near-black plate, a one-pixel bronze line and a gold title, which is the
language of Forever's tooltips and plaques, not of its windows. This plan
gives the options window (`Core/Options.lua`) and the onboarding
(`Core/Onboarding.lua`, `/uuf setup`) the same frame on Forever.

**What does not change.**

- The unit frames keep the Forever theme of 0.9. The `/uuf dev` report
  window and the page under Options › AddOns are not part of this.
- Retail, Mists, the Anniversary realms and Classic Era look as they do in
  0.9, under every theme, and so does Forever under `umbra`.
- A look changes the surface, never the information. Class and health colors
  stay; the onboarding's previews keep showing the unit frames in their own
  theme, the bronze rim on the player-frame preview included; and the red
  notes — *applies after combat*, *not on this client* — stay visible, clear
  of the frame's art.
- No new words. Both windows keep their texts, so `Core/Locale.lua` gains
  nothing, and the German strings keep the widths they were cut to.

**When the frame shows.** Soundstone and Hourstone dropped their theme
switches: their look had nothing to do but follow the client. Umbra's
`/uuf theme` mainly picks the unit frames' colors, takes effect at once and
lets `forever` be chosen on any client, so it stays, with one rule added.
The two windows wear Forever's frame when three things hold: the client is
Forever (`Umbra.isForever`), the theme resolves to `forever` (`auto` there,
or `forever` by name), and the client can draw the frame's art (*Detection
and fallback* below).

| Client | `umbra` | `forever`, or `auto` resolving to it |
| :--- | :--- | :--- |
| Forever | as in 0.9 under `umbra` | **Forever's window frame** |
| Retail, Mists, Anniversary, Era | as in 0.9 | as in 0.9 under `forever`: the flat plate with its bronze line, because these clients have other art under the frame's names, or none |

**What the two siblings confirmed, and how.** Soundstone's frames on the
mixer and on the compact bar were accepted by eye at client scale 0.7 and
Soundstone 100 %; the symbols on the bar's red buttons were counted, 3 pixel
rows above and 2 below. Its channel icons, which stood 2 pixels high when
counted, were moved by calculation without a new screenshot, and dragging by
the title strip, the tooltips and the `/dump` checks were not tried one by
one. There is no record of its options window in the frame. Hourstone's
author looked at the main window on 10 November 2026 and accepted it after
three changes; nothing was measured, and its in-game checklist has not been
worked through. So **no settings window and no dialog in this frame has been
looked at in the game anywhere**; Umbra's acceptance would be the first.

**The frame.** As Soundstone and Hourstone build it, in the window's own
units:

- A border frame of its own over the content, ten levels up, taking no
  mouse, with `NineSliceUtil.ApplyLayoutByName(border,
  'ButtonFrameTemplateNoPortrait')`, anchored TOPLEFT (−4.4, −3.35) and
  BOTTOMRIGHT (+0.5, +0.35). Soundstone measured that the opaque metal starts
  4.4 units inside the nine-slice's box on the left and reaches 3.35 above it
  at the top and 0.35 below it at the bottom, which puts it flush with the
  window on those three sides. On the right it measured the metal ending 0.5
  beyond the box; with the box itself 0.5 outside the window, that would put
  the metal about one unit beyond the window's right edge, where flush would
  be −0.5. Both siblings use +0.5 and were accepted by eye. Umbra takes the
  same anchor, so the three addons look alike side by side, and the right
  edge is the first thing to measure in the game. Measured on 11 November
  2026: flush, to within a third of a pixel (*Seen in the game*).
- The rock (`Interface\FrameGeneral\UI-Background-Rock`, a file), tiled, on
  BACKGROUND −6 from the border's (7, −21) to its (−2, 2), and over it
  `_UI-Frame-TopTileStreaks`, 43 high, on BACKGROUND −5 from (6, −21) to
  (−2, −21).
- `NineSliceUtil.UpdateCornerCropping`, which only Forever has, called in
  `pcall` with `{NineSlice = border, layoutType =
  'ButtonFrameTemplateNoPortrait'}` and the box's height, the window's height
  − 3.7. Passed the border itself it returns without a word and crops
  nothing (`NineSlice.lua` on `forever`, line 263). The two windows never
  change height, so it is called once, after the size is set. At 491 and 378
  units it is not expected to crop anything; the two corner atlases' heights,
  read with `/dump` in the game, settle it.
- The scale is UIParent's. Neither window has a scale of its own, so the
  metal is exactly as thick as on Forever's own windows. Hourstone had to
  decide this; Umbra does not.

Measured by Soundstone from the border's top: metal 6.1 wide with 5.3-unit
chamfers, the title strip from 2.8 to 19.6, the separator ending at 25.7, the
flat ground from 26.4. From the window's top, computed: the strip from 6.15
to 22.95, the separator to 29.05, the rock from 29.75. Content therefore
starts at least 29.75 below the top, ends at least 8.3 above the bottom
(band and shade) and stays at least 8.6 from the sides (metal and about 2.5
of shade) — Hourstone's clearances.

**The content stays where it is, in both looks.** The theme switch is a row
of the options window itself: a click on it re-skins the window under the
pointer. If the frame moved the rows up into the room the old header leaves,
that row would jump away from the pointer, and every row of both windows would
need a second place. So nothing moves: the frame's strip and separator take
the place of today's header (the title at 12, the line at 36), every row
keeps its y, and both windows keep their heights, 491 and 378. It leaves
about 10 units of rock between the separator and the first heading, where the
siblings start their content right under it. Computed clearances, in window
units:

| | Needed | Options window | Onboarding |
| :--- | :--- | :--- | :--- |
| First content below the top | 29.75 | 40, the *Layout* heading | 49, the eyebrow |
| Last content above the bottom | 8.3 | 12, the footer (top at 470, size 9) | 12, Back and Next |
| Controls from the left | 8.6 | 15 | 15 |
| Controls from the right | 8.6 | 12 | 12 |

The content was placed 15 from the left and 12 from the right because the
accent edge takes the first 3 units. Inside the frame that edge is gone, so
the controls stand 3 units nearer the right metal than the left. Moving them
would make every row move under the pointer again; they stay, and the right
side is looked at in the game.

**Each surface.** "Flat" is the window as it is under `forever` today, the
fallback wherever a piece of the client's art is missing.

| Umbra today | In the frame (recommended) | Alternatives |
| :--- | :--- | :--- |
| Border (`rimTop`, one pixel outside), ground, accent edge | Hidden; the frame, the rock and the streaks instead | — |
| Title, size 13 at (15, −12), in `title` | Hidden; a title of its own in the strip, size 12, centered on the border 6 below its top, in `NORMAL_FONT_COLOR` read at run time (`#FFD200` if missing), as the siblings' small windows | Left-aligned at 15 |
| Close button, 18 × 18, `×` | Hidden; Forever's red close button, 28 × 28 at the border's TOPRIGHT (0, 3): `RedButton-Exit`, `RedButton-exit-pressed`, `RedButton-Highlight` (ADD), with its own `OnClick`, because the stock one calls `HideUIPanel` | — |
| Header line at 36 | Hidden; the frame's separator takes its place | — |
| The onboarding's line at 332, over the navigation | Kept, one unit in `muted` at 0.18 as today, but cut to the content's width (15 to 308) instead of running into the side metal | Dropped |
| Section headings: `muted`, capitals | As today. Hourstone keeps its settings' labels muted too | `NORMAL_FONT_COLOR`, as Forever's own settings label each control |
| Switches of two and three fields | One of Forever's dropdown fields over the whole switch, with a one-pixel divider in each gap (*The switches* below) | Flat, as today |
| Checkboxes | Umbra's own box in the colors of Forever's settings checkbox (*The checkboxes* below) | As today; or the client's `checkbox-minimal` atlas |
| Unlock, Reset; Back, Next; *Unlock frames* | Red `UIPanelButtonTemplate` twins over the hidden flat buttons (*The push buttons* below) | Flat, as today |
| Red notes, hatching of a refused checkbox | As today, in every look and at the same places; the dropdown field shows about on the switch's own rectangle (*The switches*) | — |
| Skip, the dots, the footer and its heart, eyebrow, heading, body | As today, in the palette | — |
| The onboarding's preview boxes | Inside `InsetFrameTemplate`'s nine-slice, the inner frame Blizzard sets content into on this kind of window; the box keeps its own `PAPER` ground and its contents, and its outline is hidden under the inset | As today: `PAPER` with a one-unit outline in `border` |
| Dragging | The whole window, as today, in both looks | The title strip only, as the siblings |

**The switches.** Hourstone's format toggle on Forever is one dropdown field
over both halves with a one-pixel divider between them, the variant its
author chose from a montage after the first screenshot; red push buttons as
toggles were weighed there and not chosen. Umbra's switches take the same,
which nobody has made for three fields yet:

- The field is `common-dropdown-textholder`, the art of
  `WowStyle1DropdownTemplate` (`Blizzard_Menu/Mainline/MenuTemplates.xml`:
  120 × 25, the field anchored at (−8, 7) and (8, −9)). Here it is a texture
  of the switch's parent, from the first field's TOPLEFT (−8, 7) to the last
  one's BOTTOMRIGHT (8, −9): an atlas box of 269 × 38 in the options window
  and 309 × 38 in the onboarding. Blizzard's control is 25 high and Umbra's
  22, so the art is 3 units shorter than on Blizzard's own dropdowns, and
  its ends stretch over a field wider than any dropdown the client draws.
- A divider in the middle of each 2-unit gap: one physical pixel wide, 15
  units high on the switch's middle, in `104/80/52` (Hourstone's `outline`,
  which is Umbra's `rimBottom` under `forever`). In the options window at
  141.5 on the two-field switches and at 99 and 184 on the three-field ones;
  in the onboarding at 161.5, and at 112.3 and 210.7.
- Each field's flat ground, its tint and its 2-unit line are hidden. The
  labels keep Umbra's own rule: the chosen one in the accent, the others
  muted, the text color under the pointer. Hourstone swapped two of these
  (the chosen one in the text color, the accent under the pointer); that is
  the alternative.
- The atlas box reaches 7 above the switch and 9 below it, but most of that
  is transparent. On Hourstone's lossless screenshot of 10 November 2026, at
  1.4 pixels per unit, the field of its 185 × 25 format toggle shows as
  255 × 36 pixels, about 182 × 25.7 units: what is visible lies about on the
  control's own rectangle. So the notes stay where they are — in the options
  window on the heading's row, 3 above the switch, and in the onboarding 4
  under it — and the field's visible right edge stands about 13 units from
  the window's, clear of the metal and its shade. Hourstone's clearance test
  checks a control's rectangle for the same reason.

**The checkboxes.** `UICheckButtonTemplate` draws Retail's gray box on
Forever, not Forever's own. Soundstone measured Forever's settings checkbox
on lossless screenshots: a box of `#100C08`, a chamfered bronze edge
(`#574639` on top, `#534336` and `#493A2C` at the sides, `#5A4A39` at the
bottom) and a gold check, median `#EDC605`. The recommendation keeps Umbra's
shape and takes those colors, on three new textures that are only shown in
the frame: the 14-unit square in `#574639`, the box one physical pixel inside
it in `#100C08`, and the pip 3 units inside it, as today, in `#EDC605`. One
color stands for the four sides of the edge, which measured within a few
steps of each other. The hatch of a refused box lies over it as today.
In the UI source Forever's settings draw their checkbox from
`checkbox-minimal` and `checkmark-minimal` (`SettingsCheckboxTemplate`,
`Blizzard_SettingControls.xml`, the same on all five branches), so the art
Soundstone measured is most likely those atlases. Taking them would be the
client's own picture, but their size is unknown here, and at Umbra's 14 units
they would be drawn much smaller than in Forever's settings; that is the
second alternative.

**The push buttons.** Hourstone puts a `UIPanelButtonTemplate` over each
hidden flat button, at the same anchor and size, whose click calls the flat
button's own `OnClick`. On Forever the template is Retail's red art: its
three pieces are the files `UI-Panel-Button-Up`, `-Down` while pressed and
`-Disabled` while disabled, its label `GameFontNormal`, white under the
pointer, gray when disabled (`SecureUIPanelTemplates.xml` on `forever`). A
plain `SetText` keeps its width; only `SetTextToFit` would resize it.
Umbra's labels already take `GameFontNormal`'s face (`Core/Defaults.lua`);
whether its size there is the flat buttons' 12 is for the game to show, and
if not, the twin's label is set to 12 as Hourstone does.

For Umbra a twin has to follow more than a label. Every `Refresh` sets four
things on a flat button that its twin has to carry: the text (Lock or
Unlock, Next or Done), whether it is shown (Back is not on the first page),
whether it is enabled, and the state marks. So `Refresh` sets these through
one helper per button that sets the flat button and its twin together,
whichever look is on — Hourstone's `setLabel`, extended to shown and enabled.
The accent line and the hatch belong to the hidden flat button and are hidden
with it, and its `OnEnter`/`OnLeave` hooks no longer fire. In the frame:

- **Unlocked:** the label says *Lock*, and the twin's highlight stays on
  (`LockHighlight`, released with `UnlockHighlight`), the client's own way of
  marking a button as engaged; Blizzard does it on `forever` in
  `SharedUIPanelTemplates.lua` (`ExpandButton:LockHighlight()`). Under the
  pointer it looks the same as at rest. The alternative is the label alone.
- **Refused in a fight, while locked:** the twin is disabled and draws the
  template's own disabled art and gray label: the client's own "not now".
- **Next as the step to take:** nothing more. Blizzard's own dialogs draw
  their confirming button like the others, and Next stands where it does on
  every page. The
  alternative is a highlight held on it as on Unlock, which would make it
  look hovered all the time.

The twins never come from `Umbra.PlainButton` itself, which the report window
and the AddOns page use as well; each is created through `pcall`, as
`Templated` does in `Core/Report.lua`, and a button whose twin cannot be made
stays flat.

**Detection and fallback.** First the client, then the art: on Forever only,
each atlas through `C_Texture.GetAtlasInfo` inside `pcall`, where only a
table counts. The UI source tells which names are referenced, not what a
client draws. Each group falls back on its own:

| Group | Needs | Without it |
| :--- | :--- | :--- |
| `window` | `NineSliceUtil.ApplyLayoutByName`, `NineSliceLayouts.ButtonFrameTemplateNoPortrait` and the atlas of each of its pieces; `RedButton-Exit`, `RedButton-exit-pressed`, `RedButton-Highlight` | Both windows as today under `forever`, and none of the groups below |
| `streaks` | `_UI-Frame-TopTileStreaks` | The frame without streaks |
| `field` | `common-dropdown-textholder` | The flat switches inside the frame |
| `inset` | `NineSliceLayouts.InsetFrameTemplate` and its atlases | The preview boxes as today |
| A twin | `UIPanelButtonTemplate` built without an error | That button flat |

The rock is a file and cannot be asked for; it goes with the frame, as in
Blizzard's own template. The checkboxes take no art.

**Switching without `/reload`.** The windows are file-local and built only
when first opened; the frame's pieces are built later still, the first time
a built window is to wear the frame — at the end of its own build, or on a
switch — each group once, in a `pcall` of their own. A failure there leaves
the window flat until the next `/reload` and goes to `/uuf dev debug`, and the
window itself still opens. After that a switch only shows and hides:

- `Umbra:ApplyTheme` gains one call at its end, after `ApplyHealthStyle` and
  guarded the same way, `if self.ApplyWindowLook then`. It runs at
  `ADDON_LOADED` before any window exists and then does nothing.
- `ApplyWindowLook` decides framed or flat for each built window and shows
  one set, hides the other: border, rock, streaks, strip title, red close,
  fields, dividers, checkbox art, inset and twins on one side; outline,
  ground, accent edge, title, flat close, header line, the switches' grounds,
  the flat checkbox textures and the flat buttons on the other. One piece
  keeps two places, set again on each change, after Soundstone's `place` and
  `framePlace`: the onboarding's line at 332.
- `SetOption` then calls `OptionsChanged`, and each open window's `Refresh`
  puts back the state colors and the twins' text, visibility and state.
- Nothing of the frame goes through `Umbra:Paint`, which remembers every
  region and paints it again on each switch with `SetColorTexture` — that
  would wipe an atlas. Its art comes from the client, its few colors are
  fixed values, and the flat regions it hides keep being painted as before.
- The pieces that were anonymous locals in `Build` (ground, outline, edge,
  title, close, the lines, each switch's grounds) become fields the look can
  reach.
- The dividers and the checkbox edges are new one-pixel lines. `Umbra:Outline`
  and the rims are measured again on `UI_SCALE_CHANGED` and
  `DISPLAY_SIZE_CHANGED` by the scaler in `Core/Theme.lua`, which knows nothing
  else; the new lines are measured on the same two events by a handler of
  their own, registered only once the first of them is built — so not at all
  on the other clients.

Nothing in Soundstone or Hourstone ever switched between the frame and the
flat look in the game, only in their simulations: Umbra's switch would be the
first.

**Code.**

| File | Change |
| :--- | :--- |
| `Core/Window.lua` (new) | The art names and the detection, the frame, the strip title and the red close, the fields and dividers, the checkbox art, the inset, the twins and their helper, `ApplyWindowLook` and the measuring of the new lines. Exposed as `Umbra.Window`, never through `Umbra.Widgets`, which `Layouts/Widgets.lua` overwrites once it loads. Listed after `Core/Locale.lua` and before `Core/Options.lua` in all five TOCs, which then need a full client restart rather than `/reload` |
| `Core/Options.lua` | `Segmented` and `Check` keep their grounds as fields and offer the frame's art to the window; `Build` keeps its chrome as fields, registers the window and calls the look; `Refresh` sets the buttons through the helper; the comment on its furniture is rewritten |
| `Core/Onboarding.lua` | The same for its chrome, the line at 332, the preview boxes and its four buttons |
| `Core/Theme.lua` | The guarded call at the end of `ApplyTheme`; the pixel helper exposed for `Core/Window.lua`; the comments on the windows |
| `.luacheckrc` | `NineSliceUtil`, `NineSliceLayouts` and `NORMAL_FONT_COLOR` in `read_globals` |

The helper could also live at the end of `Core/Options.lua`, which needs no
TOC change. A file of its own keeps the frame apart from the controls both
windows share, and costs one restart of the client.

**API per client**, checked in Gethe/wow-ui-source on 11 November 2026,
branches `live`, `forever`, `classic` (Mists), `classic_anniversary` and
`classic_era`. Every new call runs on the Forever client only.

| What | `live` | `forever` | `classic`, `classic_anniversary`, `classic_era` |
| :--- | :--- | :--- | :--- |
| `NineSliceUtil.ApplyLayoutByName` | yes | yes | yes |
| `NineSliceUtil.UpdateCornerCropping` | — | yes | — |
| `NineSliceLayouts.ButtonFrameTemplateNoPortrait` | `UI-Frame-Metal-*` | `UI-Frame-Metal-*`, with Camelot's offsets (top right x −2; bottom corners y −8, bottom right x −2) | other atlases (`UI-Frame-TopLeftCornerNoPortrait`, …) |
| `NineSliceLayouts.InsetFrameTemplate` | yes | yes | yes |
| `RedButton-Exit`, `RedButton-exit-pressed` referenced | yes | yes | — |
| `RedButton-Highlight` referenced | yes | yes | yes |
| `_UI-Frame-TopTileStreaks` | atlas | atlas | a file texture under that template name |
| `UI-Background-Rock` | yes | yes | yes |
| `common-dropdown-textholder` (`WowStyle1DropdownTemplate`) | yes | yes | — (their `Classic` menu templates load instead) |
| `UIPanelButtonTemplate` | yes | yes | yes |
| `Button:SetNormalAtlas`, `SetPushedAtlas`, `SetHighlightAtlas`, `GetFontString`, `SetEnabled` | yes | yes | yes |
| `Button:LockHighlight`, `UnlockHighlight` | not in the generated documentation; used by Blizzard (`SharedUIPanelTemplates.lua`) | the same | not looked up: not called there |
| `checkbox-minimal`, `checkmark-minimal` (only for the second checkbox alternative) | yes | yes | yes |

`C_Texture.GetAtlasInfo`, `Texture:SetAtlas` with `resetTexCoords`, tiling,
sublevels and blend modes were checked for Hourstone on 10 November 2026 on
the same five branches, and `Frame:GetScript` on `live` and `forever` by its
use in Blizzard's code; Umbra calls `HookScript` on every client already. No
new events: `UI_SCALE_CHANGED` and `DISPLAY_SIZE_CHANGED` are Umbra's
already.

**How the other clients are shown to be unchanged.** Umbra has no test suite,
and none is built for this.

- By construction. The art check returns nothing unless `Umbra.isForever`,
  and `ApplyWindowLook` returns at once while nothing framed exists, so on
  the other clients no texture, frame or event handler of the frame is ever
  created. What does run there is the button helper, which for a button
  without a twin makes exactly the `SetText`, `SetShown` and `SetEnabled`
  calls `Refresh` makes today, and the regions that became fields, which
  change no drawing.
- By reading the diff: every flat region keeps its anchor, size, layer and
  paint.
- By lint: `luacheck .` in CI after the push, or locally first if it may be
  installed.
- In the game: on one other client, `/uuf` and `/uuf setup` under `auto` and
  under `forever`, beside screenshots of 0.9. On Forever under `umbra` the
  same, and once more after a round trip `forever` → `umbra` → `forever` →
  `umbra` with both windows open, when every framed piece exists and is
  hidden.

**Sheets and docs.** The sheets cannot draw the client's atlases. The
options sheet's Forever panel keeps drawing the flat look and says what it
is: `/uuf theme forever` on the other clients, and Forever's fallback. Once
the frame is accepted, a lossless in-game crop of each window can join the
README; the options window and the onboarding's first, fourth and fifth pages
show no character. Whether such a crop goes into the repository is the
author's call. The sheet draws the options window 490 high where the window is
491 (`options_layout()` closes the footer one unit sooner); it takes the
window's number. Then the reasoning that the windows wear Umbra's own
furniture, wherever it stands:

- `Core/Options.lua` (the header block and the comments at `Check` and at the
  border), `Core/Onboarding.lua` (the border), `Core/Theme.lua` (the theme's
  header and `Umbra:Outline`);
- this file: the paragraph *Under `umbra` nothing looks different* above,
  the window in *Configuration*, and the theme under *Waiting to be looked
  at*;
- the `theme` help line (`Core/Init.lua`, and the slash table in this file);
- the README's options alt text, and its and `docs/curseforge.md`'s "a gold
  title inside a bronze border" and "a gold title in a bronze border";
- the Forever panel and the captions in `tools/mockups.py`, and the SVGs it
  writes;
- a section on top of `CHANGELOG.md`. The 0.9 section stays as it is: it is
  what 0.9 shipped.

The image links in `docs/curseforge.md` move to a new tag only in a commit of
their own before a release, and only on the author's word.

**In the game.** On lossless screenshots (`/console screenshotFormat png`),
with the client build, the UI scale and the screen height noted. A new file in
the TOCs needs a full restart of the client after
`.\tools\install.ps1 -Flavor forever`.

1. **Load.** `/dump C_Texture.GetAtlasInfo("UI-Frame-Metal-CornerTopLeft")`,
   the same for `UI-Frame-Metal-CornerBottomLeft`, `RedButton-Exit`,
   `_UI-Frame-TopTileStreaks`, `common-dropdown-textholder` and
   `UI-Frame-InnerTopLeft`: each a table, or that piece shows its fallback.
   The two corners' heights say whether anything could be cropped.
2. **Frame.** The options window cropped beside a window of Blizzard's or
   Baganator's at the same scale: the metal flush on the left, top and
   bottom, and **the right edge measured**; nothing of the content in the
   bands; the title centered, `#FFD200`; the red close button under the
   pointer, pressed and clicked, and Escape.
3. **Switches.** Every switch in the field, two and three parts, the dividers
   one pixel and sharp, the ends of a 269-unit field; chosen, hovered and
   clicked; on a German client as well; *applies after combat* in a fight,
   clear of the field.
4. **Checkboxes** beside Forever's own in its settings, measured; one ticked,
   one not.
5. **Push buttons.** Unlock into Lock with its highlight held, and back;
   Unlock in a fight, disabled; Reset; the label's size under the pointer.
6. **The switch.** With the window open, `forever` → `umbra` → `forever` →
   `auto`, by the window's own switch and by `/uuf theme`: no row moves; under
   `umbra` the window matches a screenshot of 0.9; the frame comes back.
7. **The onboarding.** `/uuf setup`, all five pages: the inset around each
   preview, the rim on the player-frame preview still one pixel, Back gone on
   the first page, Next turning into Done, *Unlock frames* in a fight.
8. **Scale.** A change of UI scale with both windows open: the dividers and
   the checkbox edges stay one pixel.
9. **Another client.** On one of Retail, Mists, the Anniversary realms or
   Classic Era: both windows under `auto` and `forever`, beside 0.9.

What a capture shows goes down in this file as measured, reported or looked
at, as everything else here.

**Not known without the game.** How the frame reads around a window 280 and
one 320 wide, about as narrow as Soundstone's options, which nobody recorded;
how a dropdown field stretches to 269 and 309 units and squeezes to 38; how
the red buttons look at 64 and at 293 units wide; whether Forever's
`checkbox-minimal` would have been the better box; and what the inset's
nine-slice looks like around a near-black box rather than a table.

**Decisions**, each with the recommendation first; all twelve were decided
as recommended on 11 November 2026:

1. **The switch** stays, with the frame only on Forever when the theme
   resolves to `forever`; everywhere else, and under `umbra` on Forever, the
   windows stay as they are.
2. **Place:** the content stays where it is and the windows keep their
   heights, so a theme switch moves nothing under the pointer; or the content
   moves up into the old header's room and the windows get shorter.
3. **Dragging:** the whole window, as today; or the title strip only.
4. **Title:** centered in the strip; or left-aligned at 15.
5. **Section headings:** muted capitals, as today; or `NORMAL_FONT_COLOR`.
6. **Switches:** one dropdown field per switch with dividers, labels by
   Umbra's rule; or the same with Hourstone's label colors; or flat.
7. **Checkboxes:** Umbra's box in Forever's measured colors; or as today; or
   the client's `checkbox-minimal`.
8. **Push buttons:** red twins, unlocked shown by a held highlight, refused
   by the template's disabled art, Next unmarked; or the twins without the
   held highlight; or flat buttons.
9. **Previews:** inside the inset frame, `PAPER` kept; or as today.
10. **The onboarding's line over the navigation:** kept, cut to the content's
    width; or dropped in the frame.
11. **Code:** a file of its own, `Core/Window.lua`, which needs a client
    restart once; or the end of `Core/Options.lua`.
12. **Sheets:** the Forever panels keep the flat look and say so; in-game
    crops later, if the author wants them in the repository.

**As built.** Where the code details the plan:

- `Core/Window.lua` gives each window a look, `Umbra.Window.New(frame)`. The
  window names the flat pieces the frame replaces (`Flat`), its switches,
  checkboxes, buttons and previews (`Switch`, `Check`, `Button`,
  `Preview`) and the one piece that stands elsewhere in the frame (`Place`),
  then calls `Apply` at the end of its build. `Umbra:ApplyWindowLook()`
  applies every look again at the end of `ApplyTheme`.
- `Refresh` sets the buttons through `Window.Text`, `Window.Shown`,
  `Window.Enabled` and `Window.Held`, which make exactly the calls `Refresh`
  made before on a button that has no twin.
- The title is `GameFontNormal`, colored from `NORMAL_FONT_COLOR` at run
  time; the twins keep the template's own font and colors.
- `Segmented` and `Check` keep their grounds and boxes as fields. In the
  frame a switch hides its tint and line and a checkbox its flat pip; the
  checkbox's gold mark is shown by the control's own `Refresh`, which knows
  whether it is ticked.
- The divider and the checkbox edge are measured with `Umbra.PixelSize`,
  which `Core/Theme.lua` now exposes, on the two scale events, from a
  handler `Core/Window.lua` registers only when it builds the first of them.
- The sheet draws the options window 491 high, as the window is.

**Seen in the game.** On 11 November 2026 at 20:48, five lossless screenshots
on Forever, one of each page of the onboarding, under `auto` and in German. The preview box, 293 × 132 units, measured 384 × 174 pixels,
so about 1.3125 pixels per unit. Its edges are known in the window's own
units (15 to 308 across, 124 to 256 down), so the window's edges follow from
them; everything below is measured against those.

- **The frame is flush on all four sides.** The metal begins within 0.3 of a
  pixel of the window's left and top edges and ends within 0.3 of a pixel of
  its right edge; at the bottom it ends 0.4 to 1.1 pixels inside, under one
  unit. The right edge the plan doubted is where it should be: the
  siblings' +0.5 is right, and the description that the metal ends 0.5
  beyond the box does not hold there.
- **The title** measured `#FFD200` (the median of 301 gold pixels), centered
  on the border to within a pixel, inside the title strip.
- **The dividers** are one pixel, exactly `#685034` (104/80/52), 20 pixels
  high (15 units), each in the middle of its gap.
- **The dropdown field's** ground is `#110E09`, Soundstone's device field's.
  Its outer line lies exactly on the switch's rectangle on the left, right
  and top, and about 2 pixels above its bottom: the 22-unit switch squeezes
  art drawn for Blizzard's 25. It reads as Blizzard's field.
- **The checkboxes** measured exactly as written: a one-pixel edge in
  `#574639`, the box `#100C08`, the mark `#EDC605`.
- **The player-frame preview's rim** is still one pixel in `#9A805C`,
  `#806848` and `#685034` inside the inset, so the inset changed nothing of
  what was measured in the box.
- The red buttons, the close button, the inset and the rock were looked at:
  the author found it all very good. That is the acceptance, looked at.

At 21:00 the same evening, three more: the options window under `umbra`,
under `forever` and under `auto`, switched by its own theme row while it
stood open, the last with the onboarding's fourth page beside it. Measured
against the flat window's own edges in the same place:

- **Nothing moves.** Every row of text — headings, switches, checkboxes,
  buttons, footer — lies on the same pixel rows in the flat and the framed
  window. What differs is only what the look itself draws: the flat title
  and the accent lines under the chosen sides, or the frame's metal.
- **The frame lies on the window's edges**: the metal begins within half a
  pixel of the flat window's left edge and ends on its right, top and bottom
  edges to the pixel.
- **The dropdown fields** lie on the switches' rectangles as in the
  onboarding: on the left, right and top edges, and about 3 pixels above the
  bottom. The dividers are one pixel, in the middle of each gap, on the two-
  and the three-field switches.
- **The title** is `#FFD200` again, and so are the red buttons' labels. The
  red art lies inside the flat button's rectangle, its top about 3 pixels
  below the rectangle's.
- **Under `umbra`** the window showed the flat look with no piece of the
  frame. It was not compared with a capture of 0.9.

The labels *Gruppenverwaltung* and *Blizzard-Buffs* in the fourth page's
drawing touched each other in German; that drawing is the same in both looks,
so it is older than the frame. The buff row's label now stands under the row,
flush with its right end, in the window and on the sheet, and on the 21:00
capture the two labels stand about 50 pixels apart.

Not captured yet: the held highlight and the refused button in a fight, a
theme switch in a fight, a change of UI scale, and the other clients.

**The picture in the README** (`assets/screenshots/forever-windows.png`,
decision 12) is cut from a lossless screenshot taken at 21:17 that evening
with the released 0.10 installed, so its footer reads `v0.10`: the options
window and the onboarding's first page, each cut exactly at its metal and
set side by side. Outside the frame's 45-degree corners, and above the red
close button, the game world is transparent, so no other player's name and
no other pixel of the world is in it, and neither page shows a character.
`docs/curseforge.md` links it at the commit that added it rather than at a
tag, so the description can show it before the next release.

### Unlocking has to show what it asks you to place

**oUF calls `RegisterUnitWatch` on every frame it spawns**, so a frame whose
unit is not there is hidden. With no target and no pet, `/uuf unlock` used to
offer the player frame and nothing else — the two frames most likely to be in
the wrong place were the two you could not reach.

Unlocking therefore lets go of the watch and shows every frame, and locking
takes it back. Both calls reach the secure side and are refused in combat.
Unlocking is already refused there; locking is not, because leaving someone
with frames they can still drag is worse than finishing the tidy-up at
`PLAYER_REGEN_ENABLED`.

It also turns the stand-ins on, because placing a frame means placing all of
it: the aura rows reach further than the box does, and a frame dragged by its
middle lands wherever its rows happen to be empty. Locking puts the stand-ins
back to whatever they were before, rather than simply off.

### Dragging lands on a line, and stays on screen

**`SetClampedToScreen` clamps the box and nothing else.** A frame dragged to
the bottom edge therefore takes its castbar and its debuff row off the screen
with it, exactly the reach `Umbra:StackOffset` already answers for.
`SetClampRectInsets` fixes that, and its convention is worth writing down
because guessing it costs a reload: **each inset is added to the coordinate of
its own edge**, with +x to the right and +y up. So expanding upwards is a
positive `top` and expanding downwards a negative `bottom`, which is
`(0, 0, above, -below)` here. Two addons on this machine call it the same way
— `DialogueUI` uses `(-4, 4, 4, -4)` for an even four-unit margin and
`(-4, 4, 56, -4)` when something hangs above. The sides stay at zero because
the rows are exactly as wide as the frame.

A set switch changes both reaches, so the insets are set in
`Umbra:AnchorFrame` rather than once in `PlaceFrame`.

**Dragged by hand, a frame lands a unit or two off the one beside it**, and
that reads as a mistake rather than a choice. So while a frame is dragged,
lines on it are compared against lines on every other frame; anything within
`snapDistance` lights a guide, and releasing puts the frame on it.

**The pairings are named rather than crossed**, and the first version got this
wrong: crossing every line with every other offered *pet top to player box
bottom*, which put the pet frame on top of the player's castbar. A frame's box
is not the end of it.

- **Aligning** is edge to *matching* edge — left to left, middle to middle,
  top to top. Two frames read as a row only when the same edges agree.
- **Beside** is left edge to right edge, and only sideways: nothing hangs off
  the sides, because the aura rows are exactly as wide as the frame.
- **Stacking** goes to a slot and never to a box edge. `Slots` reads two kinds
  out of the set: where it keeps room for *another frame* — an entry naming
  one, so the pet's place between the castbar and the debuffs — and clear of
  the whole reach. An aura row is never a slot, because a frame put on one
  covers it.

In `modern` the player frame therefore offers `-18` and `-83` underneath and
nothing at `0`, and an entry counts as room for a frame by being a key in
`Umbra.frames`, which stays true of anything a later set puts in a stack.

**Not offering a line is not the same as refusing it.** That fix alone did not
hold: laid on the box edge by hand, the pet frame was 18 units from the slot
below — twice the snap distance — so nothing caught it and it sat on the
castbar exactly as before. A frame only ever snaps to what is already near.

So an overlap is refused outright. `Bands` writes down the strips a frame
actually draws — its box, its castbar, each aura block — and what lies between
them is free, which in `modern` is the space the pet belongs in. On release,
if the dragged frame would cover any of another's strips, the nearest shift
that does not is taken, however far away it is; otherwise the ordinary snap
stands. Refusing only on contact is what keeps this from fighting someone
arranging frames that never meet, and touching edges do not count as contact.

Frames beside each other are never in the way, so the horizontal ranges are
compared first — every strip is as wide as its frame, so one comparison
settles all of them.

The move happens on release, not during the drag. A dragged frame follows the
cursor, so moving it underneath makes it stick and fight rather than snap.

Asking a frame for its own rectangle is allowed here, and it is the geometry
rule that makes it so: every frame is explicitly sized and anchored to
UIParent, so nothing in its rectangle came from a unit.

### Frames reach past their own box

A frame is not the box `FrameHeight` answers for. A castbar hangs below it and
the aura rows hang below that, so anything placed underneath has to clear all
of it.

Writing the offset down as a number is what went wrong first: the pet frame's
default position was correct until a debuff row appeared under the player's
castbar and landed on top of it, overlapping by 24 units. Deriving it fixed the
collision, but the pet then kept being pushed further down as the rows below
the player grew.

**Each side of a frame is one stack, and the pet is an entry in it.** A set's
`above` and `below` lists name what hangs there, ordered outwards from the
frame, and `'pet'` stands in them next to `'helpful'` and `'harmful'`.
`Umbra:StackOffset` walks a list and answers where any one entry begins, or —
asked for nothing in particular — how far the whole side reaches. So the pet
frame's default position and the offset of the row beside it are the same
answer to the same question, and neither can be written down separately from
the other.

**Which frames hang off which is a set of keys, not a flag.** A config's
`owns` names the frames it is responsible for — `player` owns the pet,
`target` owns the target-of-target — and `Umbra:StackHeight` looks the entry
up there before treating it as an aura block. It used to be a single
`ownsPet` boolean with the pet's name written into that function, which was
the one reason a second frame could not be put into a stack without editing
the function that measures stacks. A set's list costs a frame nothing for
entries it does not own, because `StackHeight` answers nil for them.

In `classic` **nothing is placed above a frame** and the pet sits there
instead, the way ShadowedUnitFrames arranges it: above the box there is no
castbar and no aura row to clear, so adding a row below the player does not
move the pet at all. In `modern` the buffs take that space, and below the
frame the pet comes first, with the debuffs under it — so the pet stays near
the player it belongs to, and the debuff row is what gets pushed down when the
pet changes height.

Stacking several things on one side is safe either way, because the block
heights are reserved from the aura counts rather than from what the unit
happens to have on it, so each entry can take a fixed offset from the ones
before it.

The two sets measure from different corners, and a point names a different
edge in each: `TOPLEFT` fixes a frame's top edge and everything below counts
downwards, `BOTTOM` fixes the bottom edge and everything counts up. Each set
does its own arithmetic rather than sharing a formula that would have to know
which corner it is in.

### The geometry rule

**Nothing may derive its size from a widget that receives unit data.** A widget
handed a hidden value reports hidden geometry, and that travels along the
anchor chain. oUF asks the health bar for its width on every update and does
arithmetic on the answer, so a bar sized by anchors between two tag'd font
strings breaks it.

Therefore every widget gets an **explicit size** and a **single anchor to the
frame itself**. Parent and anchor may differ: the bar labels are children of
the bar so they draw above it, but anchored to the frame.

### oUF specifics

- The Health element is already fully Midnight-native: it uses
  `CreateUnitHealPredictionCalculator`, `UnitGetDetailedHealPrediction` and
  `SetAlphaFromBoolean`. **Do not reimplement it.** Its `HealingAll`,
  `DamageAbsorb` and `HealAbsorb` sub-widgets are the intended route for
  incoming healing and absorbs.
- Tag functions get `setfenv` to `_PROXY`, which falls back to `_G` through
  `__index`, so globals are visible and upvalues are unaffected.
- `oUF.colors.power` comes from the client's `PowerBarColor`.
  `element.colorPowerAtlas = true` swaps the bar for one of Blizzard's
  textures instead, and then never sets a color — see *Colors that name their
  own source* for why Umbra leaves it off.
- **oUF sets no unit tooltip, and Blizzard's handler cannot supply one.** oUF
  builds a `SecureUnitButton`, gives it the click attributes and no `OnEnter`
  at all, so without this the frames can be clicked but not read. The obvious
  fix is wrong: `UnitFrame_OnEnter` reads `self.unit`, and **an oUF frame has
  no `unit` field**. The unit lives in `frame.__unit`, kept current by
  `Private.UpdateUnits`, and again as the secure `unit` attribute. Borrowing
  the handler threw `bad argument #1 to GetUnit` on every hover, nil having
  reached `C_TooltipInfo.GetUnit`. `Layouts/Shared.lua` brings its own and
  reads `__unit`, which follows a vehicle swap where the attribute does not.
- **The ClassPower callback takes five arguments, not the four its own
  documentation lists.** The comment above it says
  `PostUpdate(cur, max, hasMaxChanged, powerType)`; the call is
  `element:PostUpdate(cur, max, hasCurChanged, hasMaxChanged, powerType, ...)`.
  Believing the comment would have had Umbra read `hasCurChanged` as
  `hasMaxChanged` and lay the pips out on every tick or none. The element also
  gives each StatusBar pip `SetMinMaxValues(0, 1)` itself, so a pip is full at
  1, and it fills the row only for a spec that owns a resource — chi on a
  windwalker monk, nothing on a brewmaster, and nothing at all before a
  specialization is chosen. `/uuf dev check` names the spec for exactly that
  reason: measured on a level 3 monk it answered `0 of 10 pips`, which is
  correct and looks like a fault until the spec is named beside it. That
  character reports **index 5**, which is none of the three monk specs, and
  `C_SpecializationInfo.GetSpecializationInfo(5)` answers for it with an id
  and an **empty name** rather than nothing at all — so a nil check alone
  prints a blank and calls it a specialization.
- `oUF:Factory(func)` runs at `PLAYER_LOGIN`, `frame:UpdateTags()` forces a tag
  refresh, and `oUF.objects` lists every frame.
- The addon metadata namespace is `C_AddOns`, plural.

### The rest of the single frames

Target-of-target and the boss column, which cost almost nothing once the pet
frame's pattern exists: a config in `Umbra.frames`, a point in each set, and
oUF does the rest. What each one is for decided how it was cut.

**There was a focus frame and it was taken out again**, on 20 September 2026,
because the person it was built for does not use `/focus` and a frame that
never fills is a frame in the way. It cost a config entry and a point per set,
and it would cost the same to put back — so this is written down rather than
kept, which is the cheaper of the two.

- **Target-of-target** is one question — is it on the tank or on me — and is
  cut like the pet in every way, including where it lives: the shared width so
  it lines up, shorter, no castbar, no auras, and a place in the target's own
  stack rather than a position of its own. Since 12 November 2026 the pet
  carries a level as well, where the setting puts the player's — a hunter's
  pet levels on its own — and the target-of-target still carries none.
- **The boss frames** keep a castbar, which is the most useful line on a boss,
  and carry no aura rows: five stacked frames with rows between them would be
  a wall.

**How many boss frames is the client's question**, not ours.
`MAX_BOSS_FRAMES` has changed between expansions, and a number written here
would be wrong in whichever direction hurts — too few leaves a boss unshown,
too many spawns a frame for a unit that can never exist. They are identical to
each other on purpose: an encounter shows between one and five, and a frame
differing from its neighbours in anything but its unit would be claiming
something about that boss that nothing here knows.

**oUF wires all three by itself, differently each time.** `targettarget`
matches `%w+target` and is handed to `HandleEventlessUnit`, which drives it
from a half-second timer because no event announces it, and `boss%d` gets
`INSTANCE_ENCOUNTER_ENGAGE_UNIT` and `UNIT_TARGETABLE_CHANGED`. Nothing about
that had to be asked for — which is also why a focus frame would cost nothing
but its config: `HandleUnit` has `PLAYER_FOCUS_CHANGED` waiting for it.

Where they go is a set decision, and the two sets answer it differently
because they are anchored to different things:

| | classic | modern |
| :--- | :--- | :--- |
| Target-of-target | above the target | above the target |
| Bosses | right edge, centred | right edge, centred |

In `classic` the target has nothing above it — both its aura rows hang below —
so the small frame belonging to the big one sits directly over it, exactly as
the pet sits over the player, and by the same two units of gap. There is no
room to the *left* of anything in that set, because it is anchored into the
corner, so the only outside it has is further right.

In `modern` the target already has buffs above it, and the first attempt read
that crowding as a rule and put the small frame beside instead. It belongs
over the frame it speaks for, the way the pet belongs under the player — so
it became an entry in the target's `above` stack, nearest the frame, and the
buff row is pushed up by exactly its height. Neither can land on the other,
and both positions follow from one count rather than from two numbers kept
equal by hand.

The boss column is the same in both, because an encounter frame is not part of
the arrangement you chose — it is something the fight brings with it, and it
belongs where nothing of yours is. Its step is each frame's whole reach, box
and castbar, asked rather than written down, so a boss frame that grows takes
its neighbours down with it instead of landing on them.

**It is centred on that edge rather than hung from the top**, which is where
it started only because 200 was an easy number to write — and 200 down from
the top right is where the quest tracker already lives. The whole block is
centred rather than its first frame, so an encounter with one boss and one
with five sit in the same place on screen.

**A frame a set does not name is now survivable.** `AnchorFrame` unpacked that
point straight into `SetPoint`, which on a missing entry would have thrown at
`PLAYER_LOGIN`, in the middle of building every frame, and taken the rest of
the build with it. It reports and parks the frame in the middle instead. The
fault would be in `Core/Defaults.lua` either way; what changed is that the
other nine frames still get built.

### Resting, in the corner of the portrait

The client's own player frame shows Z's rising out of the portrait while you
stand in an inn or a city, and Umbra showed nothing. Asked for on 12
November 2026, with a screenshot of each from a Forever tavern: the client's
frame with the Z's, and Umbra's in the same place without them.

**The Z's stay inside the portrait column**, in a 20-unit square
(`restSize`) in its top right corner. Blizzard's rise past the frame's top
edge, and above that edge stand the buffs in `modern` and the pet in
`classic` — a mockup on the real screenshot put the client's Z's straight
across the second buff. Reaching past the box would have meant an entry in
the stack, and with it the buff row 14 units higher all the time, resting or
not. The square is a level above the 2D stand-in, the plate's level: the
plate stands on the column's foot and the square hangs from its top, so the
two share no pixels.

**The art is the client's own**, as the role marker's is. Retail and
Forever animate `UI-HUD-UnitFrame-Player-Rest-Flipbook` in
`Mainline/PlayerFrame.xml`: a `FlipBook` of 7 rows by 6 columns, 42 frames,
1.5 seconds, looping, on a 30-unit texture in a 20-unit frame. The Classic
clients' frame shows a still icon instead, `UI-StateIcon` cut at `0, 0.5, 0,
0.421875`. The UI source of Mists, Anniversary and Era never names the
flipbook atlas, which settles nothing about their data, and no Blizzard Lua
on any client builds a `FlipBook` animation from Lua — Blizzard only ever
declares them in XML. So both are asked rather than assumed: the atlas with
`Umbra.AtlasKnown`, the animation under `pcall` and checked for the methods
it needs and for the texture it is aimed at. A flipbook atlas without its
animation is the whole sheet of 42 frames at once, so the two go together:
either fails and the square shows the still icon, and says why in `/uuf dev
debug` and `/uuf dev check`.

Asked in the game on 13 November 2026: the atlas is in Retail's and
Forever's data and the animation builds from Lua on both, and it is in
neither Mists', the Anniversary realms' nor Classic Era's, which show the
still icon — see *Waiting to be looked at*, item 5.

**Out of a fight, which is Forever's order and not Retail's.** Retail and
the Classic clients ask whether you are resting before they ask about
combat, so their Z's keep going in a city fight; Forever asks about combat
first. Forever has two signals for it — auto-attack, kept from
`PLAYER_ENTER_COMBAT`, and the hate list, kept from `PLAYER_REGEN_DISABLED`
— and only the second is followed here. Swinging at something puts you on
its hate list a moment later, and a flag kept by events alone goes stale on
the one that is missed, since oUF only hands a frame its events while it is
visible. The two regen events are read by their names; every other update
asks `UnitAffectingCombat`, because whether the client already answers true
inside `PLAYER_REGEN_DISABLED` has not been measured here. Neither
`IsResting` nor `UnitAffectingCombat` carries a secret marker in the
documentation, and both are read the way a hidden answer would have to be
anyway.

oUF's own `RestingIndicator` was not used: it knows `PLAYER_UPDATE_RESTING`
and nothing else, and an override skips its callbacks. `UmbraRest` is a
custom element like `UmbraRole`, with all three events registered unitless
— oUF asserts on a non-unit event registered for a unit.

### A hunter's pet says how it is

Asked for the same day: the client's pet frame on Forever carries a face
beside it — green and laughing, yellow and flat, red and frowning — that says
whether the pet is happy, content or unhappy, and with that whether it wants
feeding. Content is the time to feed it; unhappy, it loses loyalty and does
less damage.

**It is told in color and in words.** The pet frame's edge and the
portrait's ground behind the model take the mood's color — `petMood`, a
muted green, yellow and red — the edge at full strength and the ground at
`moodTintAlpha`, 0.45, where the unit's color otherwise lies at 0.13. The
model itself is never covered, as on every portrait since the veil over the
faces went on 8 November. Pointing at the frame shows the unit's lines as
always and, under them after an empty line, Blizzard's lines for the mood:
how it is, in white as the client titles it, then the damage it does for
it, whether its loyalty is rising or falling, and what it eats.

**The edge is the one place a principle gives way.** *Class color at the
edge* means the unit's color, which for your own pet is the reaction color:
the same green on every pet, always, and so no information at all. On a
hunter's pet frame with a mood to tell, the edge carries the mood instead;
everywhere else, and on that frame the moment there is no mood — a vehicle,
a client answering nothing — it is the unit's color as before. With no pet
at all there is no unit color to go back to, so the frame the mood was on
gets the placeholder it was built with, as a theme switch does; unlocking is
where that empty frame shows. The health bar is untouched either way.

It took three tries, all on 12 November 2026, off screenshots of the same
pet. A face at the end of the name row, inside the box at the row's height —
11 units, the role marker's size — and the client's own face, 24 by 23,
beside the frame with its own tooltip and a reach the mover had to be told
about, were both built and seen in the game, and neither looked right on
Umbra's frames. The tooltip alone came next, and then a mockup on the real
frame of four ways to color it — the ground behind the model, a veil over
the whole portrait, a ring around it, the edge alone — of which the ground
and the edge were chosen together.

**Repainted on the mood's own events.** The colors go on in
`UpdateIdentity`, through `umbraPaintMood`, so a new pet, a theme switch and
`/uuf health` all reach them as they reach the unit's color. A change of
mood alone arrives as `UNIT_HAPPINESS`, taken unitless as Blizzard takes it —
its code never reads which unit the event names — and `PET_UI_UPDATE`, which
the Classic pet frame refreshes on too. The event is the reason the client
is asked whether it has one before anything is built: Retail has none, and
registering it there is an error report on every login.

**Three clients have it, in two ways**, measured against the UI source of
all five on 12 November 2026:

| | the mood | what it eats |
| :--- | :--- | :--- |
| Forever | `C_PetInfo.GetPetHappiness` | `C_PetInfo.GetPetFoodTypes`, a table |
| Anniversary, Classic Era | `GetPetHappiness` | `GetPetFoodTypes`, one word per return value |
| Mists | `GetPetHappiness`, which answers nothing since Cataclysm | `GetPetFoodTypes`, one word per return value |
| Retail | — | — |

The globals on the Classic clients are undocumented: Blizzard's pet frame
calls `GetPetHappiness`, and its pet paper doll and stable call
`GetPetFoodTypes` — the Classic pet frame's own tooltip has no diet line, so
the one here follows Forever's. Colors and lines are only for a hunter, whose
pet is the only one with a mood; `HasPetUI`'s second answer tells a hunter's
pet from a demon at runtime, as it does for Blizzard.

**Mists is left out by name**, the one place this feature asks for a client
rather than for a function. It has the global and the event and answers
nothing, since a pet's mood went in Cataclysm; Blizzard's own Mists pet
frame still calls it and hides its face on the nil. Left out, the pet frame
there is exactly what it was.

**Kept in the tooltip while it is open.** On Retail and Forever the client
rebuilds a unit tooltip from its data every so often and drops lines added
to it, unless the owner has an `UpdateTooltip`, which it then calls instead —
which is how Blizzard's unit frames keep theirs. So the pet frame of a hunter
sets one, `FillTooltip`, which fills the tooltip again with the unit's lines
and the mood's, and the mood follows while the pointer rests on the frame.
Every other frame leaves it unset. The words are the client's globals —
`PET_HAPPINESS1` to `3`, `PET_DAMAGE_PERCENTAGE`, `GAINING_LOYALTY`,
`LOSING_LOYALTY`, `PET_DIET_TEMPLATE` — so they read in the client's language
with no translation here; the diet is joined with `PET_FOOD_DELIMIT` where
there is one and `LIST_DELIMITER` where not.

oUF's own `Happiness` element is gated on Forever and stays unused, and so
does its `colorHappiness`, which would paint the health bar: the bar belongs
to health.

### Range fading belongs to the group frames

The sixth principle, and it cannot be built on the frames that exist today.

**oUF's `Range` element fades only party members.** It asks
`UnitIsConnected(unit) and UnitInParty(unit)` and, for anything that fails
that, simply sets `insideAlpha` and returns. On a target, a pet or a focus it
is not a no-op by accident but by construction, because `UnitInRange` itself
only answers for units in your party or raid — for anyone else the client has
no distance to give an addon.

Range to an arbitrary unit therefore has to be asked a different way:
`C_Spell.IsSpellInRange` against a spell the character actually has, which
means a per-class table of one harmful and one helpful spell, kept current
across expansions. That is a real piece of work and a real maintenance
burden, and it buys the least on exactly the frames it would be built for —
you can see your own target.

So this waits for the group header rather than being half-built now.
`Umbra.metrics.rangeAlpha` is already there, unused on purpose, and the raid
is where fading earns its place: twenty frames where the ones you cannot
reach should step back without being hidden.

### Auras

`SecureAuraHeaderTemplate` has been removed. Auras go through
`CreateFrame('AuraContainer')` with `AuraGroup`s that create their own buttons.
Inside instances the container and its buttons gain forbidden aspects, and the
`initializeFrame` callback runs before that takes effect.

One AuraGroup per dispel type was the obvious way to get a colored underline,
and it would have meant ordering auras across groups. It is not needed.
**`AuraButton:AddDispelTypeTexture(texture, options)` colors one of our own
textures by the aura's dispel type**, so the color never passes through us —
which is the whole difficulty, since aura data is hidden inside instances.
`options.style` decides what art the client puts on the texture, and
`Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset` keeps ours.
`options.customDispelColorMap` takes a table of colors; oUF fills
`oUF.colors.dispel` from `AuraUtil.GetDebuffDisplayInfoTable()`.

What the client does to a registered texture when the aura has **no** dispel
type is not established. `showWithoutDispelType` makes it visible in that case,
but nothing says the color is left alone. So each button carries two lines on
the same rectangle: ours underneath, always visible, and a registered one above
it with `showWithoutDispelType` off, which appears only when there is something
to dispel.

The row cannot overflow the space reserved for it, because `maxFrameCount` and
`AuraBlockHeight` are handed the same count: more auras than that are not
created rather than wrapping into a row nothing made room for. Raising the
count raises the reserved block, and everything under it moves down with it.
`Umbra:AuraPerRow` is the one place that answers how many fit. This paragraph
claimed 8 at a width of 210 for a while, left over from when the icon was 22
wide, while two others correctly said 7; the width now follows the row rather
than the row the width, so both are 8 again and by construction.

**The client counts a row differently, and that cost an icon.** Measured in
*Thron der Gezeiten* on 20 September 2026: seven real buffs in a block
reserved for eight, while `/uuf dev test` had been showing eight all along. The
preview proved nothing here and said so — it packs its stand-ins with
`AuraPerRow`, and the client packs the real row itself.

`layoutLimit` reaches `SetFlowLayoutMaximumLineSize`, which is a width in
pixels, and the client fills a line by adding each button *together with its
spacing* until the next one would not fit. So it asks for `n · (icon +
spacing)` — 8 · 28 = 224 — where the frame is `n · icon + (n - 1) · spacing`
= 222 wide, the same row without the gap after the last icon, which nothing
draws. Handed the frame width, eight needed 224 against a limit of 222, seven
fitted, and the eighth wrapped into the next line.

`Umbra:AuraRowLimit` answers the client's question in the client's own terms,
and `AuraPerRow` keeps answering ours. The 2 pixels are the whole difference,
and neither side is wrong: one is measuring a row that is drawn, the other a
row that is being filled.

**Confirmed in the client**: eight real buffs in the row afterwards, same
character, same dungeon. That was the one thing about the auras that had
never been looked at with real data — the geometry, the colors and the side
after a switch all had been.

**A full row can be looked at without waiting for one.** `/uuf dev test` fills
every reserved slot with stand-ins, which is the only way to see the case the
arrangement has to survive — every slot taken, on both frames, in both sets.
`Layouts/Preview.lua` re-cuts them through `Umbra.AuraButtonLook`, the same
function that re-cuts a real button, and packs them with `Umbra:AuraPerRow`,
the same arithmetic that reserves the block. So a real row that disagrees with
the preview is a finding about that arithmetic rather than about the preview.

What the stand-ins do not speak for: the icon is a question mark, the
durations are stand-in strings that say nothing about what the client would
print, and the client packs the real rows itself. Their dispel colors are not
invented — they cycle through `oUF.colors.dispel`, which is the very table
handed to `AddDispelTypeTexture`, so the colors are the ones a dispellable
aura really gets and can be compared out in the open world where the real ones
cannot be read.

The cooldown frame draws **its own** countdown text, centered, in a font sized
for Blizzard's icons, so on a small one it overhangs both edges.
`SetHideCountdownNumbers(true)` turns it off; the duration then comes from
oUF's `showDuration`, whose `Time` label Umbra re-fonts and re-anchors. Both
labels can anchor to the button's own corners, because the button is exactly as
wide as the icon.

**The icon border grows inwards.** Hung outside the button it put the visible
left edge of the whole aura block one unit left of the frame's own edge —
measured off a screenshot at 31 against 37 in a threefold zoom, so two
physical pixels. The icons themselves were flush the whole time; it was the
border that was not. The backdrop now fills the button and the spell art is
inset by one, which keeps the border and leaves the block's edge on the
frame's edge.

**The right edge lines up too, since the width follows the row.** It did not
before: at a frame width of 210 the row came to 194 and, being left-aligned,
left all 16 of the difference on the right. That was measured on 20 September
2026 off a screenshot at a UI scale of 1.4048 — the block ran x 7..279 against
frame edges at 6.8 and 301.8, so flush on the left and 21.8 pixels short on
the right, which is those 16 units exactly, on both frames.

Rather than shrink the icon back towards the size the duration label already
refused, the frame took the width of the row: `8 · 26 + 7 · 2 = 222`. The name
column gained the 12 units, the reserved block heights did not move, and the
aura counts became whole rows of eight.

`Label` clears the anchor oUF already set before placing the label. A second
point on a font string stretches it rather than moving it, which is what made
the duration look left-aligned when it was in fact centered.

**The icon size is set by the duration label, not the other way round.** At 22
the label measured 39 pixels wide against a 42 pixel icon, filling it edge to
edge, and two neighbouring labels read as one run of text. Both numbers came
off a screenshot; the label was centered to within half a pixel, so the fix was
width, not position. 26 with an 11 point font leaves margin, and eight of
them are what the frame width is now cut from.

That was enough on its own: measured again at 26, the label is 31 pixels on a
36 pixel icon, centered to within half a pixel.

**It was not enough for a two-digit minute, in any of the client's words.**
On a German Forever client, measured on 7 November 2026 off a lossless
screenshot at 1.3125 pixels per unit, the client wrote `25 min` and `40 min`:
45 pixels each on a 34 pixel icon, neighbours overlapping by 7 to 10 pixels
and the first label hanging 6 pixels over the frame's left edge. The `min` is
the locale's `MINUTE_ONELETTER_ABBR`: `%d min` on German Forever and on
Portuguese clients everywhere, `%d m` in English and in German on Retail, a
word of its own in Russian, Korean and Traditional Chinese. And `24 m`, the
shortest of them, measures 36 at this size in the client's Friz Quadrata — a
pixel over each edge of the icon, and clear of the next label only because the
pitch is 36.75. So whatever the 31 pixels above caught, it was not a
two-digit minute. The size held; the words did not — see the format below.

**The duration sits in the middle of the icon square, not of the button.** The
button is taller than the icon by the gap and the line, so anchoring the label
to the button's own centre puts it low, and anchoring it to the top puts it in
the top quarter — measured at y 11..18 against an icon spanning y 6..42, which
is 9.5 pixels too high. The offset is written out from the icon's own size.

**The duration format is ours, on the second attempt.** This paragraph said
*leave the duration format alone* until 7 November 2026. The first attempt to
shorten `24 m` to `24m` through `CreateSecondsFormatter` was reverted: the
function is not a global on Retail 120100, and the namespaced one took
different arguments than assumed, so the same label came back as `9 Minuten 46
Sekunden`. The client's own default was taken to fit the icon then, and
guessing at the signature cost two reloads. The paragraph ended on *any second attempt starts
by reading the client's own callers, not by trying argument orders* — and the
German Forever client above is why there is a second one.

What was read, on the `live` and `forever` branches, which are identical here:

- `Blizzard_CustomAuraButton.lua`: `SetDurationText(fontString, options)` is
  Lua in a secure addon. It gives each button a `DurationTextBinding` that
  samples the aura's duration itself, and takes `options.textFormatter` — a
  `NumericFormatter` — or `options.textFormat`. oUF passes
  `element.durationFormatter` through as the first. oUF's own documentation
  calls `durationFormat` a string; the client wants a table there.
- `Blizzard_AuraContainerShared.lua`: the default is a `SecondsFormatter` with
  one-letter abbreviations, which is where the locale's `min` comes from. No
  setting of a `SecondsFormatter` replaces that word, and German keeps the
  space unless the formatter is told to ignore the locale — `25min` is still
  44 pixels.
- `C_StringUtil.CreateNumericRuleFormatter()` takes no arguments and is
  configured by `SetBreakpoints`: a threshold, a printf-style format and an
  optional division per rule. No Blizzard code uses one; oUF's author and
  RealUI hand one to `SetDurationText`.

So `Layouts/Auras.lua` builds a `NumericRuleFormatter` that words the time as
the own rows do — `8s`, `25m`, `2h`, `3d`, seconds rounded down and every
larger unit up — and hands it to oUF. The value never passes through Lua: the
client applies the rules to a duration that may be secret, and writes into a
label whose text is a secret aspect. **Before it is used, it is tested**: at
load time it has to word six plain numbers as a count and the right letter,
within one of what `Remaining()` prints. A refusal or a wrong answer leaves the
client's default in place, `/uuf dev check` reports `aura duration format:
the client's`, and `/uuf dev debug` has the answer that failed it.

Measured with the client's own Friz Quadrata at this size: `49m` is 32 pixels
including the shadow, on a 34 pixel icon, and every two-digit count is as wide
as every other because the digits are. `24 m` with the space — the client's
English word and the old own-row format alike — is the 36 pixels above.

oUF's default `CreateButton` builds icon, cooldown, count and duration through
the aura-button API, and is worth keeping. Umbra only re-cuts it in
`PostCreateButton`: the button is taller than it is wide, so the icon, the
cooldown and the count are pinned to the square at the top and the line sits in
the strip below. Metrics reach that callback on the element rather than in the
group options, because the options table goes on to the client and is typed.

### Output that outgrew the chat frame

`/uuf dev check` answers around thirty lines now, and a chat frame is the wrong
place to read them: everything else is pushed out of view, and the answers
have to be held against each other rather than watched scrolling past. It
opens a window instead, `Core/Report.lua`.

The text in it is **plain**. The colors existed to be glanced at in chat;
these lines are meant to be selected and pasted somewhere else, and an escape
code in a pasted report is noise. What decides a value is its word — `hidden`,
`readable`, `nil` — never its color. The report also carries its own first
line, naming the build and the client, because pasted anywhere else it has no
other context.

**No addon can reach the clipboard**, so the window does not pretend to. The
button selects the whole report and focuses it, and Ctrl+C is the part the
game leaves to the person; the button says so rather than being called Copy
and doing half of that.

**A slash command runs inside the chat edit box's own Enter handling.** That
is the single most important thing this window taught, and it was learned by
breaking the client. `EditBox:SetFont` wants a third argument where a
FontString does not; `Build` threw on it; and an error thrown out of a slash
command does not merely fail — it takes `SendText` down with it. The typed
text stays in the box and the key looks broken, which from the outside is
indistinguishable from a dead keyboard. The way out, `/reload`, is also typed,
so the client had to be restarted and the repair installed from outside the
game.

Two things follow, and neither is about fonts:

- **The window is optional and chat is the floor.** `Build` is called through
  `pcall`, only a window that came back whole is kept, and a report that has
  no window to go in is printed instead. A diagnostic that cannot be shown is
  still worth having.
- **A failed command stops at the command.** The whole `/uuf` handler is
  wrapped, so a fault is caught and named rather than reaching the frame that
  was only trying to send a line of text. It still reaches error capture; it
  no longer reaches the chat frame.

The first diagnosis of this was wrong twice over — a focus that was never
stuck, then a retry that could not have run — and what settled it was not
reasoning but `!BugGrabber.lua` on disk, which had the file, the line and the
whole stack the entire time. **Read the error log before theorising.**

**A focused edit box that is hidden keeps the keyboard.** The select-all
button focuses it, and the first version did not let go on the way out: Enter
went on reaching a field nobody could see, so chat accepted nothing at all —
including the `/reload` that would have escaped it. Hiding now clears the
focus whichever way the window was closed, Enter and Escape both let go, and
because the box is multiline, Enter would otherwise have typed a newline into
the report rather than returning to chat.

It stays an EditBox because selecting text is the only copying the game
offers, so typing into it is undone rather than prevented, with the selection
put back where it was.

**The lesson outlived the bug.** A diagnostic reachable only by typing is
unreachable in exactly the case where typing has stopped working, and that is
the case it is most wanted in. So `Bindings.xml` offers the report as a key
binding as well — the client picks that file up from the addon folder without
a TOC entry, and Blizzard key binding panel is worked with the mouse.

**It wears the client's own furniture.** A panel that looks like the rest of
the interface is one less thing to work out, so the border, the title bar, the
close button, the sunken body, the scroll bar and the button all come from
Blizzard's templates — `BasicFrameTemplateWithInset` and its neighbours. Each
is asked for through `pcall` with something plain built here if it is missing,
because a missing template throws rather than answering nil and Forever is
missing parts of the Retail surface. The title is set through whichever of
`SetTitle`, `TitleText` and `TitleContainer.TitleText` that client has, which
are three names for one thing across versions.

The frame carries no unit data — it is handed strings that were formatted
before it existed — so the geometry rule has nothing to say about it, and its
widgets may size themselves however they like. Both the close button and the
scroll frame are taken from the client's templates through `pcall`, with a
plain one built here if the template is missing, which is the same care every
other client-supplied thing in this addon gets.

### The client keeps a hostile unit's model to itself

**Settled.** A target's 3D portrait is empty inside a dungeon and filled in the
open world, on the same character against the same kind of unit. Measured in
*Der Steinerne Kern* on 20 September 2026:

```
portrait target: UnitIsConnected: readable — true
portrait target: UnitIsVisible:   readable — true
portrait target: ready:           readable — true
portrait target: model:        readable — nil
portrait player: model:           readable — 878772
portrait pet:    model:           readable — 1266661
```

`ready` true with no model is the answer: the client has no work left to do and
has still assigned nothing. It is not late, it is withheld — which is why a
retry could never have helped, whatever it had been gated on.

**`display info` was not evidence, and this file claimed it was.** It reads 0
on the target, and a later run showed it reads 0 on the player and on the pet
as well, whose models load. It is simply not what `SetUnit` fills in. What
carries the finding is `GetModelFileID` — a number on the two units that are
yours, nil on the one that is not — together with the same kind of target
having a model out in the open world.

This **is** the restricted-value regime, and saying it was not — which these
notes did, on the strength of two conditions coming back in the clear — was
reading the regime too narrowly. It does not only hand back opaque numbers; it
also declines. What a creature looks like *is* its identity, and identity is
what the client holds back about a hostile unit inside an instance. The three
frames line up exactly with that: the player is yours, the pet is yours, and
the target is not.

That also disposes of the guesses made along the way, and they are worth
keeping because each was reasonable and wrong:

- **Not the column.** One style builds all three frames.
- **Not player versus creature.** The pet is a creature and loads.
- **Not streaming.** A bounded retry was written for that reading and changed
  nothing — and worse, it was gated on `IsUnitModelReadyForUI`, an API nobody
  had measured, so the first attempt could not even have run. A gate on an
  unmeasured assumption in front of a measurement is the exact mistake this
  file exists to prevent, committed while chasing it.
- **And `display info` proved nothing**, though it was read as proof for a
  while. Two wrong readings off one run, both from taking a number for an
  answer without first checking what it says on the cases that work.

Nothing here can fix a client that declines, so the column stops being empty
instead. `SetPortraitTexture` — Blizzard's own 2D portrait, asked for the same
unit — is laid **over** the model rather than swapped for it, because a hidden
PlayerModel does not load and hiding it would cost the real model its chance
to turn up. The stand-in goes up the moment there is nothing to show and comes
down the moment there is, so a target in the open world is 3D and one in a
dungeon is 2D, without either case knowing about the other.

The bounded retry stays, and now has an honest job: a model that really is
still streaming upgrades the column from 2D to 3D instead of the column
sitting empty while it waits. `/uuf dev check` reports which of the two is
showing.

**It holds in a delve too**, measured on 21 September 2026 on the same
character within minutes: `model: readable — 1100258` and `showing 3D model`
outside, `model: readable — nil` and `showing 2D stand-in` on a target inside.
A delve is solo and has no encounter, so whatever withholds the model is not
waiting for a group or a boss fight — the instance is enough.

**But the instance is not the condition.** Patch 12.0.5's API notes name it
outright: `Model:SetUnit` and `ModelSceneActor:SetModelByUnit` no longer accept
a unit token for a unit whose identity is secret, and they do not throw — they
hand back nil where they used to hand back success. An instance is a place
where that condition is met, not the thing being tested. Every sentence above
that reads *inside an instance* should be read as *where identity is secret*,
and the measurements still stand — they were the right readings of a narrower
question than the one being answered.

**Settled by measurement, both directions, on 21 September 2026** — Retail
120100, the same character minutes apart, so that only the place changed:

```
                              open world             inside
target:       identity     in the clear           secret
target:       model        readable — 6253063     readable — nil
target:       showing      3D model               2D stand-in
targettarget: identity     in the clear           secret
targettarget: model        readable — 878772      readable — nil
targettarget: showing      3D model               2D stand-in
player:       identity     in the clear           in the clear
player:       model        readable — 878772      readable — 878772
pet:          identity     in the clear           in the clear
pet:          model        readable — 1266661     readable — 1266661
party1:       identity     —                      in the clear
party1:       model        —                      readable — 3049179
```

Identity and model move together in every row, and nothing else moves at all:
`ready` is true in all twelve, `UnitIsVisible` and `UnitIsConnected` are true
in all twelve, and `display info` is 0 in all twelve. The column is 2D exactly
where the client will not say who it is looking at.

**The party member settles the wider claim inside a single run.** Brann is a
creature, in an instance, in the same report as a target with no model — and
he is in the clear and his model loads. So the instance is not what withholds
anything. Being neither yours nor your group's is.

So the retry is now gated on it, in `PortraitPostUpdate`: a secret identity
puts the stand-in up and stops there, because eight tries over four seconds at
a question already answered is four seconds of asking a client that has
refused. A model missing from a unit in the clear still starts the chain,
which is the case the chain was written for.

**The open world half of the report is not reproduced, and the obvious
explanations are now used up.** The column was seen 2D on the target and the
target-of-target outside an instance, which is what started all of this.
Three runs outside since say otherwise, and the third was aimed at the gap the
first two left — a target-of-target that is somebody else:

```
targettarget: identity  in the clear
targettarget: model     readable — 4207724
targettarget: is player readable — true
targettarget: same as player: readable — false
```

A foreign player, out in the open world, in the clear with a model. So it is
not "a unit that is not yours" either: outside, a creature and another player
both load. Whatever produced the sighting is narrower than anything measured
here, and a report cannot be run backwards over it — `/uuf dev check` has to
be typed while the 2D column is on screen. The identity line will name it in
one go when it is.

Until then this section describes instances, which is where it has been
measured.

**Issue #1's contradiction turned up again**, on the target-of-target inside,
and this time without a delve:

```
targettarget: may compare with player: readable — true
targettarget: same as player:          hidden
```

Permission granted, answer withheld, on exactly the pair that threw 716 times
— so the guard under *Permission to compare two units is not an answer* is
standing on a condition that still occurs, rather than on one delve.

**Two different frames answered to `party1`, and now they say which they are.**
The header's child and the hidden party stand-in both point at the unit, and
with the token for a name they printed the same label over different answers.
Named, the pair reads correctly:

```
UmbraPartyHeaderUnitButton1: model readable — 3049179 · showing 3D model
UmbraPartyStandIn1:          model readable — nil     · showing 3D model
```

The stand-in's empty answer is itself right: a hidden `PlayerModel` does not
load, so it reports a missing model for as long as it stays hidden. That is
the second gate in `PortraitPostUpdate` — without it the four locked stand-ins
each started a retry chain that could not end any other way. It also explains
the `showing 3D model` next to a missing one: nothing covers a frame nobody
can see.

Whether the client declines `SetPortraitTexture` for the same unit it declined
a model for was the open question here, and the portrait box answered it on 22
September 2026: **it does not.** The stand-in gets the unit's own face, not a
question mark — see *A refused model is not an empty one*.

### Placing a frame is the client's business in a fight

**Found in an error log rather than in use**, 22 September 2026, on Retail:

```
[ADDON_ACTION_BLOCKED] AddOn 'UmbraUnitFrames' tried to call the protected
function 'UmbraBoss5Frame:SetClampRectInsets()'
  Core/Mover.lua:73  AnchorFrame
  Core/Mover.lua     ApplyLayout ← ResetPositions ← /uuf reset
```

Not an error and not a throw: a refusal, and one that taints the path it was
called on. Every frame Umbra places is a secure unit button, so the insets
that keep a frame's aura rows on screen cannot be set while a fight is on.
`/uuf unlock` has always refused in combat and `Reveal` has always waited for
`PLAYER_REGEN_ENABLED`; placing went through both of their doors without
either guard, because it runs at login where there is no combat and nobody
had typed `/uuf reset` mid-fight until then.

So `ApplyLayout` now answers false in combat and finishes at
`PLAYER_REGEN_ENABLED`, beside the pending reveal — a frame is placed before
it is shown, so the layout goes first. `/uuf reset` and `/uuf layout` say
which of the two happened rather than reporting a move that did not take.

One thing nearly went wrong in the writing of it: `local pendingLayout`
started out declared next to the function that sets it, which is *after* the
function that reads it — and a local declared after its first use is a global,
silently, with the two halves then talking past each other.

### A file id is not a drawn model

**Open, and the instrument for it is built and has been run.** The box works
and has already settled two other things — see *A refused model is not an
empty one* — but the run that produced it was inside a dungeon, where the
target's identity is secret and the file id is nil, which is the case that
already works. **The case below is still unreproduced in the box: a unit in
the open world, identity in the clear, a file id in hand, and an empty
square.** On Retail 120100 on 22 September 2026, in the open world in *Der Altar des Zorns*, a hostile target answered
`/uuf dev check` with everything that is supposed to mean a portrait:

```
portrait target: identity — in the clear
portrait target: model:        readable — 124639
portrait target: ready:        readable — true
portrait target: showing 3D model
```

and the column was empty. Measured off the screenshot, 2000 px wide: the
target's portrait square holds **53 distinct colors across 1680 pixels, 1183
of them the same one** — the ground with the reaction tint over it and
nothing standing on them. The player's square in the same picture holds 1732
distinct colors in 1920, the pet's 673 in 1120. The ground and the tint are
both there, so nothing about the column is misplaced or unpainted; what is
missing is the model.

Three things that report were **not** saying, each of which had been read out
of it:

- **`showing 3D model` was not "a model is drawn".** It reported which of the
  two layers was uncovered, which is all it ever claimed — and with the 2D
  stand-in down, that is the only thing it could report. An empty 3D layer
  and a full one read the same. The line now says `2D stand-in down, the
  square is the model's`, which is the thing that was measured.
- **A file id is not a drawn model either.** `GetModelFileID` answered a
  number here, and `ModelPending` treats a number as "there is nothing to
  wait for". That was written when the two known states were *a model* and
  *nil*, and this is a third.
- **"no 2D model either" is not a refusal.** The stand-in is only ever raised
  where the file is nil, so on this unit `SetPortraitTexture` was never
  asked. Whether the client would have given a face is unmeasured.

What the id is not: oUF's own fallback. Its unavailable branch loads
`Interface\Buttons\TalkToMeQuestionMark.m2`, which the community listfile
gives as 130738 — from wago.tools rather than from this client, so it is a
pointer and not a measurement, but 124639 is not it. oUF took the `SetUnit`
branch, as its two conditions coming back readable and true already said.

The explanations still standing, none of them separable from the outside:

1. **The client built no model for this unit.** The target was one of the
   ruin's fallen hunters, up the hill and a long way off; a unit the world is
   not drawing may have nothing for the UI to borrow, while its display is
   still named.
2. **The model is framed out of the square.** `SetPortraitZoom(1)` uses the
   portrait camera the model file carries, and an old creature file whose
   camera is missing or degenerate would render off-view rather than nothing
   at all.
3. **The file has no geometry to draw**, whatever it is named. **This is the
   standing reading**, and it is a reading rather than a measurement: an old
   creature file that the client will name and cannot picture is not a fault
   in the column, and nothing in the addon could have done better with it.
   The *file alone* square settles it in one screenshot the next time anyone
   is standing in front of such a unit.
4. **The model is there and nearly invisible** — a ghost or otherwise
   translucent unit. The screenshot arrives here as lossy WebP, which would
   flatten a very faint model into the uniform block that was measured. The
   variance carries the finding; the colors do not.

### `/uuf dev portrait`, four attempts in one picture

Nothing the client hands over says whether the column drew anything, so this
measurement does not end in words: it opens a box and draws. One row per
unit, four squares each, side by side.

| | |
| :--- | :--- |
| as drawn | the portrait camera and the unit — exactly what the column does |
| whole model | the model's own camera, which brings a body framed outside the square into view if that is where it is |
| file alone | the file the live element holds, loaded with no unit behind it — geometry the client owns, told apart from a unit it will not build one for |
| 2D | `SetPortraitTexture` for the same unit, on a texture cleared first, so what comes back is the client's answer and not the last unit's face |

Read against the four explanations above: *whole model* settles 2, *file
alone* settles 3, and together they settle 1 — a file that draws on its own
while the unit draws nothing leaves only the unit. *2D* settles what the
other half of the column would do, and is the one square that is also a
repair: if the client hands over a portrait for the unit whose model it will
not build, the stand-in belongs there, and the gate that raises it needs a
better question than a nil file id.

**The target is the question; the player and the pet are the controls.** Two
units whose models are known to load, in the same picture, on the same
client, at the same moment. A row that is empty in all four squares is worth
something only next to a row that is not — and a row for a unit that is not
there says so rather than being left out, because a box that quietly shows
two rows instead of three is a box that has to be counted.

The squares are live `PlayerModel`s, not pictures of one: they ask the client
the same four questions the frames ask, and the screenshot of them is the
report. Each caption is read twice, now and a third of a second later,
because `GetModelFileID` can answer nil in the frame the unit was set in and
a caption saying `holds nothing` under a square that fills a moment later
would be this file's own mistake made again.

Two things came out of building it. The window furniture — border, title bar,
close button, sunken body, each from the client's templates with a plain one
built where they are missing — is now `Panel` in `Core/Report.lua` and serves
both windows. And `/uuf dev check` lost the wording that started this:
`showing 3D model` now reads `2D stand-in down, the square is the model's`,
which is what it measures.

### A refused model is not an empty one — it is you

**Settled, and it was not what anyone was looking for.** The first run of the
box, in *Das Verlies* on 22 September 2026, inside with a party, on a target
whose identity is secret:

```
target — name hidden      identity secret · no file · ready true
  as drawn     holds 878772      a dwarf
  whole model  holds 878772      the same dwarf, whole
  file alone   no file           empty
  2D           gave RTPortrait1  a masked human rogue
player — Donnerbüchse     identity in the clear · file 878772 · ready true
  as drawn     holds 878772      the same dwarf
```

`878772` is the player's own file, and the dwarf in the target's squares is
the dwarf who typed the command. So **`SetUnit` on a unit the client will not
name does not leave the model empty; it leaves the player standing in it.**

The control for that claim is in the same picture and was not put there for
it: the target's *file alone* square is a `PlayerModel` that was cleared and
then given nothing at all, because there was no file to give it — and it is
empty. A cleared model with nothing set draws nothing, so the dwarf in the
other two squares came from `SetUnit` itself rather than from the widget
falling back to what it is named after.

What that costs: the 2D stand-in is not a nicety over an empty square, it is
the only thing standing between an enemy frame and a portrait of yourself.
`ModelPending` raises it on a nil file id, which is exactly the shape of this
case — the element holds no file while the square holds the player — so the
column was right here, and the live frame in the same screenshot shows the
rogue's own face. It is the *other* case, a file id over an empty square,
where the cover never comes up.

**`SetPortraitTexture` is not declined where the model was.** That question
was left open under *The client keeps a hostile unit's model to itself*, and
this answers it: the client handed over the target's real portrait —
a masked human rogue, the unit that was standing there — for a unit whose
identity it had just refused to name. The stand-in is a true picture of the
unit, not a question mark, which is worth more than it sounds: the column
keeps its meaning on exactly the units that need it.

Two things to read correctly in that box, both measured and neither a fault:

- **`file alone` draws white.** A character or creature file loaded by id
  comes in without its textures — an untextured mesh, the player as a white
  dwarf and the pet as a white bear. The square answers *is there geometry*,
  and geometry is all it answers.
- **`gave RTPortrait1` is not a file id.** `GetTexture` on a portrait comes
  back with a render-target name, and the same word appears on all three
  units while the three pictures differ. So the caption says a portrait was
  given, and nothing about whose.

### A portrait framed before its model arrived

Seen on Forever on 8 November 2026 at 09:25, off a lossless screenshot: the
player's portrait was a blurred close-up of the armor — yellow cloth and a
red and white emblem — where two minutes earlier it had shown the face. The
debug buffer had just read `portrait missing for player — standing in for it`
and `portrait arrived for player on try 1`. Seen once; nothing since has made
it happen again.

What was read, on all five branches of the client's code and in other unit
frames:

- oUF sets zoom, distance and position, then `ClearModel` and `SetUnit`, once.
  The bundled element is upstream's, and upstream has no report of this.
- Blizzard places its custom cameras in `OnModelLoaded` when a new model is
  set, after the model exists, and the talking head on Retail and Forever
  calls `RefreshCamera` there first. Its model frames call `RefreshCamera` on every
  `UI_SCALE_CHANGED` and `DISPLAY_SIZE_CHANGED`, on all five clients —
  among them the guild news boss model, which sets its portrait zoom once in
  `OnLoad` and leaves the refresh to keep it.
- Shadowed Unit Frames, EllesmereUI and the Forever addon GlassUnitFrames
  frame the portrait after `SetUnit` rather than before it; KullThranUI and
  DialogueUI frame theirs in `OnModelLoaded`.
- A zoom that was simply lost shows the whole figure — what Shadowed Unit
  Frames' own comment and an ElvUI report describe — not a close-up. So the
  picture fits a framing worked out while the model was still streaming in
  better than a lost one. That is a reading, not a measurement.

Three changes follow, and none copies oUF's values:

- `RefreshCamera` when the client says a model has loaded, hooked only where
  the model offers `OnModelLoaded`. The question mark of an unreachable unit
  keeps its own framing, because the refresh works from the settings already
  on the model.
- `RefreshCamera` on every portrait when the UI scale or the resolution
  changes, as Blizzard's model frames do.
- `RetryPortrait` looks before it reloads. It called `ForceUpdate` first, so a
  model that had loaded by itself in the half second was cleared and set
  again. Whether that happened before the bad picture, the old log cannot
  tell: it wrote `on try 1` either way. That case now refreshes the camera,
  lowers the stand-in, and logs `portrait arrived for player on its own,
  before try 1`. A model that turns up only after a try has set it again
  logs `before try 2 — try 1 had set it again` instead: which of the two
  loads arrived, nothing in the retry can tell.

Left out on purpose: zooming again with oUF's numbers after `SetUnit`, which
would copy oUF and frame the question mark as a face, since which branch ran
is private to the element; and `ForceUpdate` from `OnModelLoaded`, which a
load would fire again. `/uuf dev check` counts the loads per portrait,
`models loaded since the last reload`. Blizzard's own code wires
`OnModelLoaded` on the talking head's `PlayerModel` on Retail and Forever and
on the wardrobe's `DressUpModel`s, a kind of `PlayerModel`, there and on
Mists; on the Anniversary realms and Classic Era nothing of Blizzard's uses it.
A count that stays at zero on a client means the hook never ran there, and
only the scale refresh and the retry change apply. On 8 November 2026 it
counted above zero on Forever, the Anniversary realms and Classic Era — see
*Waiting to be looked at*, item 4.

### Permission to compare two units is not an answer

**Settled, and it is a defect in oUF.** Every comparison of two unit tokens in
the library goes through one function:

```lua
function Private.unitIsUnit(unit1, unit2)
	return C_Secrets.CanCompareUnitTokens(unit1, unit2) and UnitIsUnit(unit1, unit2)
end
```

The permission is asked, and then the result is handed straight to a boolean
test at eleven call sites. **The permission can be granted and the answer
still come back hidden.** Measured on Retail on 21 September 2026, inside a
delve — so an instance without a group, which is the cheapest way to reach the
restricted-value regime:

```
Libs/oUF/elements/portrait.lua:48: attempt to perform boolean test on a
secret boolean value (execution tainted by 'UmbraUnitFrames')
  self.__unit = "targettarget"   unit = "player"   count 716
```

The captured stack says which of the two calls did it, and it is worth
spelling out because the two readings lead to different fixes. `UnitIsUnit`
sits in tail position, so a hidden *permission* would have thrown inside the
`and`, named `private.lua:34`, and kept that frame on the stack. Instead the
top of the stack is `portrait.lua:48` with the tail call already collapsed:
permission granted in the clear, answer hidden.

So oUF's guard is not one, and a call site cannot be made safe by asking
nicer. What works is asking the question and looking at what came back —
`Umbra.Secrets.SameUnit`, which answers true, false, or **nil for "the client
will not say"**, needs no `C_Secrets` at all, and therefore behaves the same on
a client that has none.

`/uuf dev check` prints both halves side by side, per frame, and a third run on 21
September 2026 — in a delve, with a creature targeted that had a target of its
own — **measured the contradiction itself**:

```
portrait targettarget: may compare with player: readable — true
portrait targettarget: same as player:          hidden
```

Permission granted in the clear, answer hidden. Exactly what the stack said,
now from the client rather than from a reading of it.

**And the client is not protecting a secret here.** Two lines above, in the
same block, stands `targettarget: is player: readable — false`. If the
target-of-target is not a player, it cannot be the player unit, so the answer
`UnitIsUnit` refuses to give is already deducible from a value the client hands
over in the clear one question earlier. **The refusal is structural on the
shape of the question, not derived from what the answer would reveal.**

That is the finding with the longest reach. It means no amount of reasoning
about *what* ought to be secret will predict which calls are safe, because
this one is not hiding anything. Only asking does — which is what
`Secrets.SameUnit` was built to do, and why oUF's permission check was never
going to be enough.

The two runs before it, the open world and the same delve, settle one half and
narrow the other. The permission is readable in both places:

```
                 open world                      delve
target: may compare with player   readable — true       readable — true
target: same as player            readable — false      readable — false
target: model                     readable — 1100258    readable — nil
target: showing                   3D model              2D stand-in
```

So **the hiding is not a blanket rule for instances.** `target` against
`player` answers in the clear inside a delve, on the same run where the same
target's model is withheld. Whatever is hidden is narrower than "comparisons
under the restricted-value regime".

**The likely shape of it, still a hypothesis.** The pair that threw is
`targettarget` against `player`, and in a solo delve that comparison has a
specific meaning: *is that creature targeting me?* Which unit an NPC has
picked is threat information, and threat is the kind of thing the regime holds
back. `target` against `player` leaks nothing by comparison — it is your own
choice, and you made it.

Those two missed the pair itself, because neither was typed while anything had
a target of its own — the block is gated on the unit existing, which is right
for the model questions and is why it took a third run.

**The fix holds.** Session 71 is the delve run above, with the guard in place
and `same as player` coming back hidden — the exact condition that threw 716
times in session 70. Its log was flushed at 16:35 and carries **no
`portrait.lua` entry at all**; the 716 did not grow. The target-of-target
column came up on its 2D stand-in, which is the right answer for a hostile
model withheld inside an instance.

**Why only that one frame.** `targettarget` is a derived token, so oUF spawns
it *eventless* — a 0.5s tick instead of events (`ouf.lua:405`). Two events are
let through anyway because the portrait has nothing else to go on, and being
on an eventless frame they are registered **without a unit filter**
(`events.lua:99`). So that single frame is told about every portrait and every
model change in the world, and compares each one against its own token. Every
other frame compares its token with itself, which nothing refuses: the proof
is the same session, where this frame's own tick made that comparison
thousands of times and produced none of the 716 errors.

The fix stands in front of the handler rather than replacing the element. oUF
keeps its event handlers in plain fields on the frame, `self[event]`, so a
wrapper costs a closure and leaves the portrait still being set by oUF's own
code. Three answers, three things to do: not ours, drop it; ours, hand it on
naming the frame's own token; refused, settle it on a 0.5s timer through
`ForceUpdate`, because "some model somewhere changed" arriving several times a
second must not reload ours several times a second.

All five of the portrait's unit events are guarded, not only the two that
threw. The other three — `UNIT_CONNECTION` and the two `PARTY_MEMBER_*` — are
shared with Health and Power, so the field holds a list rather than a single
handler, and the portrait's entry is picked out of it by identity: the same
function is registered for all five, and `UNIT_PORTRAIT_UPDATE` is the one
field where it is still alone. **Health and Power need no guard of their own.**
They gate on `self.__unit ~= unit`, a plain string comparison no client can
hide. The portrait is the only element in oUF that asks the client to compare
two tokens for it.

**The other ten call sites are not reached from here**, and it is worth
knowing why rather than trusting it. All ten ask `unitIsUnit(unit, 'player')`
from elements that only exist on the player frame, where the token *is*
`player` and the comparison is the one nothing refuses. The exception is a
vehicle, where the frame's token becomes `vehicle` — untested, and the first
place to look if class power or the resting indicator ever throws this.

It is installed through `oUF:RegisterInitCallback`, which runs for every
spawned object — **including header children**, which is what matters next:
`partyNtarget` and `raidNtarget` take the same eventless path (`suffix ==
'target'`, `ouf.lua:423`), so the group frames would have walked into exactly
this.

Not reported upstream yet.

### Incoming healing and absorbs

Three surfaces on the health bar, all of them oUF's own: `HealingAll`,
`DamageAbsorb` and `HealAbsorb` on the Health element, which updates them
itself and sizes each one to the health bar on every size change. Only the
height and one anchor are Umbra's.

**That anchor is the one exception to the geometry rule**, and it is what
makes the arithmetic possible rather than a shortcut around it. Incoming
healing starts where current health ends, and `current + incoming` cannot be
worked out in Lua: both are hidden, and adding them throws. The client can do
it, so the sum is written as an anchor — the healing bar's left edge on the
right edge of the health fill, the absorb's on the right edge of the healing
fill — and never passes through us at all.

The rule survives that, because it is about **reading** geometry, not about
anchoring. Nothing asks these bars how wide they came out. oUF sizes them from
`Health:GetWidth()`, whose rectangle is explicit, and otherwise only calls
`SetMinMaxValues` and `SetValue` on them, both of which take hidden numbers.
Widgets.lua says the same thing about the bar shading, which lies over the
whole bar rather than over the fill — that one had a choice and this one does
not.

Each bar is as wide as the whole health bar while starting somewhere inside
it, so `SetClipsChildren` on the health bar is what keeps the overhang off the
rest of the frame.

**The numbers had to move.** The prediction bars are children of the health
bar, so they draw above everything the bar itself carries, and the two labels
were among that: a large absorb covered the health value it belonged to. The
labels now sit on a layer of their own above the prediction bars, explicitly
sized and anchored to the frame like every other widget, with only the parent
changed.

The hatching is **our own texture**, `Media/hatch.tga`, for the reason the
signature line is a character rather than an art path: a path into the
client's own art cannot be asked whether it survived the last patch, and a
missing one draws nothing. The tile is 32x32 and white, with the stripe
repeating every 8 pixels in both directions so it meets itself seamlessly
however far the client stretches the region; `SetHorizTile` repeats it at its
native size instead of stretching one copy, which is why it is a plain
texture over the fill rather than the fill itself. The color comes from
`SetVertexColor`, and if the file ever goes missing the flat fill underneath
is still the right color at the right width.

**`/uuf dev test` fills these too.** An absorb takes someone else to put on you,
so it can be waited for even less than a full aura row. The stand-in amounts
are the bars' own scale — `SetMinMaxValues(0, 1)` and a plain fraction —
which says the same thing to a bar and needs no arithmetic on a hidden value:
`max * 0.18` would throw inside an instance, which is exactly where this
wants looking at. Where they start is still the real health, and that is the
honest picture. oUF rewrites all three on every health tick, so the stand-ins
go back on through the element's own `PostUpdate` rather than being written
once and lost on the next tick.

### Relevant to group frames

**The secure group header works, and these notes were wrong about that.**
Measured on Retail on 21 September 2026 with `/uuf dev header`, which spawns one
real header with `showSolo` and reports what the child came out as:

```
secure snippets (loadstring_untainted): unavailable

children: 2
child 1: oUF-guessUnit: party   umbraProbeRan: yes   unit: player   styled: true
child 2: oUF-guessUnit: party   umbraProbeRan: yes   unit: party1   styled: true
```

That run did not write down the roster, which left the child count unusable:
two children could have been a party or a header inventing frames. **Asked
again solo on 21 September 2026**, twice in a row so the second reading came
after the client's own layout pass:

```
group: solo, 0 member(s)
children: 1
child 1: oUF-guessUnit: party   umbraProbeRan: yes   unit attribute: player
child 1: __unit: player   styled: true   shown: false  (first run)
child 1: ...                             shown: true   (second run)
```

One child solo, two in a party, so the header follows the roster. `shown`
turning true on the second run is `RegisterUnitWatch` and the client's layout
pass doing their work unasked. The child machinery is measured whole: created,
unit assigned from outside any snippet, oUF's snippet run, ours run inside it,
style applied, shown. The probe pushes nothing.

`oUF-guessUnit` is set from **inside** the restricted environment, by oUF's
own `initialConfigFunction`. `umbraProbeRan` is set by a second snippet the
layout handed the header, which oUF's snippet runs near its end. `styled:
true` means that snippet reached its last line and called back out. All three
answer yes on a client where `loadstring_untainted` does not exist.

So group frames can be **real** group frames: children created, units
assigned and re-sorted by the client's own machinery, during a fight and
after it. Not four fixed frames for `party1..party4` waiting for combat to
end, which is what this section used to say was the only option left.

**The visibility driver works too, and took three askings to say so.**
`header:SetVisibility('solo,party')`
returns without erroring and oUF stores the conditional it built —
`[@player,exists,nogroup:party] show;[group:party,nogroup:raid] show;hide` —
but `state-visibility` reads back nil, both at registration and on a later
run. Which decides *when* a header appears, and can give out on its own.

Two readings fit that, and they are opposites: the driver machinery does not
work for this frame, or visibility is handled apart from the attribute and
writes none. `pcall` returning true separates neither, and neither does
`IsShown()` on a header something else has shown — the first version of this
probe called `Show()` right after registering, which left a header that looked
driven and was only pushed. It no longer shows anything by hand.

What tells them apart is a second driver on an attribute name that is ours and
special to nobody: `RegisterAttributeDriver(header, 'umbraProbeDriver',
'[@player,exists] yes; no')`. It answered **`yes`, at registration and after**,
on the same run where `state-visibility` stayed empty.

So the machinery is there and evaluates on the spot. Visibility is simply
steered apart from the attribute, and Show and Hide are the only place it
shows. Which leaves one more thing that cannot be read off a shown header: a
frame stands visible from the moment it is created, so a driver doing nothing
at all leaves exactly the picture a working one leaves. `header shown: true`
is not evidence and is no longer reported as any.

What cannot be faked is the header going **away** on a condition it cannot
meet. `/uuf dev header` ends by registering `[group:raid] show;hide` while solo,
reading `IsShown()`, putting the real condition back and reading again:

```
visibility driven: hidden by [group:raid] solo: true
                   back on solo,party: true
```

**So the header is driven, and nothing about group frames rests on a proxy
any more.** Children created, units assigned and followed, both snippets run,
style applied, and the client deciding when the whole thing is on screen.

Three askings for one answer, and each round the reading looked complete at
the time: `pcall` said true, the attribute said nothing, the frame said shown.
The first was a call not erroring, the second an attribute visibility does not
use, the third a frame that is visible from birth. Only the fourth asked for
something a broken driver cannot produce. That is the third time this file
records the same lesson in a week, and the cheapest form of it: **ask for the
thing that cannot happen unless the answer is yes.**

**Why the assumption was wrong, which is the part worth keeping.**
`loadstring_untainted` is what an *addon* calls to turn a string into a
function without tainting it. `initialConfigFunction`, attribute drivers and
state drivers are compiled by the *client's own* secure code, reached through
`SetAttribute`, and never go near that global. The two were read as one
mechanism because they are both "secure snippets" in conversation.

This is the same mistake as *Permission to compare two units is not an
answer*, and it happened in the same week: a proxy question was trusted in
place of the real one. There the proxy said yes and the answer was no; here
the proxy said no and the answer is yes. Neither direction is safe. **Ask the
question you actually need answered.**

`Umbra.hasSecureSnippets` stays, because it is a true measurement — it is the
label that was wrong. It answers whether *we* can compile a snippet ourselves,
which nothing here does, and it is not the gate for group headers. `/uuf
check` reports it as what it is.

A second thing they rest on is already answered: `partyNtarget` and
`raidNtarget` frames are spawned eventless and hear about every model in the
world, which is the fault issue #1 was — see *Permission to compare two units
is not an answer*. The guard for it is installed through
`oUF:RegisterInitCallback`, so header children get it without the group code
having to remember.

That flag is set in `Core/Init.lua` and reported by `/uuf dev check`. It used to be
set in `Compat/Forever.lua`, which returns early on anything but Forever and is
not listed in the Retail TOC at all — so on Retail it was nil, which behaves
like false and happens to be right, but by accident rather than by
measurement. A flag should not be true or false depending on which file
loaded — least of all one that was, at the time, believed to decide whether a
whole class of frames could exist. It does not; see above.

**Measured on Retail on 20 September 2026**, standing in *Die Abyssalhallen*:
`secure snippets: unavailable` beside `compat: none`. So the answer is the
same one the accident used to give, and it is now an answer: no compatibility
file ran, and the flag was set by asking the client. `loadstring_untainted` is
missing on Retail 12.1 as well as on Forever — **and that turned out not to
decide anything about group frames**, which is written up above.

---

## Next

### Waiting to be looked at

Written and installed, never confirmed in the client. Each one degrades
quietly rather than erroring, which is why none of them announced itself.

1. **A real absorb.** The surfaces are confirmed: the stand-ins were seen in
   *Thron der Gezeiten* on 20 September 2026 and drew on the target frame
   too, so the anchors to the health fill are accepted inside an instance on
   a unit whose health is hidden — which is the thing this design rests on.
   Incoming healing then looked right on a later run, reported rather than
   measured.

   What has not been pinned down is a **real** damage absorb, because none of
   the runs so far produced one: a hunter carries no absorb of its own. The
   remaining question is whether oUF's values arrive, not whether the
   surfaces work, and a shielded tank in the target frame answers it.

2. **Umbra's words for an aura's duration.** Written on 7 November 2026 from
   the client's interface code, and seen on Forever the same evening in
   *Eisenschmiede*, off a lossless screenshot at 1.3125 pixels per unit:
   `/uuf dev check` read `aura duration format: ours (25m)`, so the formatter
   was built and answered its test numbers, and the buff row read `29m`,
   `31m` and `2h`, every label's core 3 to 11 pixels inside its icon's edges
   where `25 min` had hung 6 over. The cast time measured `230/233/240`, the
   text color, though it stood on the empty part of the bar in that shot.

   On 8 November 2026 `/uuf dev check` read `aura duration format: ours
   (25m)` on the Anniversary realms and Classic Era as well, where Umbra
   writes the timer on its own rows.

   Still to be seen: the same row inside an instance, where the duration is
   secret and the client applies the rules without Lua seeing the value; the
   cast time on the fill; and Retail. If a check reads `the client's`, `/uuf
   dev debug` has the number the formatter failed on.

3. **The theme.** Written from the screenshots of 7 November 2026 and from
   the client's interface code, and seen on Forever on 8 November 2026 off
   lossless screenshots at 1.3125 pixels per unit. The palette measured
   exactly on the frames and in the options window, whose border was one
   physical pixel; `/uuf theme` switched the frames where they stood
   (reported, not measured). At 09:05 in *Halle der Waffen* the rim lay
   inside the body, one pixel at `154/128/92`, `128/104/72` and `104/80/52`,
   the right line on the frame's last column, and the target of the target
   kept a clear three-pixel gap over the target. At 09:24 in *Tundrid-Hügel*,
   at 2.125 pixels per unit, the lines were still one pixel each in the same
   three colors, the right line owned both corners, and the top and bottom
   started on the pixel after the class edge, which ran the whole height —
   so a second UI scale is settled. At 09:42 in *Kristallsee*, back at
   1.3125, the lines started where the portrait begins: on the player, the
   target and the target of the target the class edge (four pixels) and the
   gap beside it (three) ran from the body's first row to its last, and the
   top and bottom began on the portrait's first column, in the same three
   colors. Later that day `/uuf setup` opened in Forever's furniture as
   well, bronze border and gold title — looked at, not measured to the
   pixel. And on Retail, Mists, the Anniversary realms and Classic Era,
   the same day: `auto` kept Umbra's slate and teal, and `/uuf theme
   forever` drew the same look — seen working on all four, not measured.
   What a look still has to settle:

   - A switch in combat, which should be a result, and a UI-scale change in
     one, which should re-measure the rims on the spot.
   - A switch inside an instance, where a region may carry an aspect the
     client will not let an addon recolor. `/uuf dev debug` reads `theme
     repaint refused:` if one did.
   - The options window and the onboarding in Forever's own window frame,
     built on 11 November 2026. Both were measured in the game the same
     evening, the options window switched between all three themes while
     open; the states in a fight and a change of UI scale are still to be
     seen: the checklist under *The windows in Forever's own frame*, *In the
     game*.
     The furniture seen on 8 November is now what the other clients show
     under `/uuf theme forever`, and Forever where its frame's art is
     missing.

4. **The portrait camera.** Written on 8 November 2026 from one picture —
   see *A portrait framed before its model arrived*. What has to be seen:

   - The close-up not coming back over some days of play on Forever.
   - `models loaded since the last reload` above zero in `/uuf dev check`
     on each client that offers the script, the Anniversary realms and
     Classic Era above all, where nothing of Blizzard's uses it.
   - Healthy portraits unchanged by the refresh: the face on every frame,
     the question mark of a disconnected party member, and the 2D stand-in.

   On Forever, the same day, the first run with the change: the script
   fires there. `/uuf dev check` counted 2 loads on the player, 2 on the
   pet, 7 on the target and 3 on the target of the target. The debug buffer
   read `portrait missing for` the player and the pet at login, then
   `portrait arrived for pet on its own, before try 1` — a late model that
   was not set a second time — and `portrait arrived for player on its own,
   before try 2`, worded since as *try 1 had set it again*: the player's
   model was still missing at try 1, so that try reloaded it, as it should.
   The four faces looked as they did before the change, and a party member
   who had gone offline showed the question mark as it should. On Retail,
   Mists, the Anniversary realms and Classic Era, the same day, the
   portraits worked as well, and the script fires on the two clients where
   nothing of Blizzard's uses it: `/uuf dev check` counted 2 loads on the
   player and 3 on the pet on TBC Anniversary (interface 20506), and 3 and
   2 on Classic Era (11509). On Retail and Mists the count was not written
   down. Still open: the close-up.

5. **The rest indicator and the pet's mood.** Written on 12 November 2026
   from the UI source of all five clients — see *Resting, in the corner of
   the portrait* and *A hunter's pet says how it is*. `/uuf dev check`
   prints four lines for them, `rest art`, `rest now`, `pet mood` and `pet
   mood now`; unlocking and `/uuf dev test` show the Z's.

   Seen on Forever the same evening, off a lossless screenshot
   at 1.3125 pixels per unit: the Z's drawing in the portrait's top right
   corner while resting, their yellow at x 839–857 and y 1041–1058 against a
   square of 836–862 by 1037–1063, so inside it and inside the column, on
   the frame of the flipbook that was caught.

   `/uuf dev check` on Forever on 13 November 2026, a hunter resting with
   his pet out (`dev-41ea1c7-dirty`, interface 16001):

       rest art: available — the client's flipbook, 42 frames in 1.5 s
       rest now: resting yes, in combat no, showing yes
       pet mood: available — C_PetInfo.GetPetHappiness, on the edge, the portrait and in the tooltip
       pet mood now: 3 of 3, 125% damage, loyalty rising, 6 foods, painted yes

   So on Forever the atlas is in the data and a `FlipBook` animation builds
   from Lua, which no Blizzard code does; `C_PetInfo` answers in the clear
   with the level, the damage and a rising loyalty; the diet comes back as a
   table of six; and the mood was painted.

   The other four the same day, the same build:

   | | `rest art` | `rest now` | `pet mood` |
   | :--- | :--- | :--- | :--- |
   | Retail (120105) | `available` — the flipbook | resting yes, showing yes | `none` — no pet happiness |
   | Mists (50504) | `still` — the atlas is not in this client | resting yes, showing yes | `none` — no mood since Cataclysm |
   | Anniversary (20506) | `still` — the atlas is not in this client | resting yes, showing yes | `none` — only a hunter's pet, on a warlock |
   | Classic Era (11509) | `still` — the atlas is not in this client | resting **no**, showing no | `none` — only a hunter's pet, on a warlock |

   So the flipbook is Retail's and Forever's, and the three Classic clients
   have the still icon; the UI source could not have said which. On Classic
   Era nothing showed, and the client said why: `IsResting` answered false,
   because the character stood in a town that is not a rest area — so the
   frame did what the client said. The icon there is taken to work as it
   does on the Anniversary realms, which run the same code and fall back on
   the same file. What is still to be seen:

   - The Z's gone in a fight in a city and back after it.
   - How large they draw across the whole loop. The client's cells carry a
     margin of their own, so `restSize` may want tuning.
   - The pet frame on Forever with a hunter's pet: yellow and then red as
     it goes hungry, and green again after feeding, each change arriving
     without touching the frame — `UNIT_HAPPINESS` taken unitless has not
     yet been seen to fire for it — and off a lossless screenshot the edge
     at `petMood`'s values and the model uncovered. The tooltip's lines in
     German under the unit's, staying while the pointer rests on the frame.
     A warlock's frame and tooltip unchanged.
   - On the Anniversary realms and Classic Era with a hunter: the same
     colors and lines, and the diet read from return values. The
     characters checked there so far were warlocks.

Settled on 21 September 2026, measured in a delve:

- **The portrait guard**, issue #1 — see *Permission to compare two units is
  not an answer*. The run that confirms it is the one where `same as player`
  came back hidden, which is the condition that threw 716 times before it, and
  its log carries no `portrait.lua` entry at all.

  One half of it is reported rather than measured, and is the half that can
  fail quietly: whether the target-of-target column keeps **following** what
  the target is looking at. The fix trades an immediate refresh for one on a
  0.5s timer wherever the client refuses to answer, and a snapshot cannot tell
  a column that follows from one that is merely correct at the moment it was
  looked at. `unit comparison refused:` in the debug buffer says the settling
  branch was reached; whether it settles on the right unit is watched for.

Settled on 20 September 2026, all reported from the client:

- **Which way a row fills after a layout switch.** Nine buffs were the test
  the earlier runs could not give it. `modern` fills upwards, `classic`
  downwards, both correct — so `SetFlowLayoutAnchorPoint` and
  `SetFlowLayoutGrowthDirection` do take after creation, and a set switch
  needs no rebuild.
- **`/uuf auras both`**, working in use. The narrower worry — Edit Mode also
  moves `BuffFrame` and `DebuffFrame`, and might take them back from a parent
  of ours — has not shown itself, so it stops being a question and becomes
  something to watch for.
- **Energy**, on a druid. Rage and focus were already confirmed, focus
  measured at `239/138/85` on the hairline against the client's `255/128/64`
  with the gloss over it, and the percentage above it orange at `195/128/97`
  rather than the `141/151/171` it would fall back to. All four resources
  answer.
- **The 2D portrait stand-in**, and that it *is* the design: 2D where the
  client has classified the unit, 3D where it has not. Not a fault to chase
  but the two halves of one rule — `SetUnit` takes no token for a secret
  identity, so the column shows whichever of the two it can get.
  `SetPortraitTexture` is allowed where the model was not, which was the open
  half of it. Instances are where that happens, not what causes it: a party
  member inside one is in the clear and his model loads — see *The client
  keeps a hostile unit's model to itself*.

Settled earlier: auras inside an instance, the side a row lands on after a
switch, and the frame positions in both sets.

### Remaining single frames

None. Target-of-target and the boss column are built — see *The rest of
the single frames* — and incoming healing and absorbs went in through oUF's
health sub-widgets. What is left of the single frames is looking at the three
new ones in the client.

### Group and raid frames

**The party column is built**, on a real secure header: `Layouts/Group.lua`.
Children the client creates, assigns and re-sorts, in the Umbra style, keyed
`party` because that is the unit oUF hands a header child. Confirmed drawing
in a delve on 21 September 2026 with two members — `/uuf dev party` reports the
column child by child, with each top edge in screen coordinates so a row in a
screenshot can be matched to the frame that drew it.

**And a cast bar**, the one the single frames have, at full width under the
frame. It took one line in the config: `StackOffset` opens a frame's lower
side with `CastbarReach`, so the debuff row moved down by exactly the
castbar's height and `GroupSlotHeight` carried that into the header's spacing,
the column's height and the stand-ins without any of the three being told. A
member is 69 tall now — 33 of frame, 16 of castbar, 20 of debuff row — and the
column is 294 for four of them.

**Each member carries a debuff row**, and the form was the decision rather
than the switch. The single frames' row is 26-pixel icons eight across; a
party frame is 33 pixels tall, so that row under one of them reads as a second
column of frames. Party icons are 14, which puts the block at 18 — the health
bar's own height plus its gap and underline — and the duration label is off,
because at 14 pixels it covers the icon it belongs to. The stack count stays:
one glyph, and the one that changes what you do. How many icons is asked
rather than chosen — at that size `AuraPerRow` answers fourteen, and fourteen
of them with their spacing are exactly the 222 pixels a frame is wide, so the
row ends where the frame ends instead of stopping somewhere in the middle of
it. Buffs are off; what is dispellable is the information, and the underline
already carries it.

ShadowedUnitFrames answers the same question with buffs at the frame's top
left and debuffs at its bottom left, 16 pixels, one row of up to ten, both
growing right, with auras you cast yourself drawn 30% larger — the same
arrangement for party as for everything else. Read as evidence, not copied: it
carries no license (decision 3).

**One number now answers how much room a member takes.**
`Umbra:GroupSlotHeight` is the frame plus whatever hangs off either side of
it, and the header's `yOffset`, `ColumnHeight` and the unlock stand-ins all
ask it. Before the debuff row the three agreed by accident, because nothing
hung off a party frame at all; the first row under one would have put the next
member on top of it.

**The tank and the healer are marked, and the role survives the instance.**
Measured in a five-man party inside one on 21 September 2026: all four
children answered `readable` to `UnitGroupRolesAssigned` — TANK, DAMAGER,
DAMAGER, HEALER — with `roleicon-tiny-healer` known to the client. That was
worth asking before drawing anything from it: a role is what a person signed
up as, not a property of a unit in the world, and this client has been
withholding exactly that kind of thing. The first run of the same report
proved less than it looked like it did, because it did not say where it had
been taken; it does now.

All three roles are drawn. The first build marked only the tank and the
healer, reasoning that a mark on three rows out of four is not a mark and that
damage is named by carrying nothing. It reads well and it was wrong in use: an
empty space says "no role" and "damage" in the same breath, and in a column of
four the gap is never explained. NONE still draws nothing — that one is an
absence. The space is reserved on every
group frame regardless, the way the pip row is reserved on the player frame:
four names starting at one x with two marks beside them is a column, and names
that move sideways when somebody re-queues is a fault. The art is the client's
own atlas, checked before it is shown, because `SetAtlas` on a name this
client does not have leaves the texture as it was instead of refusing — the
one failure that would draw a blank square and say nothing.

Three faults came out of that first run, and all three failed silently:

1. **A stray second frame.** `Layouts/Single.lua` spawns one frame per entry
   in `Umbra.frames`, and the party config lives there because the style looks
   its configs up by unit. So an unmanaged single frame for the unit `party`
   was spawned beside the column, under the same mover name and the same saved
   position. The config carries `header = true` now and `Single.lua` skips it.
2. **The column could not be dragged.** Every other mover is a unit button and
   takes the mouse by being one; this one is a plain frame, which receives no
   mouse input until told to. It listens and rises a strata while unlocked,
   and gives both back on locking — an invisible box over a party column would
   swallow every click meant for the people in it.
3. **`inset` did not exist in the `modern` block.** It is a local of the
   `classic` block above it. The point read nil, the client took nil for zero,
   and the column sat flush against the screen edge — on top of
   `CompactRaidFrameManager`, which the client shows for exactly as long as
   you are in a group, which is exactly as long as the column exists. It has
   its own `inset` now and stands on `baseline`, the line the player and
   target frames stand on.

**The player is not in the column.** Decided on 21 September 2026: the column
is about the other four. `showSolo` and `showPlayer` are switched on only
while frames are being placed, so there is something to drag and something to
see the style on when you are alone.

**Range fading is in**, on group frames only, which is where oUF's `Range`
element works at all: it gates on `UnitInParty` and sets the inside alpha for
anything else. On a single frame it would be a no-op that always reports "in
range". It fades through `SetAlphaFromBoolean`, so the answer is never tested
— but `UnitIsConnected(unit) and UnitInParty(unit)` above it is, and that is
the shape issue #1 threw 716 times on. On party members rather than on a
hostile unit, so it is watched in the error log rather than guarded in
advance.

**Raid frames are parked, and that is a decision rather than a delay.** 22
September 2026: Blizzard's own raid frames do the job, class coloring
included, and nothing about them is in the way often enough to be worth forty
frames in eight subgroups. They stay in the README table as *not yet*, the
header carries them whenever they are wanted, and nothing else is waiting on
them. Clique support is what is left ahead of them.

**No fixed frames for Forever, either.** The beta could not configure a
header child (*The secure header does not work on Forever*), and the answer to
that was not a second party column built out of four nailed-down frames: it
would have had no sorting and no in-combat changes, it would have needed
maintaining beside the header, and raid frames would have been the same work
twice over. The client might have its own copy of `loadstring_untainted` back
by its launch on 4 November 2026, and then every line of that would have been
written for nothing. So Umbra waited for the client, with the column standing
itself down and Blizzard's group panel taking over. The release client needed
nothing more: on 8 November 2026 its header configured its children and the
column drew a party. The stand-down stays, for a client that cannot build one.

**Open, and not urgent: pets of group members.** Two shapes are in the
running and neither has been argued out yet — under each member's own frame,
the way the player's pet hangs under the player, or at half size beside it.
In a five-man one or two people bring one and it is rarely what you react to,
so nothing is lost by deciding this after the column has been used in anger.

### Blizzard's own aura display

`Core/Blizzard.lua` parents `BuffFrame` and `DebuffFrame` to a frame that is
never shown, behind `/uuf auras`. Not `Hide`, which the next thing that
shows them undoes, and not `UnregisterAllEvents`, which cannot be undone at
all. Reparenting leaves their logic running and is reversible.

**Both names are still right on Retail 12.x**, established without the client
by reading addons on this machine that reach the same two frames:
EnhanceQoLSkinner hides `_G.BuffFrame` and `_G.DebuffFrame` by those names,
and EnhanceQoL's Edit Mode library lists both as Edit Mode systems and finds
a `.Selection` on each. So `/uuf dev debug` reporting a name it cannot find is a
Forever finding, not a Retail one.

**They are protected, and that was a real defect.** The same addon bails out
of hiding them on `InCombatLockdown() and frame:IsProtected()` and picks the
work up again at `PLAYER_REGEN_ENABLED`. Umbra's `SetParent` sat inside a
`pcall` that swallowed the refusal: `/uuf auras umbra` typed during a fight
did nothing, printed that it had worked, and nothing happened when the fight
ended either. A refusal is now a wait — the last state asked for is kept,
applied at `PLAYER_REGEN_ENABLED`, and the command says it is waiting rather
than reporting a state the screen does not show yet.

Still unverified: whether Edit Mode puts the frames back. That is what
`/uuf auras both` followed by a trip through Edit Mode answers.

### Configuration

Ace3 is not embedded yet. Positions live in a small hand-rolled store in
`Core/Mover.lua`, keyed by layout set, and the set itself is one saved string.

**The options window** (`Core/Options.lua`, since 0.6) sets what `/uuf` sets
and nothing more. Both go through `Umbra:SetOption(key, value)`, which writes
the saved value, calls the applier the command always called, and tells an
open window through `Umbra:OptionsChanged()`. `SetLocked` and the party
column's `StandDown` tell it too. So a new setting is one entry in `SETTINGS`
there, one control in `Build`, and one branch in the command; a setting that
cannot be applied live does not belong in that window until something can
rebuild a frame.

`debuffs` (0.8) is the first setting the onboarding does not ask. It is a
refinement of the layout for frames kept somewhere the set did not plan for,
and someone answering the first questions has not put them anywhere yet.
`theme` (0.9) is the second: `auto` already answers it by client.

The window is drawn from Umbra's palette, whichever theme is in force, rather
than from the client's templates — except on Forever under the Forever theme,
where it and the onboarding wear the client's own window frame (*The windows
in Forever's own frame*) — and `tools/mockups.py` draws its flat look from the
same numbers (`OPT`) — change one, change both. Its three ways in besides `/uuf` are in `Core/Minimap.lua`
(the addon compartment on Retail and Forever, a minimap button on the Classic
clients, which have none) and at the end of `Core/Options.lua` (a page under
Options › AddOns). Its words go through `Umbra.L` (`Core/Locale.lua`), keyed
by the English text: German on `deDE`, English everywhere else, and a missing
translation falls back to the English key. Chat output is not translated.
The Settings API calls it uses were checked in
wow-ui-source on all five branches; `AddonCompartment.lua` exists on `live`
and `forever` only.
**The onboarding** (`Core/Onboarding.lua`, since 0.7) asks the same settings,
but for the debuffs switch,
on the first login, one to a page with a preview, and is drawn in
`assets/design/onboarding.svg` from `ONB` in `tools/mockups.py` — change one,
change both. It writes through `Umbra:SetOption` as the window does, so it
holds no state of its own beyond the page it is on, and it builds its
switches from `Umbra.Widgets`, the options window's own pieces. It hooks
`Umbra:OptionsChanged`, so an answer given elsewhere shows up in it at once.

First login is decided in `ADDON_LOADED`: no `UmbraUnitFramesDB` at all sets
`onboarded = false`, and a table without the field — anyone updating from
0.6.1 or earlier — counts as asked. The window sets it true however it is
left. It opens a second after `PLAYER_LOGIN`, or after the fight when the login
lands in one.

Its previews are drawn rather than borrowed. The miniature screen is placed by
the set's own points, scaled, so the client resolves its anchors exactly as it
resolves the real frames'; the player frame is plain textures from the same
metrics, with the 2D portrait, name, class color and level of the character
logging in.

When that moves to AceDB and AceConfig, the design studio's profile schema
(`schemaVersion: 2`) should become the import format. The studio still offers
`classic|retail` and needs updating to the three real clients first.

### Forever

Forever launched on **4 November 2026**; its beta closed on 23 October. Known
beta behaviour: `/reload UI` is protected while `/reload` is not.

**The beta client was installed** from 20 September 2026, under the same root
as Retail: `World of Warcraft\_classic_beta_`, whose `.flavor.info` reads
`wow_classic_beta`, with `WowB.exe`. The beta closed on 23 October 2026, and
the launcher now installs Forever as product `wowf` into `_forever_`, which is
where `.\tools\install.ps1 -Flavor forever` puts the addon since 0.8.
`tools/.wowpath` holds the shared root, so the flavour alone picks the client
and neither overwrites the other. Nothing carries over from the beta folder:
its AddOns and saved variables stay behind.

`Interface\AddOns` does not exist until the client has been started once, so a
first install has to wait for that.

### The secure header does not work on Forever

**On the beta. On the release client it does** — measured on 8 November
2026, see *Measured on the release client* at the end of this section.

**Settled, on the first run of `/uuf dev header` on that client**, 22 September
2026. The answer did not come back in the report window: it came back in the
error log, eighty-eight times.

```
Blizzard_RestrictedAddOnEnvironment/RestrictedExecution.lua:79:
	attempt to call a nil value
	with args (body="local header = self:GetParent()", env=<table>, signature="self")
  ...SecureGroupHeaders.lua:120  (header=UmbraProbeHeader, newChild=…UnitButton1)
  ...SecureGroupHeaders.lua:495  SecureGroupHeader_Update
  ...SecureStateDriver.lua:101   state-visibility

Locals: loadstring_untainted = nil
```

The body being compiled is **oUF's `initialConfigFunction`**, and the code
compiling it is **Blizzard's own**. `SecureGroupHeaders.lua` configures every
new child by running a snippet through the restricted environment, the
restricted environment compiles every snippet with `loadstring_untainted`, and
on this client that function is not there. So the header creates a child, the
child cannot be configured, and the state driver comes back and tries again.

**Everything around the snippet works.** The probe run that produced this, on
the retired-probe build the same afternoon, is otherwise a clean bill:

```
visibility driver: true    plain driver: true    state now: yes
header shown: true
children: 7
child 1..7: oUF-guessUnit nil · unit attribute nil · __unit nil · styled false
visibility driven: hidden by [group:raid] solo: true
                   back on solo,party: true
```

Drivers register, the client evaluates the conditionals itself and writes the
answer, and visibility is genuinely driven — hidden on a condition that cannot
be met and back the moment it can. Macro conditionals are native; only the
compiling of a snippet body is gone. The header is a complete machine with one
part missing, and it is the part that gives a child its unit.

**Children, none of them finished.** Seven on the first run, three on a fresh
one after a reload, solo, where a working header makes one — the client
creates the button, throws while configuring it, and comes back and makes
another, so the count is a tally of attempts and says nothing about whether
the header works. Nothing takes the half-built buttons back, either.

That cost a day's assumption: the first stand-down written here tested
`#children == 0`, which is the one number Forever does not produce. What
separates a working header from this one is whether **any child was given a
unit** — the client's own `unit` attribute, or oUF's `__unit` — and the probe
and the live column both ask it that way now.

**And the throw cannot be caught, only seen afterwards.** The full stack puts
it on our own call:

```
RestrictedExecution.lua:79  attempt to call a nil value   loadstring_untainted = nil
  SecureGroupHeaders.lua:120 / 176 / 495
  [C]: Show
  SecureStateDriver.lua:100 / 164 → RegisterAttributeDriver
  oUF/ouf.lua:727            header:SetVisibility
  [C]: pcall
  Group.lua:647              the probe registering its visibility
```

Our `pcall` is two frames below the error and the report above it reads
`visibility driver: true`. The restricted environment hands the error to the
error handler and carries on, so the call succeeds, the log fills, and no
caller can tell. A capability probe built on `pcall` would therefore answer
*yes* on the client where the answer is no — which is why the stand-down reads
the header's children instead of trying to catch anything.

**This is not the same question as `secure snippets (ours)`, and that line is
now worth more rather than less.** It reads `unavailable` on Retail too, where
the party column works perfectly: an addon cannot compile a snippet there, and
Blizzard's own machinery can. On the Forever beta neither could. The two
clients therefore separated cleanly:

| | Retail 120100 | Forever beta 69913 |
| :--- | :--- | :--- |
| an addon compiles a snippet | no | no |
| the client compiles its own | yes | **no** |
| secure group header | works | cannot configure a child |

Which settled what `/uuf dev header` was built to ask, and settled it the
wrong way for that build: **no secure group header could work on it**, by oUF
or by anyone, because what failed was below every layout. A party column on
the beta would have had to be fixed frames with no sorting and no in-combat
changes — which is the second addon the header was chosen to avoid being — or
wait for the client to gain the function before its launch on 4 November
2026. It did; see *Measured on the release client* below.

**Build 70009 may be what changed this.** Read off the
`forever` branch on 25 October 2026: in 1.60.1.70009, 24 September,
`Blizzard_EnvironmentCleanup.toc` stopped depending on the restricted
environment through a game-type gate that left `camelot` out, and now names
it as an `OptionalDep` the way Retail does. On 69913 the cleanup could run
first and clear `loadstring_untainted` before `RestrictedExecution.lua`
captured its own copy at file scope — which is the `loadstring_untainted =
nil` the error above shows. The restricted-environment and group-header Lua
is byte-identical to Retail's, and the oUF maintainers name 70009 as the fix
(oUF #895). `/uuf dev header` has since been run on the release client, and
the header works there; whether 70009 or a later build did it, nothing here
can tell. The column's stand-down measured it as it was written to, and a
header that worked was used without a change.

Three things followed for the code on the beta:

- **Solo it does not bite.** The live header spawns with `showSolo` and
  `showPlayer` false and a `party` visibility, so it is hidden and configures
  nothing. The errors above came from the probe, which turns both on to force
  the question. On the beta the column would have failed the moment a party
  was joined, not at login.
- **The probe now retires itself.** It gives up its drivers and hides once it
  has answered, because a driver on a header that cannot build a child is a
  standing invitation to try again — eighty-eight times in one run. A second
  `/uuf dev header` arms it again.
- **And the live column now checks its own work.** Two seconds after the
  header is first shown it asks whether any child was given a unit; children
  without one is not a state a working header passes through, so it gives up
  its driver, hides, hands Blizzard's group panel back whatever `/uuf group`
  says, and prints one line saying so. `/uuf dev party` opens with `stood
  down`.

  It is written as a measurement rather than a client check: nothing in it
  asks whether this is Forever, it asks whether this header produced
  children. That answers correctly on the next client nobody has tested yet,
  and it answered correctly on Forever's release client, where on 8 November
  2026 it found children with units and stayed out of the way.
  In combat it is postponed rather than decided — unregistering a driver
  touches a protected frame — and the question is asked again the next time
  the header is shown.

**Measured on the release client.** `/uuf dev header` on 8 November 2026,
solo, on `dev-9dc59df` against interface 16001:

```
secure snippets (ours): unavailable
group: solo, 0 member(s)
header: created
children: 1, configured: 1
child 1: oUF-guessUnit: party   umbraProbeRan: yes   unit attribute: player
child 1: __unit: player   styled: true   styled as: party
visibility driven: hidden by [group:raid] solo: true
                   back on solo,party: true
```

The same answer Retail and Mists give, and no error in the log: the client
compiles its own snippet again — whether through 70009, which the oUF
maintainers name as the fix, or a build after it, nothing here can tell.
`secure snippets (ours): unavailable` is the addon-facing global, which Retail
clears as well, and says nothing about the header. The same day, in a real
group, the column drew the party, a member who had gone offline with the
question mark. Nothing in Umbra changed for it; the stand-down simply found
children with units and stayed out of the way.

### What the Forever client actually did

Run on 20 September 2026 against build `1.60.1.69913`, standing in Deathknell
on a level 1 warlock. **Umbra loads and draws.**

- **The TOC is picked up.** The `_Camelot` suffix is real rather than a guess:
  MinimapButtonButton ships one too and declares the same
  `## Interface: 16001`, which is what the build number resolves to.
- **`issecretvalue` is true here as well.** The restricted-value regime is not
  a Retail-only thing, which had been an open assumption.
- **The same values are hidden, and none of them throws.** `UnitHealth`
  hidden, `UnitHealthMax` readable at 63, `UnitHealthPercent` hidden, and all
  three tags — `[umbra:health]`, `[perhp]`, `[perpp]` — hidden rather than
  erroring. The reasoning under *Hidden values reach further than documented*
  holds on both clients.
- **`aura underline: available`.** `Enum.CustomAuraButtonDispelTypeTextureStyle`
  and its `PreserveAsset` exist here, so the dispel coloring is not Retail-only
  either. The containers were built and the rows drew.
- **The chat font carries U+2665**, so the signature line reads as intended.

One deviation found in passing: **`GetSpecializationInfo` answers with the
class name.** On the warlock it returned *Hexenmeister* for spec 1, where
Retail names the specialization. It only reaches a diagnostic line, so nothing
is built on it.

- **`Umbra.isForever` matches.** `/uuf` names the client `Forever (interface
  16001)` rather than `unsupported`, so `WOW_PROJECT_ID ==
  WOW_PROJECT_MAINLINE` holds here and the interface falls in the 16xxx band
  the check keys off. **No longer from 1.60.1.70170 on**, 1 October 2026:
  Blizzard's `Camelot\ProjectConstants.lua` sets `WOW_PROJECT_ID =
  WOW_PROJECT_CAMELOT` (18), which made Forever neither Mainline nor Forever
  here, `Compat/Forever.lua` returned on its first line and `/uuf` said
  `unsupported`. Found by reading the `forever` branch on 25 October; 0.8 asks
  for either answer and counts Forever as Mainline.
- **`secure snippets: unavailable`.** `loadstring_untainted` is missing here,
  as the record said, and `Umbra.hasSecureSnippets` is false by measurement
  rather than by a file that failed to load. What that was taken to mean for
  group frames was wrong, and is corrected under *Relevant to group frames* —
  the header on Retail works without it. Whether the same held on Forever was
  one `/uuf dev header` away; on the beta it did not, and on the release
  client it does.

**One thing does not add up yet.** `/uuf dev debug` answered `nothing has been
refused since login` on a run where `secure snippets: unavailable` — but that
is exactly the condition under which `Compat/Forever.lua` calls `Umbra:Debug`
two lines further down. The buffer should have held at least that one line.

So either the compat file is not running to the end, or the buffer is not
being filled, and until that is told apart an empty buffer proves nothing
about what the build refused. `/uuf dev check` now reports `compat:` for exactly
this: `Forever.lua ran` is the file confirming it reached its last line, and
`none` on this client would mean it did not. On Retail `none` is the expected
answer, because no compatibility file is loaded there at all.

### Mists of Pandaria Classic

*The Anniversary realms (Burning Crusade 2.5.6) share all of this — see
*Anniversary* below.*

Added on 25 September 2026, **checked against Blizzard's interface code
first** and played with the day after — see *Measured on 26 September 2026*
below. The first plan was a second, older oUF — 12.1.0, the
last tag without secret values — with an adapter for every place its API
differs from 14. It was dropped before a line of it was written, because the
premise was wrong: Mists is a Classic client in `WOW_PROJECT_ID` only.

**How it was checked.** Blizzard's own interface code for the `classic` branch,
build 5.5.4.69934 of 22 September 2026, carries the generated API
documentation. Every client function oUF 14 and Umbra call was looked up in
it, and a name that is not documented was looked for in Blizzard's own code,
because a few long-standing globals (`UnitIsDead`, `UnitHasVehicleUI`) are
used there and never documented. What came back:

- **There:** `issecretvalue`, `C_Secrets`, `CreateUnitHealPredictionCalculator`
  with every method oUF's health element calls on it, `UnitHealthPercent`,
  `CurveConstants.ScaleTo100`, the duration and seconds-formatter objects the
  cast bar builds at file scope, `SetAlphaFromBoolean`, `UNIT_IN_RANGE_UPDATE`,
  `UnitGroupRolesAssigned` and the `roleicon-tiny-*` atlases, `PartyFrame` with
  its `PartyMemberFramePool`, `BuffFrame` and `DebuffFrame`, and
  `CompactRaidFrameManager`. `RestrictedExecution.lua` keeps its own
  `loadstring_untainted` before the environment is cleaned, exactly as on
  Retail, so the secure group header should work.
- **Missing:** the `AuraContainer` widget, `AddDispelTypeTexture` and the
  `CustomAuraButtonDispelType*` enums — so oUF 14's aura rows cannot be
  built — and `GetUnitChargedPowerPoints`.
- **Missed by both, found by reading oUF against Blizzard's code on 25
  October:** `PlayerVehicleHasComboPoints`, which oUF's class power calls
  unguarded in a vehicle seat, and `C_ClassTalents`, which it indexes on
  `TRAIT_CONFIG_UPDATED` — an event the client calls valid. Compat/Classic.lua
  answers the first from the vehicle's power type and lets the event go where
  the namespace is missing. Neither has been seen in a seat or a spec change.
- **Missed by the check, found by the first login:** `SetRolesets`. It is a
  widget method, and the check looked up functions. See below.

**The aura rows are ours where the container is refused.** `Spawn` already
asked for the container through `pcall`, because Forever was missing parts of
the surface; a refusal now builds the row out of plain buttons in
`Layouts/Auras.lua` instead of leaving the frame without auras. The decision
is the refusal, not the client's name. Each button is cut by
`PostCreateButton` and packed by `Umbra:AuraPerRow`, so it is the same
geometry as a container's and as the preview's stand-ins. What the container
did for us is done in Lua: the underline takes its color from
`oUF.colors.dispel` by `dispelName`, the countdown is a label on a 0.2 s
timer, and right-click cancels a buff through `CancelUnitBuff` out of combat.
Every value that decides something is asked whether it is hidden first, so
if Mists ever switches secret values on, a hidden count or duration leaves
that part blank instead of throwing. `/uuf dev check` says which rows the
frames are standing on.

**`GetUnitChargedPowerPoints` is answered in `Compat/Classic.lua`.** oUF reads
combo points as `UnitPower(unit, ComboPoints), GetUnitChargedPowerPoints(unit)`,
and the second call would throw on every point gained. Nil is Retail's answer
for a unit with no charged points. Nothing of Blizzard's on that client calls
it, so our global cannot reach their code.

**`SetRolesets` is answered there too**, and it cost the whole layout on
the first login: `ouf.lua:853: attempt to call a nil value` in `Spawn`, on
the first frame built, so `oUF:Factory` stopped and no frame came up. oUF
tags every frame and header it builds with a roleset, and every Blizzard
frame it puts away. Rolesets are Midnight's rules for what an addon may do to
a frame; Mists has none, so the first answer was a method that did nothing.

**That was half wrong**, and the next login showed which half: Blizzard's
player frame stood beside Umbra's, frozen. oUF 14 hides Blizzard's frames
with `SetRolesets('alwaysBlocked')` and nothing else — Midnight stops drawing
a blocked frame — so a method that ignores the roleset leaves them on screen
with their events taken away. `alwaysBlocked` now does what oUF did before
Midnight: hide, reparent to a frame that is never shown, and hook `SetParent`
so nothing puts it back. A frame whose container was already put away is only
hidden. `unitFrames` still does nothing. It goes on the Frame and Button
method tables, the only two types oUF calls it on, and only where missing.

**And unknown events are let go of before oUF tries them.** The second
login reported `Attempt to register unknown event "UNIT_POWER_POINT_CHARGE"`
from the class power element on a monk. oUF survives that on its own — it
tries an event under `xpcall` and registers nothing when it fails — but it
hands the failure to the error handler on the way, on every login and every
change of specialisation. `Umbra.GuardUnknownEvents` in `Compat/Classic.lua`
fronts each frame's `RegisterEvent` from the style, which runs before oUF
enables any element, and asks `C_EventUtils.IsEventValid` first. Checking
every event name in oUF and Umbra against the client's documentation found
one more, `HONOR_LEVEL_UPDATE`, in the PvP indicator Umbra does not use.

The lesson for the next client: a check against the API documentation has to
look up the **methods** called on widgets and the **events** registered, not
only the functions. A second
sweep did, comparing every `:Method(` in oUF and Umbra against the documented
names and against every function Blizzard's own code defines on that client;
everything else it turned up is defined by oUF itself.

**What oUF's class power row does not know about Mists stays empty**, and that
is oUF's reading of the classes, not the client's:

- Chi is read for Windwalker only; on Mists every monk has it.
- Eclipse, Shadow Orbs, Burning Embers and Demonic Fury have no reader at all.
- Combo points live on the target on Mists. Whether `UnitPower('player',
  ComboPoints)` answers there is the first thing to look at on a rogue.

**To look at first, in the client:**

1. `/dump (select(4, GetBuildInfo()))` — the TOC says `50504`, taken from the
   build number rather than read off a client.
2. `/uuf dev check`: `Mists`, `compat: Mists`, and `aura rows: our own`.
3. `/uuf dev test` and `/uuf layout classic` / `modern`: both rows turn round.
4. A buff with a countdown, a stacking one, a dispellable debuff on a party
   member, and a right-click out of combat.
5. `/uuf dev header` in a party.
6. Combo points on a rogue, Holy Power on a paladin.

**Measured on 26 September 2026**, on a monk:

- The frames build and draw, Blizzard's own are gone, and the aura rows are
  ours and fill: countdowns in seconds and minutes, stack counts, the
  underline. Chi showed two of four on the player frame.
- **`/uuf dev header`, solo: the secure header works on Mists.** `header:
  created`, `children: 1, configured: 1`, and the child reports
  `umbraProbeRan: yes`, `unit attribute: player`, `styled as: party` — the
  step the Forever beta could not take. Both drivers registered and answered: hidden by
  `[group:raid]`, back on solo and party. The child read `shown: false`,
  which solo says nothing. **Still open:** a real party — four members
  sorted, and a change of roster during a fight.
- Still open as well: right-click to cancel a buff, combo points, and the
  interface number read off the client rather than taken from the build.

### Anniversary

The Anniversary realms run **Burning Crusade Classic, 2.5.6.69795** (Blizzard's
`classic_anniversary` branch, 12 September 2026), with
`WOW_PROJECT_BURNING_CRUSADE_CLASSIC`, TOC suffix `_TBC`, installed under
`_anniversary_`.

**It lacks exactly what Mists lacks.** The same sweep — functions, widget
methods, events and `C_` namespaces, against the client's generated API
documentation and every function Blizzard's own code defines — came back
identical for both branches, line for line. Two cross-checks, because an
identical answer is also what a sweep that read the wrong tree would give:
the two branches differ in 2,966 files, and a spot check of the functions
this rests on (`CreateUnitHealPredictionCalculator`, `IsEventValid`,
`UnitGetTotalAbsorbs`, `CurveConstants.ScaleTo100`, `PartyMemberFramePool`
and more) finds each in both. Blizzard's unit frame TOC for the Classic
family loads `PartyFrame` and the rest for every flavour, TBC included.

So `Compat/Mists.lua` became `Compat/Classic.lua`, gated on any client that
is not Mainline, and both Classic TOCs load it.

What Burning Crusade has no use for stays empty rather than being built
around: no boss units, and oUF reads Holy Power, Chi and Soul Shards off
power types that are zero there, so only combo points fill the pip row.

**Measured on 26 September 2026**, on an Affliction warlock with a
voidwalker: the frames build with no Lua error, Blizzard's own are gone, and
`/uuf dev check` read `TBC Anniversary (interface 20506)` — so the TOC's
number is the client's — with `aura rows: our own, on 6 frames` and the
compatibility file run through. `issecretvalue` exists and hides nothing:
health, percentages and every tag read in the clear. Player, pet and target
portraits load as models. The class power row reads `0 of 10 pips` under
`Gebrechen (spec 1)` — so `GetSpecialization` answers on this client too,
and a warlock simply has nothing to fill it with. The compat line named the
file after the client, `TBC.lua ran`, for a file called `Classic.lua`; the
two are reported apart now. **Still open:** a party, combo points, and
right-click to cancel a buff.

### Classic Era

**Classic Era 1.15.9.69722** (Blizzard's `classic_era` branch, 12 September
2026), `WOW_PROJECT_CLASSIC`, TOC suffix `_Vanilla`, installed under
`_classic_era_`. The same sweep gave the same answer as Mists and Anniversary,
line for line, and the same spot check found every function this rests on;
Blizzard's Classic unit frame TOC loads `PartyFrame` for Vanilla as well. So
Era needed a TOC, a flag and an installer flavour, and nothing else:
`Compat/Classic.lua` answers it as it answers the other two.

Era has no class resource the pip row reads except combo points, no boss
units and no absorbs to speak of, so all of those stay empty.

**Measured on 26 September 2026**, on a warlock with a pet: `Classic Era
(interface 11509)` — the TOC's number is the client's — `compat: Era —
Classic.lua ran`, `aura rows: our own, on 6 frames`, and every value and tag
in the clear. Player, pet, target and target-of-target portraits load as
models. One oddity worth knowing: the class power line read `Gebrechen
(spec 1)` on a client that has no specialisations, so `GetSpecialization`
answers there and names the first tree. Nothing here decides anything on it.
**Still open:** a party, combo points, right-click to cancel a buff.

---

## Working on it

**Installing:** `.\tools\install.ps1` mirrors the checkout into the AddOns
folder under the name the client expects, fetches oUF when missing, and writes
the commit it built from as the version. The WoW path is remembered after the
first run.

**When `/reload` is enough:** for Lua changes. TOC changes — icon, version,
interface, file list — need a full client restart.

**Releasing.** A tag — any tag — triggers `.github/workflows/release.yml`,
which runs the BigWigs packager. Measured on the `0.1` tag: it builds **one**
package carrying both TOC files, not one per flavor, and writes a
`release.json` beside it naming every interface they answer for, which is what
an addon manager reads to pick. It also decides the GitHub release type
itself and **clears a prerelease flag set beforehand**, so `gh release edit
<tag> --prerelease` belongs after the run, not before it.

**Where it goes: GitHub, CurseForge and Wago.** The TOCs name the CurseForge
project in `X-Curse-Project-ID` and the Wago one in `X-Wago-ID`, and each
site's token is a repository secret, `CF_API_KEY` and `WAGO_API_TOKEN`. Up to
0.9 the TOCs carried no Wago ID and the secret was not set, so the tag runs
reached GitHub and CurseForge only — and not one of them said so, because the
packager skips a site it holds no token for and stays green. The workflow
now stops before uploading anything when a token is missing. A tag that is
already out goes to Wago alone with `gh workflow run release.yml -f
tag=<tag>`: that run builds the tag again and hands the packager Wago's token
and nothing else, so CurseForge and the GitHub release are left as they are.

**The notes are the newest changelog section, and only that.** The workflow
cuts the first `## ` section of `CHANGELOG.md` into `RELEASE_NOTES.md`, which
is what `.pkgmeta` hands the packager for the GitHub release body, CurseForge
and Wago; the zip keeps the whole `CHANGELOG.md`. So the section for a release
goes at the top, headed `## <tag> — <date>`, before the tag is pushed — the
workflow stops if the top section names any other version. 0.4.1 was released
before this and carried every section back to 0.1.

The pictures in `docs/curseforge.md` come from the repository at a tag, so
they move to the new tag in a commit of their own before the release, and
the description is pasted into CurseForge and into Wago once the tag is
out — before that, the links point at a tag that does not exist yet. Wago
started out with the README instead, which it took from GitHub: its
pictures are relative paths, which point nowhere off GitHub, so not one of
them showed there (8 November 2026). An absolute link into the repository
loads on Wago's page, SVG included. A picture added after its release is
linked at the commit that added it, which never moves either, until the next
release moves every link to its tag (`forever-windows.png`, 11 November
2026).

**Checking before shipping:** syntax can be checked without the client;
semantics cannot. Luacheck runs in CI.

**Acceptance belongs inside an instance.** The open world proves little, even
though hidden values apply there too, because encounters, Mythic+ and PvP add
further restrictions.

**Colors and metrics** live in `Core/Defaults.lua`, and the `forever` palette
and the code that switches to it in `Core/Theme.lua`. A frame configuration
overrides any layout value through its metatable.

**Where things are.** `Layouts/Widgets.lua` holds the surfaces every frame is
built from and writes down the geometry rule; `Layouts/Tags.lua` the tags;
`Layouts/Auras.lua` the aura containers; `Layouts/Shared.lua` the style that
assembles them.

**Read the error log first.** `!BugGrabber.lua` under
`WTF/Account/<id>/SavedVariables/` holds every captured fault with its file,
its line, its locals and its whole stack, and it survives the session. One
reading of it settled a question that two rounds of reasoning had got wrong in
two different directions — and it can be read from outside the game, which
matters on the day the game is the thing that is broken.

**Look rather than reason.** The most expensive mistakes here came from
plausible assumptions about the API. What helps: reading the oUF source under
`Libs/oUF`, looking at how working addons call an API, and sampling screenshots
pixel by pixel instead of estimating colors.
