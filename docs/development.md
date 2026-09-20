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
installed.

Four of the six design principles are implemented — class color at the edge,
the portrait column, power as a hairline, and auras with an underline.
Alongside them: two layout sets, the class-power row, a cast bar, a frame
mover, a switch for Blizzard's own aura display, an addon-list icon and
packaging.

The aura underline is **verified in the open world**, geometry and color both,
by sampling screenshots pixel by pixel — the measurements are under *Auras*.
What is still open there is the same check **inside an instance**, where the
container and its buttons gain forbidden aspects.

Two principles are open: hatched absorbs with ghosted incoming healing, and
range shown through fading.

### Slash commands

`/uuf` on its own prints the version and the list.

| | |
| :--- | :--- |
| `layout classic` · `layout modern` | switch the whole arrangement |
| `unlock` · `lock` · `reset` | move frames, per layout set |
| `blizzard` | hide or restore Blizzard's buff and debuff frames |
| `check` | which unit values this client hides |
| `debug` | print what was refused while building |

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
| Pet | above the player | below everything |
| Buffs | below, nearest the frame | above the frame |
| Debuffs | below, outside the buffs | below the castbar |

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

### Frames reach past their own box

A frame is not the box `FrameHeight` answers for. A castbar hangs below it and
both aura rows hang below that, so anything placed underneath has to clear all
of it. `Umbra:FrameExtent` answers for that distance, per set.

Writing the offset down as a number is what went wrong first: the pet frame's
default position was correct until a debuff row appeared under the player's
castbar and landed on top of it, overlapping by 24 units. Deriving it fixed the
collision, but the pet then kept being pushed further down as the rows below
the player grew.

In `classic` **nothing is placed above a frame** and the pet sits there
instead, the way ShadowedUnitFrames arranges it: above the box there is no
castbar and no aura row to clear, so adding a row below the player does not
move the pet at all. In `modern` the buffs take that space and the pet goes to
the bottom, where it is furthest from the frame and moves whenever a row below
grows.

Stacking two rows on one side is safe either way, because the block heights are
reserved from the aura counts rather than from what the unit happens to have
on it, so the outer row can take a fixed offset from the inner one.

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
The measured packing matches the computed one — 8 icons per row at a frame
width of 210 — but that has only been checked at this one width.

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

The right edge does not line up and cannot: seven icons of 26 with 2 between
them come to 194 against a frame width of 210. The row is left-aligned, so the
slack is all on the right.

`Label` clears the anchor oUF already set before placing the label. A second
point on a font string stretches it rather than moving it, which is what made
the duration look left-aligned when it was in fact centered.

**The icon size is set by the duration label, not the other way round.** At 22
the label measured 39 pixels wide against a 42 pixel icon, filling it edge to
edge, and two neighbouring labels read as one run of text. Both numbers came
off a screenshot; the label was centered to within half a pixel, so the fix was
width, not position. 26 with an 11 point font leaves margin, and still fits
seven icons to a row at a frame width of 210.

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

### Relevant to group frames

`loadstring_untainted` is missing on Forever **and** on Retail 12.1. That
affects secure snippets, state drivers, `RunAttribute` and
`initialConfigFunction` — precisely what secure group headers and click-casting
rest on. Every snippet site belongs inside `if loadstring_untainted then … end`
with a static fallback. `Compat/Forever.lua` already exposes
`Umbra.hasSecureSnippets` for this.

---

## Next

### Waiting to be looked at

Written and installed, never confirmed in the client. Each one degrades
quietly rather than erroring, which is why none of them announced itself.

1. **Auras inside an instance.** The container and its buttons gain forbidden
   aspects there, and `initializeFrame` runs before that takes effect. This is
   the one that matters; everything else about auras is measured and holds.
2. **Turning an aura row round on a layout switch.** `/uuf layout` re-anchors
   the containers and calls `SetFlowLayoutAnchorPoint` and
   `SetFlowLayoutGrowthDirection` again, both in `pcall`. If a row lands on
   the right side of the frame but fills the wrong way, those calls do not
   take after creation, and the containers have to be rebuilt on a switch
   instead of turned.
3. **`/uuf blizzard`.** Whether Edit Mode puts `BuffFrame` and `DebuffFrame`
   back, and whether those two names survived the 12.0 rework. `/uuf debug`
   reports a name it cannot find.
4. **Power colors without the atlas.** Rage, energy and focus now take their
   flat `PowerBarColor` instead of a texture. Only mana has been looked at.

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
never shown, behind `/uuf blizzard`. Not `Hide`, which the next thing that
shows them undoes, and not `UnregisterAllEvents`, which cannot be undone at
all. Reparenting leaves their logic running and is reversible.

Unverified: whether Edit Mode puts them back, and whether the two names are
still the right ones after the 12.0 rework.

### Configuration

Ace3 is not embedded yet. Positions live in a small hand-rolled store in
`Core/Mover.lua`, keyed by layout set, and the set itself is one saved string.
When that moves to AceDB and AceConfig, the design studio's profile schema
(`schemaVersion: 2`) should become the import format. The studio still offers
`classic|retail` and needs updating to the three real clients first.

The aura rows do not fill the frame width: seven icons of 26 with 2 between
them come to 194 against 210, and the row is left-aligned so the slack sits on
the right. Sizes that divide evenly would close it, at the cost of an icon
size nobody picked for its own sake.

### Forever

Forever launches **4 November 2026**. Known beta behaviour: saved variables are
written but never read back, and `/reload UI` is protected while `/reload` is
not.

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
