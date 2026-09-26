# Umbra Unit Frames

**Your game. Front and center.**

Compact, readable unit frames for **World of Warcraft Retail**, **WoW: Forever** and **Mists of Pandaria Classic**. Your class color sits on the edge of the frame, your portrait gets a column of its own, and the numbers you actually read stay the biggest thing on screen.

Inspired by ShadowedUnitFrames — the same idea about what a unit frame is for, with a look of its own.

> **Where it stands.** Everything below is built and in use. There is no options window yet: every setting is a `/uuf` command. Clique is not supported, and raid frames are deliberately Blizzard's — both are said plainly further down rather than left as something this has not got round to.

---

## What a frame is made of

![Umbra Unit Frames — what a frame is made of](https://media.forgecdn.net/attachments/1967/376/frame-anatomy-png.png)

Player, target, pet, boss, party — every frame is built from the same parts, then cut down to what it is for. A class-colored edge. A portrait column. A name. One health bar that owns the frame, and a hairline underneath it for mana, energy or rage.

---

## Six ideas about reading a frame

**Class color at the edge.** A 3-pixel edge and the name carry your class color. The health bar stays a neutral green, so a drop in health reads as a drop in health and nothing else. If you would rather have class color on the bar too, `/uuf health class`.

**A portrait in its own column.** A narrow rectangular portrait sits left of the name and bars — on the target frame as well. No circular medallions, no glowing rings, nothing sitting behind your numbers.

**Resources as a hairline.** Mana, energy and rage run in a thin line instead of a second big bar. Health stays the thing you see first.

**Auras with an underline.** A slim colored line under each icon instead of a thick border around it. Your own effects and the ones that matter still jump out, and the grid stays calm.

**Shields and incoming heals you can tell apart.** Absorbs are drawn as hatching. Incoming healing is a pale, see-through segment. Neither one can be mistaken for health you already have.

**Range by fading.** Someone out of range fades out, portrait and all. They stay recognisably themselves instead of turning into a grey copy.

![Umbra Unit Frames — bar and aura states](https://media.forgecdn.net/attachments/1967/375/bar-states-png.png)

> Accent color belongs to the interface. Class color belongs to the unit. The health bar belongs to health.

---

## What you get

| Frame | What it carries |
| :--- | :--- |
| **Player** | Cast bar, class power (combo points, holy power, runes and the rest), power value, 16 buffs and 8 debuffs |
| **Target** | Cast bar, power value, 8 buffs and 16 debuffs — the other way round, because what *you* put on the target is why you are looking at it |
| **Pet** | Same width so it lines up, but short: no cast bar, no aura rows |
| **Target of target** | One question — is it on the tank or on me — and cut the same way |
| **Boss** | As many as the fight has, each keeping its cast bar |
| **Party** | A column with cast bars, power values, a row of debuffs, the role each member signed up as, and range fading — not on the Forever beta, for a reason the client decides |
| **Raid** | Not yet, and not next — Blizzard's own do the job, class coloring included, and the group header carries them whenever they are wanted |

There is deliberately **no focus frame**. One was built and taken back out: a frame that is empty most of the time is a frame in the way.

![Umbra Unit Frames — the party column](https://media.forgecdn.net/attachments/1967/379/party-column-png.png)

The party column is built on the game's own group header, which means the game creates and sorts the members — in combat as well as out of it.

---

## Two layouts, one command

A layout decides three things at once, because they only make sense together: where the frames sit, which side the aura rows hang on, and whether your pet sits above you or below. Each layout remembers its own dragged positions, so you can set both up and switch freely.

### `modern` — the default

The arrangement Dragonflight introduced. Player and target meet in the lower third, buffs above them, the pet under the cast bar, debuffs under the pet. The party column goes to the left edge.

![Umbra Unit Frames — the modern layout](https://media.forgecdn.net/attachments/1967/378/layout-modern-png.png)

### `classic` — where the player frame used to live

Player and target in the top left, the pet above them, both aura rows below, and the party column hanging under the whole block.

![Umbra Unit Frames — the classic layout](https://media.forgecdn.net/attachments/1967/377/layout-classic-png.png)

The boss column is the same in both — right edge, centred. It is not part of the arrangement you chose; it is something the fight brings.

---

## Commands

There is no options window yet. `/uuf` on its own prints the list, and **every setting takes effect where you stand** — no `/reload`.

| Command | Values | What it does |
| :--- | :--- | :--- |
| `/uuf layout` | `classic`, `modern` | the whole arrangement |
| `/uuf auras` | `umbra`, `both` | who shows your buffs and debuffs |
| `/uuf health` | `class`, `plain` | what colors the health bars |
| `/uuf group` | `umbra`, `both` | whether the game's group manager stays on the left edge |
| `/uuf unlock` | — | drag the frames — all of them, filled out so you can see what you are placing |
| `/uuf lock` | — | put them back to work |
| `/uuf reset` | — | forget this layout's dragged positions |

Type a setting without a value and it tells you what it is on and what the alternatives mean.

Defaults are `modern`, `both`, `plain`, `both` — Blizzard's aura display and group panel stay up until you say otherwise, because that panel carries your raid markers and the way out of a group.

There is also `/uuf dev`, a set of read-only checks that change nothing and print what your client is doing. `/uuf dev test` fills every aura slot with stand-ins so you can judge a layout at its fullest, and `/uuf dev check` gives you most of a good bug report in a window you can copy out of.

---

## Installing

Grab it with your addon manager, or unpack the zip into `Interface\AddOns` yourself.

The folder is named **`UmbraUnitFrames`** and the command is `/uuf`. There is an unrelated addon called *Umbra* — the longer name keeps both installable side by side.

One package covers both supported game versions; you do not need to pick a build.

---

## Which game versions

| | Retail (Midnight) | WoW: Forever | Mists of Pandaria Classic | Classic Era |
| :--- | :--- | :--- | :--- | :--- |
| Supported | yes — tested inside an instance | yes, with two exceptions | new — checked against the client's code, and seen working | new |

The Anniversary realms (Burning Crusade) and Classic Era are supported the same way as Mists.

Forever launches **4 November 2026**, and Umbra already loads and draws on its beta client. Mists is new in this version. Its client carries almost everything Umbra and oUF ask of it; the aura rows are the exception, and Umbra draws those itself there. Eclipse, Shadow Orbs, Burning Embers and Demonic Fury are not shown yet. Classic Era and Anniversary come after Mists.

**The two exceptions on Forever are the client's, not Umbra's.**

*The party column cannot be built there.* That client compiles every secure snippet with `loadstring_untainted`, the function is missing, and the client's own group-header code needs it to finish each child it creates — so the header makes buttons it cannot finish, by Umbra or by any other addon. Umbra notices within two seconds of the column first appearing, hides it, stops asking, and hands Blizzard's group panel back whatever `/uuf group` says. Every other frame is unaffected.

*And it does not remember.* The beta writes its saved variables on exit and never reads them back, so every login and every `/reload` starts from the defaults — your layout and anything you dragged with it. The write is correct; it is the reading that never happens, and no addon can do that part for the client.

Both are being watched rather than worked around: either could be gone by launch, and `/uuf dev header` answers where any given client stands — including one nobody has tested yet. **Retail is untouched by all of this.**

**A word on Secret Values.** Since patch 12.0 the game hides exact health and power numbers inside encounters, Mythic+ and PvP — addons may display them but not read them. Umbra's design happens to suit that well: a neutral health bar with class color on the edge never needed to work out a color from your health, so your frames look and behave the same inside a boss fight as outside one. What you will notice is that health reads as a percentage while the fight hides the number.

---

## About the pictures above

These sheets are **drawings, not screenshots.** They are generated from the same measurements the addon lays the frames out with, so the sizes, spacing and colors you see are the real ones. What they cannot show you is anything the game decides at the moment of play: the fonts are your client's, the spell art in an icon is the real spell's, and a portrait is a live 3D model rather than the silhouette drawn here.

---

## Credits

ShadowedUnitFrames is the visual inspiration behind Umbra, and thank you to the authors and the community who carried that idea through so many versions of WoW.

Umbra is an **independent addon**, not an official successor to ShadowedUnitFrames, and is not affiliated with Blizzard Entertainment. The inspiration is visual only — none of ShadowedUnitFrames' code is used here.

Built on [oUF](https://github.com/oUF-wow/oUF).

## License and source

Umbra's own code is MIT licensed, and the source lives on [GitHub](https://github.com/krebs3r/umbra-unit-frames). If this project ever goes quiet, someone else can pick it up — which is precisely what ShadowedUnitFrames could not offer.

Bug reports and feedback are welcome, and the most useful ones say **which piece of information got harder to read**.

---

**UMBRA UNIT FRAMES** — *Less clutter. More clarity. Your game. Front and center.*
