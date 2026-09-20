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

Done: the project foundation, and the player, target and pet frames, verified
inside an instance under the restricted-value regime with error capture
installed, and **loading and drawing on the Forever beta client** — see
*Forever* for what that run settled.

Five of the six design principles are implemented — class color at the edge,
the portrait column, power as a hairline, auras with an underline, and
hatched absorbs with ghosted incoming healing. Alongside them: two layout
sets, the class-power row, a cast bar, a frame mover, a switch for Blizzard's
own aura display, an addon-list icon and packaging.

The aura underline is **verified in the open world and inside an instance**,
geometry and color both, by sampling screenshots pixel by pixel — the
measurements are under *Auras*. Nothing about the containers is refused where
they gain forbidden aspects; `/uuf debug` came back silent on a build run from
inside *Der Flammenschlund*.

One principle is open: range shown through fading. The absorbs have been seen
drawing in an instance, on both the player and the target frame, but only as
stand-ins — see *Waiting to be looked at* for what that does and does not
settle.

### Slash commands

`/uuf` on its own prints the version and the list.

| | |
| :--- | :--- |
| `layout classic` · `layout modern` | switch the whole arrangement |
| `unlock` · `lock` · `reset` | move frames, per layout set; unlocking shows and fills every frame |
| `test` | fill every aura slot with stand-ins, and the health bar's prediction |
| `auras umbra` · `auras both` | who shows your buffs and debuffs |
| `check` | which unit values this client hides, and what the class-power row found |
| `debug` | print what was refused while building, including before it was on |

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
other way round from what this file claimed until the `/uuf check` run of
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

Only the player frame carries a `'pet'` entry, through `ownsPet`; on the
target frame the same list costs nothing, because `Umbra:StackHeight` answers
nil for anything that frame does not have.

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
  specialization is chosen. `/uuf check` names the spec for exactly that
  reason: measured on a level 3 monk it answered `0 of 10 pips`, which is
  correct and looks like a fault until the spec is named beside it. That
  character reports **index 5**, which is none of the three monk specs, and
  `C_SpecializationInfo.GetSpecializationInfo(5)` answers for it with an id
  and an **empty name** rather than nothing at all — so a nil check alone
  prints a blank and calls it a specialization.
- `oUF:Factory(func)` runs at `PLAYER_LOGIN`, `frame:UpdateTags()` forces a tag
  refresh, and `oUF.objects` lists every frame.
- The addon metadata namespace is `C_AddOns`, plural.

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
reserved for eight, while `/uuf test` had been showing eight all along. The
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

That was the one thing about the auras that had never been looked at with
real data — the geometry, the colors and the side after a switch all had
been.

**A full row can be looked at without waiting for one.** `/uuf test` fills
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

**`/uuf test` fills these too.** An absorb takes someone else to put on you,
so it can be waited for even less than a full aura row. The stand-in amounts
are the bars' own scale — `SetMinMaxValues(0, 1)` and a plain fraction —
which says the same thing to a bar and needs no arithmetic on a hidden value:
`max * 0.18` would throw inside an instance, which is exactly where this
wants looking at. Where they start is still the real health, and that is the
honest picture. oUF rewrites all three on every health tick, so the stand-ins
go back on through the element's own `PostUpdate` rather than being written
once and lost on the next tick.

### Relevant to group frames

`loadstring_untainted` is missing on Forever **and** on Retail 12.1. That
affects secure snippets, state drivers, `RunAttribute` and
`initialConfigFunction` — precisely what secure group headers and click-casting
rest on. Every snippet site belongs inside `if Umbra.hasSecureSnippets then …
end` with a static fallback.

That flag is set in `Core/Init.lua` and reported by `/uuf check`. It used to be
set in `Compat/Forever.lua`, which returns early on anything but Forever and is
not listed in the Retail TOC at all — so on Retail it was nil, which behaves
like false and happens to be right, but by accident rather than by
measurement. A flag that decides whether a whole class of frames can exist
should not be true or false depending on which file loaded.

---

## Next

### Waiting to be looked at

Written and installed, never confirmed in the client. Each one degrades
quietly rather than erroring, which is why none of them announced itself.

1. **Which way a row fills after a layout switch.** The *side* is confirmed:
   `/uuf layout` moved the real containers from under the frame to above it
   without a reload, in an instance. What that does not show is the fill
   direction, because eight fit in a row and the character carried six. It
   takes a ninth aura to see whether `SetFlowLayoutAnchorPoint` and
   `SetFlowLayoutGrowthDirection` take after creation, or whether the
   containers have to be rebuilt on a switch instead of turned. The stand-ins
   prove nothing here: Umbra packs those itself.
2. **`/uuf auras both`.** Whether Edit Mode puts `BuffFrame` and `DebuffFrame`
   back. The names themselves are settled on Retail — see *Blizzard's own aura
   display* — so what is left is one trip through Edit Mode with the frames
   concealed. `/uuf debug` reporting a name it cannot find is Forever.
3. **Energy.** Rage and focus are confirmed — focus measured on 20 September
   2026 at `239/138/85` on the hairline against the client's `255/128/64` with
   the gloss over it, and the percentage above it orange at `195/128/97`
   rather than the `141/151/171` it would fall back to. Only energy is left,
   which wants a rogue, a monk or a druid in cat form.
4. **Absorbs and incoming healing, from real data.** The stand-ins were seen
   in *Thron der Gezeiten* on 20 September 2026 and drew — including on the
   target frame, so the anchors to the health fill are accepted inside an
   instance, on a unit whose health is hidden. That is the thing this design
   rests on, and it holds.

   What has still not been seen is a **real** absorb or a real incoming heal.
   Nothing on that run produced one: a hunter carries no absorb of its own,
   and incoming-heal prediction needs a cast heal in flight rather than an
   instant self-heal. So the remaining question is only whether oUF's values
   arrive, not whether the surfaces work. A shielded tank in the same group,
   watched on the target frame, answers it.
5. **3D portraits on an enemy frame inside an instance.** Seen empty there and
   filled outside, on the same run. The frame, its ground and its tint are
   explicitly placed and do not care what the unit is, so this has the shape
   of a restricted value rather than of a broken anchor: oUF chooses between
   the unit's model and a question mark on `UnitIsConnected and
   UnitIsVisible`, then calls `SetUnit`. `/uuf check` now reports both of
   those and the loaded model file, per frame — a model of nil with a
   readable `UnitIsVisible` means `SetUnit` was reached and answered with
   nothing, which is a different fault from a branch that never took.

Settled since this list was written: auras inside an instance, the side a row
lands on after a switch, and the frame positions in both sets.

### Remaining single frames

Then focus, target-of-target and boss frames, which are cheap once the pet
frame's pattern exists. Then incoming healing and absorbs through oUF's health
sub-widgets.

### Group and raid frames

Secure group header with the `loadstring_untainted` guard, Clique support, and
range fading verified here through oUF's `Range` element — the raid is where it
matters most.

### Blizzard's own aura display

`Core/Blizzard.lua` parents `BuffFrame` and `DebuffFrame` to a frame that is
never shown, behind `/uuf auras`. Not `Hide`, which the next thing that
shows them undoes, and not `UnregisterAllEvents`, which cannot be undone at
all. Reparenting leaves their logic running and is reversible.

**Both names are still right on Retail 12.x**, established without the client
by reading addons on this machine that reach the same two frames:
EnhanceQoLSkinner hides `_G.BuffFrame` and `_G.DebuffFrame` by those names,
and EnhanceQoL's Edit Mode library lists both as Edit Mode systems and finds
a `.Selection` on each. So `/uuf debug` reporting a name it cannot find is a
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

That last one broke the one thing it most needed to work. `/uuf debug` exists
to report what the build refused, the build happens at `PLAYER_LOGIN`, and the
switch was saved so that it would already be on by then — which on this client
it never is. **So the lines are buffered instead**: `Umbra:Debug` writes every
line down whether or not anyone is listening, and switching the flag on hands
over what it missed. That asks nothing of the client and works the same on
both.

- **`secure snippets: unavailable`.** `loadstring_untainted` is missing here,
  as the record said. So group frames on this client need the static fallback,
  and `Umbra.hasSecureSnippets` is false by measurement rather than by a file
  that failed to load.

**One thing does not add up yet.** `/uuf debug` answered `nothing has been
refused since login` on a run where `secure snippets: unavailable` — but that
is exactly the condition under which `Compat/Forever.lua` calls `Umbra:Debug`
two lines further down. The buffer should have held at least that one line.

So either the compat file is not running to the end, or the buffer is not
being filled, and until that is told apart an empty buffer proves nothing
about what the build refused. `/uuf check` now reports `compat:` for exactly
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

**Look rather than reason.** The most expensive mistakes here came from
plausible assumptions about the API. What helps: reading the oUF source under
`Libs/oUF`, looking at how working addons call an API, and sampling screenshots
pixel by pixel instead of estimating colors.
