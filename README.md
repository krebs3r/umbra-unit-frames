# Umbra Unit Frames

**Your game. Front and center.**

![World of Warcraft · Unit Frames](https://img.shields.io/badge/World_of_Warcraft-Unit_Frames-75DCC4?style=flat-square&labelColor=15191F)
![Focus · Classic & Retail](https://img.shields.io/badge/Focus-Classic_%26_Retail-C9B888?style=flat-square&labelColor=15191F)

**Umbra preserves the idea, not every old design decision.**

A project for modern, readable unit frames in World of Warcraft Classic and Retail. Inspired by ShadowedUnitFrames, with a visual identity of its own: class-colored edges, rectangular character portraits beside the bars, and information right where you need it.

[The idea](#the-idea) · [Design principles](#design-principles) · [Classic and Retail](#classic-and-retail) · [Contributing](#contributing)

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
| **Class color at the edge** | A **3-pixel edge** and the character's name carry the class color. The health bar stays **neutral green** by default. Class identity and health each have a distinct visual role. |
| **A dedicated portrait column** | A narrow, **rectangular character portrait** sits to the left of the name and bars—including on the target frame. Subtle class tinting replaces circular medallions, glowing portrait rings, and images behind the numbers. |
| **Resources as a hairline** | Mana, energy, and rage use a thin line rather than a second dominant bar. Health remains the primary information. |
| **Auras with an underline** | A slim colored line beneath each icon replaces a prominent full border. Personal and important effects should be easy to identify without cluttering the grid. |
| **Distinct shields and healing** | Hatching indicates absorbs; a light, translucent segment represents incoming healing. Both should remain clearly distinguishable from current health. |
| **Range through fading** | Out-of-range units fade together with their portraits. Class color and character identity remain intact rather than being replaced by a grayscale filter. |

**Accent color belongs to the interface. Class color belongs to the unit. The health bar belongs to health.**

## Classic and Retail

Umbra is aimed at **World of Warcraft Classic and Retail**. The goal is a shared visual language and consistent interaction—from a small Classic party to a Retail raid.

Differences between clients should be handled explicitly. Shared layout and profile functionality belong in a common core; differences in aura APIs, class resources, or protected UI functionality require targeted adaptations.

Actual support is determined by documented client testing and the compatibility information for each addon version.

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

## License

A license for the project's original code has not yet been selected and will be documented separately. The origin and licensing terms of any incorporated third-party components must be considered independently.

---

**UMBRA UNIT FRAMES**  
*Less clutter. More clarity. Your game. Front and center.*
