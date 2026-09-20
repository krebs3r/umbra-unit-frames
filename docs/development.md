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

Done: the project foundation, and the player and target frames, verified
inside an instance under the restricted-value regime with error capture
installed.

Three of the six design principles are implemented — class color at the edge,
the portrait column, power as a hairline. Alongside them: player, target and
pet frames, the class-power row, a cast bar, a frame mover (`/uuf unlock`), an
addon-list icon and packaging.

The three harder principles are open: auras with an underline, hatched
absorbs with ghosted incoming healing, and range shown through fading.

---

## What the client actually does

Several of these contradict the patch notes and were established by testing.

### Hidden values reach further than documented

`UnitHealth` and `UnitHealthMax` are hidden from addons **in the open world**,
not only inside instances, Mythic+ and PvP. Arithmetic, comparison, `tostring`
and `string.format` on a hidden value all throw.

### What still works

- `FontString:SetFormattedText` **renders** hidden values. Displaying is
  allowed; reading is not.
- `StatusBar:SetValue` and `SetMinMaxValues` accept hidden numbers.
- `SetStatusBarColor` accepts a hidden color, such as the one
  `C_ClassColor.GetClassColor` returns for a hidden class. `SetColorTexture`
  and `SetVertexColor` carry no such guarantee, which is why every surface in
  Umbra that shows class color is a StatusBar rather than a texture.
- `UnitHealthPercent(unit, true, CurveConstants.ScaleTo100)` is **not** hidden.
  The client deliberately hands out a coarse percentage.
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
- `oUF.colors.power` comes from the client's `PowerBarColor`; with
  `element.colorPowerAtlas = true` the bar uses Blizzard's own textures.
- `oUF:Factory(func)` runs at `PLAYER_LOGIN`, `frame:UpdateTags()` forces a tag
  refresh, and `oUF.objects` lists every frame.
- The addon metadata namespace is `C_AddOns`, plural.

### Relevant to auras

`SecureAuraHeaderTemplate` has been removed. Auras go through
`CreateFrame('AuraContainer')` with `AuraGroup`s that create their own buttons.
A colored underline per dispel type can probably be built as **one AuraGroup
per dispel type with its own template**; the risk is ordering across groups.
Inside instances the container and its buttons gain forbidden aspects, and the
`initializeFrame` callback runs before that takes effect.

### Relevant to group frames

`loadstring_untainted` is missing on Forever **and** on Retail 12.1. That
affects secure snippets, state drivers, `RunAttribute` and
`initialConfigFunction` — precisely what secure group headers and click-casting
rest on. Every snippet site belongs inside `if loadstring_untainted then … end`
with a static fallback. `Compat/Forever.lua` already exposes
`Umbra.hasSecureSnippets` for this.

---

## Next

### Remaining single frames and auras

**Auras first**, because they are the largest unknown and carry a design
principle. Then focus, target-of-target and boss frames, which are cheap once
the pet frame's pattern exists. Then incoming healing and absorbs through oUF's
health sub-widgets.

Worth doing first: `Layouts/Shared.lua` has grown past 320 lines and holds
everything. Adding auras to it would make it unwieldy.

### Group and raid frames

Secure group header with the `loadstring_untainted` guard, Clique support, and
range fading verified here through oUF's `Range` element — the raid is where it
matters most.

### Configuration

Ace3 is not embedded yet; positions live in a small hand-rolled store in
`Core/Mover.lua`. When that moves to AceDB and AceConfig, the design studio's
profile schema (`schemaVersion: 2`) should become the import format. The studio
still offers `classic|retail` and needs updating to the three real clients
first.

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

**Look rather than reason.** The most expensive mistakes here came from
plausible assumptions about the API. What helps: reading the oUF source under
`Libs/oUF`, looking at how working addons call an API, and sampling screenshots
pixel by pixel instead of estimating colors.
