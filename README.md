# Umbra Unit Frames

**Your game. Front and center.**

![World of Warcraft · Unit Frames](https://img.shields.io/badge/World_of_Warcraft-Unit_Frames-75DCC4?style=flat-square&labelColor=15191F)
![Focus · Retail & Forever](https://img.shields.io/badge/Focus-Retail_%26_Forever-C9B888?style=flat-square&labelColor=15191F)

**Umbra preserves the idea, not every old design decision.**

A project for modern, readable unit frames in World of Warcraft Retail and WoW: Forever. Inspired by ShadowedUnitFrames, with a visual identity of its own: class-colored edges, rectangular character portraits beside the bars, and information right where you need it.

[The idea](#the-idea) · [Design principles](#design-principles) · [Supported clients](#supported-clients) · [Contributing](#contributing)

---

## The idea

Your character, your target, and your group should be the focus. The interface should help you understand their status — not compete for your attention.

Umbra brings together compact unit frames, a clear information hierarchy, and restrained styling. Rather than replacing the entire user interface, it focuses on player, target, focus, party, and raid frames.

> **Familiar to use. Distinct by design.**

### Why “Umbra”?

*Umbra* refers to the [dark inner region of a shadow](https://science.nasa.gov/moon/eclipses/). The name acknowledges the project's visual inspiration without simply repeating “Shadowed.”

It also captures the thinking behind the project: **The interface steps back. Your game stays in focus.**

## Design principles

Color, shape, and placement should make different kinds of information easy to distinguish. These six principles define Umbra's visual direction.

| Principle | Approach and purpose |
| :--- | :--- |
| **Class color at the edge** | A **3-pixel edge** and the character's name carry the class color. The health bar stays **neutral green** by default, and `/uuf health class` gives it the unit's color as well for anyone who would rather have it there. Class identity and health each have a distinct visual role. |
| **A dedicated portrait column** | A narrow, **rectangular character portrait** sits to the left of the name and bars—including on the target frame. Subtle class tinting replaces circular medallions, glowing portrait rings, and images behind the numbers. |
| **Resources as a hairline** | Mana, energy, and rage use a thin line rather than a second dominant bar. Health remains the primary information. |
| **Auras with an underline** | A slim colored line beneath each icon replaces a prominent full border. Personal and important effects should be easy to identify without cluttering the grid. |
| **Distinct shields and healing** | Hatching indicates absorbs; a light, translucent segment represents incoming healing. Both should remain clearly distinguishable from current health. |
| **Range through fading** | Out-of-range units fade together with their portraits. Class color and character identity remain intact rather than being replaced by a grayscale filter. |

**Accent color belongs to the interface. Class color belongs to the unit. The health bar belongs to health.**

## Supported clients

Umbra targets **Retail** and **WoW: Forever**. These are one codebase, because Forever is not a Classic client: it runs the Mainline UI architecture on Vanilla content.

| | Retail (Midnight) | WoW: Forever | Classic Era |
| :--- | :--- | :--- | :--- |
| Interface | `120100`, `120105` | `16001` | `11509` |
| `WOW_PROJECT_ID` | Mainline | Mainline | Classic |
| API surface | 12.1.5 | 12.1.5, minus parts | Vanilla |
| Secret Values | yes | yes | no |
| TOC suffix | `_Mainline` | `_Camelot` | `_Vanilla` |
| Umbra support | planned | planned | not planned |

The old Classic globals—`UnitAura`, `GetSpellInfo`, `GetItemInfo`, `CombatLogGetCurrentEventInfo`—do not exist on Forever. Code is written against the Retail API and the handful of Forever deviations live in `Compat/Forever.lua`.

Classic Era would need a second implementation rather than a compatibility layer, and is out of scope.

### What Secret Values change

Since patch 12.0 the client returns opaque values for health, power and aura data inside encounters, Mythic+ runs and PvP matches. An addon may hand such a value to the client for display, but may not read it, compare it, or calculate with it.

This suits Umbra's design better than most: a neutral health bar with class color at the edge never needs to derive a color from a health value, so the bar looks and behaves the same inside an encounter as outside one. Two consequences are visible to you:

- **Health reads as a percentage.** The number itself is not lost—the client can still render a hidden value—but nothing may be *derived* from it. Custom thresholds, or a bar color that shifts as health drops, are not possible while the value is hidden.
- **Auras are drawn through Blizzard's aura containers**, which constrains how freely icons can be arranged.

Actual support is determined by documented client testing and the compatibility information for each addon version.

## Installing

The addon folder is named `UmbraUnitFrames` and the slash command is `/uuf`. An unrelated addon named *Umbra* already exists; the longer name keeps both installable side by side.

### Running from a checkout

Copying the clone directly into `AddOns` does not work, and it fails silently: the addon simply never appears in the list. Two things differ from a released build.

1. **The folder must be named `UmbraUnitFrames`.** WoW looks for `Foo_Mainline.toc` only inside a folder named `Foo`, so a clone directory named `umbra-unit-frames` is never inspected.
2. **`Libs/oUF` is not in the repository.** It is fetched at build time and ignored by git, so a checkout has to provide it.

`tools/install.ps1` handles both. Pass the WoW path once; it is remembered afterwards.

```powershell
.\tools\install.ps1 -WowPath "C:\Games\World of Warcraft"
```

```powershell
.\tools\install.ps1 -Flavor forever
```

Re-run it after every change, then `/reload` in the client. Adding the folder for the first time needs a full client restart, because the addon list is only read at launch.

## Contributing

Feedback, bug reports, and focused improvements are welcome. It is especially helpful to explain **which information a change makes easier to read or understand**.

A bug report should identify the affected frame, selected layout, version, and steps to reproduce the issue.

Please discuss larger changes in an issue first. Document the source and licensing of any code or assets you contribute.

## Credits

ShadowedUnitFrames is the visual inspiration behind Umbra. Thank you to the original authors and the community who have carried this idea through so many versions of WoW.

- [Shadowed / ShadowedUnitFrames](https://github.com/Shadowed/ShadowedUnitFrames)
- [Nevcairiel / ShadowedUnitFrames](https://github.com/Nevcairiel/ShadowedUnitFrames)
- [NoSelph / ShadowedUnitFrames](https://github.com/NoSelph/ShadowedUnitFrames)

Listing these projects does not imply that their code is already included in Umbra. Umbra is an **independent project**, not an official successor to ShadowedUnitFrames, and is not affiliated with Blizzard Entertainment.

The inspiration is visual only. ShadowedUnitFrames carries no license file, which means no permission to reuse its code has been granted—so none of it is used here, and none of it may be contributed.

Umbra is built on [oUF](https://github.com/oUF-wow/oUF) (MIT), which is embedded at build time rather than checked in.

## License

Umbra's own code is [MIT licensed](LICENSE). If this project ever goes quiet, someone else can pick it up—which is precisely what ShadowedUnitFrames could not offer.

Embedded third-party components keep their own terms: oUF is MIT.

---

**UMBRA UNIT FRAMES**  
*Less clutter. More clarity. Your game. Front and center.*
