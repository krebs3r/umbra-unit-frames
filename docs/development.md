# Development notes

Working notes for Umbra Unit Frames: what the client actually does, what is
built, and what comes next. The six design principles in the
[README](../README.md) are the product definition; this file is about making
them work against the API.

## Decisions

1. **Retail and WoW: Forever are one codebase.** Forever runs the Mainline UI
   (`WOW_PROJECT_MAINLINE`, interface 16001, the 12.1.5 API set), not the
   Classic API. Two TOCs, one source tree. Classic Era is out of scope.
2. **oUF as the framework**, embedded through `.pkgmeta` rather than declared
   as a dependency.
3. **MIT licensed.** ShadowedUnitFrames carries no license file, so none of
   its code is used here.
4. **The design adapts to the API**, and the deviations get documented.

## Status

Done: the project foundation, and every single frame — player, target, pet,
target-of-target and the boss column — the first three verified inside an
instance under the restricted-value regime with error capture installed, and **loading and drawing on the Forever beta client** — see
*Forever* for what that run settled.

**The party column is built**, on the client's own secure header, with a
debuff row, a cast bar and a role marker — see *Group and raid frames*. Raid
frames are the next thing on that header.

**On Retail. Not on Forever.** The first `/uuf dev header` on the beta, 22
September 2026, came back in the error log rather than in the report window:
that client's own restricted environment cannot compile the snippet its own
header machinery runs on a new child, so no secure group header works there,
by oUF or by anyone — see *The secure header does not work on Forever*.

All six design principles are implemented — class color at the edge, the
portrait column, power as a hairline, auras with an underline, hatched absorbs
with ghosted incoming healing, and range shown through fading, which arrived
with the group frames it was waiting for. Alongside them: two layout sets, the
class-power row, a cast bar, a frame mover, a switch for Blizzard's own aura
display, one for its group panel, a switch for class-colored health bars, an
addon-list icon and packaging.

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

`/uuf` on its own prints the version and the list.

| | |
| :--- | :--- |
| `layout classic` · `layout modern` | switch the whole arrangement |
| `unlock` · `lock` · `reset` | move frames, per layout set; unlocking shows and fills every frame, and a group column against stand-ins for every slot |
| `auras umbra` · `auras both` | who shows your buffs and debuffs |
| `group umbra` · `group both` | who shows your party: the Umbra column alone, or the client's panel as well |
| `health class` · `health plain` | whether the health bar takes the unit's color too, or leaves it to the edge |
| `dev` | the measurements, listed behind that word |

**The measurements moved behind `/uuf dev` on 21 September 2026.** None of them
changes how anything looks; they report, and the list someone reaches for when
they have forgotten a command should be about the frames.

| | |
| :--- | :--- |
| `dev test` | fill every aura slot with stand-ins, and the health bar's prediction |
| `dev check` | opens a report window: which unit values this client hides, what the class-power row found, and per frame whether the unit's identity is secret and what its portrait could load |
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
the first place.

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
  stack rather than a position of its own.
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

**The duration sits in the middle of the icon square, not of the button.** The
button is taller than the icon by the gap and the line, so anchoring the label
to the button's own centre puts it low, and anchoring it to the top puts it in
the top quarter — measured at y 11..18 against an icon spanning y 6..42, which
is 9.5 pixels too high. The offset is written out from the icon's own size.

**Leave the duration format alone.** An attempt to shorten `24 m` to `24m`
through `CreateSecondsFormatter` was reverted: the function is not a global on
Retail 120100, and the namespaced one took different arguments than assumed, so
the same label came back as `9 Minuten 46 Sekunden`. The client's own default
fits the icon at this size, and guessing at the signature cost two reloads.
Any second attempt starts by reading the client's own callers, not by trying
argument orders.

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

Still to build: raid frames, and Clique support.

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
When that moves to AceDB and AceConfig, the design studio's profile schema
(`schemaVersion: 2`) should become the import format. The studio still offers
`classic|retail` and needs updating to the three real clients first.

### Forever

Forever launches **4 November 2026**. Known beta behaviour: saved variables are
written but never read back, and `/reload UI` is protected while `/reload` is
not.

**The beta client is installed** as of 20 September 2026, under the same root
as Retail: `World of Warcraft\_classic_beta_`, whose `.flavor.info` reads
`wow_classic_beta`, with `WowB.exe`. That is the folder
`.\tools\install.ps1 -Flavor forever` already targets, and `tools/.wowpath`
holds the shared root, so the flavour alone picks the client and neither
overwrites the other.

`Interface\AddOns` does not exist until the client has been started once, so a
first install has to wait for that.

### The secure header does not work on Forever

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
Blizzard's own machinery can. On Forever neither can. The two clients
therefore separate cleanly:

| | Retail 120100 | Forever 16001 |
| :--- | :--- | :--- |
| an addon compiles a snippet | no | no |
| the client compiles its own | yes | **no** |
| secure group header | works | cannot configure a child |

Which settles what `/uuf dev header` was built to ask, and settles it the
wrong way: **no secure group header can work on this client**, by oUF or by
anyone, because what fails is below every layout. A party column on Forever
would have to be fixed frames with no sorting and no in-combat changes — which
is the second addon the header was chosen to avoid being — or wait for the
client to gain the function before it launches on 4 November 2026.

Two things follow for the code as it stands:

- **Solo it does not bite.** The live header spawns with `showSolo` and
  `showPlayer` false and a `party` visibility, so it is hidden and configures
  nothing. The errors above came from the probe, which turns both on to force
  the question. On Forever the column will fail the moment a party is joined,
  not at login.
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
  and it answers correctly here if the function turns up before 4 November.
  In combat it is postponed rather than decided — unregistering a driver
  touches a protected frame — and the question is asked again the next time
  the header is shown.

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
  the check keys off.
- **Saved variables really are written and never read**, and the two halves of
  that are worth keeping apart, because only one of them is broken.
  `/uuf layout classic` followed by `/reload` came back as `modern`. The file
  on disk says why: `WTF/Account/<id>/SavedVariables/UmbraUnitFrames.lua`, and
  its `.bak` beside it, are one generation apart and read

  ```
  .bak      layout = "classic", debug = true, positions for both sets
  current   layout = "modern",  no debug,     positions for modern only
  ```

  So the **write is correct**. What the reload does not do is read it back:
  `ADDON_LOADED` sees an empty table, Umbra fills in its defaults, and the
  next save writes those defaults over the real settings. Every reload
  destroys a generation, and the `.bak` is the only thing still holding the
  previous one.

  Nothing on this side can fix that, and nothing should try. A store of our
  own — custom CVars, say — would be a second mechanism carried forever for a
  beta that cannot load files every addon depends on. Worth revisiting only if
  it is still broken near the 4 November launch.

That last one broke the one thing it most needed to work. `/uuf dev debug` exists
to report what the build refused, the build happens at `PLAYER_LOGIN`, and the
switch was saved so that it would already be on by then — which on this client
it never is. **So the lines are buffered instead**: `Umbra:Debug` writes every
line down whether or not anyone is listening, and switching the flag on hands
over what it missed. That asks nothing of the client and works the same on
both.

- **`secure snippets: unavailable`.** `loadstring_untainted` is missing here,
  as the record said, and `Umbra.hasSecureSnippets` is false by measurement
  rather than by a file that failed to load. What that was taken to mean for
  group frames was wrong, and is corrected under *Relevant to group frames* —
  the header on Retail works without it. Whether the same holds on Forever is
  one `/uuf dev header` away and has not been run there yet.

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

**Checking before shipping:** syntax can be checked without the client;
semantics cannot. Luacheck runs in CI.

**Acceptance belongs inside an instance.** The open world proves little, even
though hidden values apply there too, because encounters, Mythic+ and PvP add
further restrictions.

**Colors and metrics** all live in `Core/Defaults.lua`. A frame configuration
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
