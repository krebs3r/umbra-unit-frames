# Changelog

## 0.3 — 22 September 2026

What this one settled is mostly what the client does, and one of the answers
is a limitation rather than a feature.

**The party column does not work on the WoW: Forever beta.** That client
compiles every secure snippet with `loadstring_untainted`, the function is
missing there, and the client's own group-header code uses it to configure
each child it creates — so the header makes buttons it cannot finish, by oUF
or by anyone else. Nothing a layout can work around. Umbra steps back there
instead: the column checks whether any child was given a unit, and if none
was, it hides, stops asking the client, and hands Blizzard's group panel back.
Every other frame is unaffected. Retail is untouched by any of this.

No party column out of fixed frames is planned for Forever. It would have no
sorting and no changes during a fight, it would need maintaining beside the
header, and the client may simply have the function by the time it launches or
in a later beta. Umbra waits for the client.

Raid frames are parked for the same kind of reason, and it is a decision:
Blizzard's own do the job, class coloring included. The header carries them
whenever they are wanted.

Still a pre-release, and for the same reason as 0.1 and 0.2: there is no
configuration beyond the slash commands, and Clique is not supported yet.

- The party column stands itself down on a client whose header cannot finish a
  child: no driver, no empty column, and Blizzard's group panel back whatever
  `/uuf group` says. It asks whether a child was given a unit rather than
  whether this is Forever, so it answers correctly on a client nobody has
  tested yet — and on this one if the missing function turns up
- `/uuf dev portrait` opens a box with four attempts at each portrait side by
  side: the square as the column draws it, the whole model from its own
  camera, the file alone with no unit behind it, and the client's 2D portrait.
  The target is the question, the player and the pet are the controls. A
  column that is empty while every value about it reads healthy is a picture
  now, not an argument
- `/uuf dev check` no longer says `showing 3D model`. That line only ever
  measured which of the two layers was uncovered, and an empty model read the
  same as a full one; it says `2D stand-in down, the square is the model's`
- `/uuf dev header` retires its probe once it has answered, and keeps the run
  that answered rather than taking it again — asking costs errors on a client
  that cannot compile a snippet. It counts children that were *finished*
  rather than children that were made, which on that client is seven against
  none. Both group reports now name the build and the client they were taken
  on
- `/uuf reset` and `/uuf layout` in combat no longer reach for a protected
  frame. Placing a frame sets clamp insets on a secure unit button, which the
  client refuses in a fight; it now waits for the fight to end, ahead of the
  reveal that already waited there, and both commands say so
- Two things the client does, measured and written down: `SetUnit` on a unit
  whose identity is secret leaves the **player's own model** in the square
  rather than an empty one — so the 2D stand-in is what keeps your own face
  off the enemy frame — and `SetPortraitTexture` is *not* declined for that
  same unit, so the stand-in is the unit's real portrait rather than a
  question mark

## 0.2 — 22 September 2026

The group frames. A party column on the client's own secure group header —
children it creates, assigns and re-sorts, in the Umbra style — carrying
everything a frame in this addon has: the portrait column, class color at the
edge, power as a hairline, debuffs, a cast bar and the role each member signed
up as. Range fading comes with it, which is the sixth design principle and the
one that was waiting for exactly this.

Still a pre-release, and for the same reason as 0.1: there is no configuration
beyond the slash commands. Raid frames are not here yet, and neither is Clique
support.

- A party column, built on a real `SecureGroupHeaderTemplate` rather than four
  fixed frames: the client creates the children, assigns their units and re-
  sorts them, in combat as well as out of it. It is dragged by a mover of its
  own rather than by the header, because what a secure header does with a
  child that is not one of its unit buttons is not something this addon has
  measured. Unlocking shows four stand-ins in its place, which are real frames
  on `party1..party4` rather than boxes of the same size
- The party column carries each member's debuffs: one row under the frame,
  icons at 14 pixels rather than the 26 a single frame uses, with the same
  dispel underline and no duration label — at that size the label covers the
  icon it belongs to. The count is what fits the frame's width rather than a
  number written down, so the row ends where the frame does. Buffs stay off
- The party column marks each member's role with the client's own icon, left
  of the name — tank, healer and damage alike. Only NONE draws nothing,
  because that one is an absence. The space is reserved on every group frame
  whether or not there is an icon in it, so the names stay in one column
  when somebody changes role
- Party frames have a cast bar, the same one the single frames carry: full
  width under the frame, spell name at the left and the time at the right.
  It cost one line — the stack below a frame already began with the
  castbar's reach, so the debuff row moved down by its height and the column
  grew with it, from 53 to 69 per member
- Range fading, the last of the six design principles, and confirmed in an
  instance on 21 September 2026. A unit out of range fades with its portrait
  and its rows instead of being replaced by a grey copy of itself — oUF gates
  its own element on group membership, which is why it waited for the column
  rather than being half-built on the single frames
- The header's spacing, the column's height and the stand-ins shown while it
  is unlocked now ask one function how much room a member takes. A row
  hanging under each frame was the first thing that could make the three
  disagree, and three numbers derived separately is how the pet once ended
  up under a row of debuffs
- In the modern set the party column is centred on the left edge instead of
  standing on the set's baseline. It grew by a debuff row per member while
  its bottom edge stayed put, so all of that growth went upward from a line
  that was already low
- `/uuf group umbra` puts the client's own group panel away, `/uuf group
  both` brings it back. It goes the way Blizzard's aura stack already went —
  parented to a frame that is never shown, so nothing of its own is
  overwritten and the panel shows itself again unharmed. Default is `both`:
  the panel carries the raid markers and the way out of a group, and the
  column was placed to clear it rather than to replace it
- `/uuf health class` colors the health bar by the unit — class for a player,
  reaction for everything else, the same color the edge already carries — and
  `/uuf health plain` puts it back to the one neutral green. The incoming-heal
  ghost follows the bar so that what is arriving still reads as the same
  quantity. Off by default: the neutral bar is the design, this spends it on
  purpose, and the setting is remembered
- A class-colored health bar is muted to 60% so that the two numbers on it
  stay legible. The text is near-white and priest white, rogue yellow and
  monk green are near-white too; the fade puts the dark behind the bar back
  into the color. It is the fill's alpha rather than the color, because
  dimming a class color means arithmetic on three numbers that are secret
  inside an instance — and it leaves the 3-pixel edge at full strength, so
  identity still reads loudest where the principle puts it
- A portrait no longer spends four seconds waiting for a model the client has
  refused to hand over. Since 12.0.5 `Model:SetUnit` takes no unit token for a
  unit with a secret identity, so that is now the question asked: a classified
  unit gets the 2D stand-in and nothing else, and the retry is kept for a
  model that really is still on its way. Hidden frames — the four party
  stand-ins while the column is locked — no longer start a chain at all
- The target-of-target frame no longer throws on every model change in the
  world. oUF asks the client for permission to compare two unit tokens and
  treats a yes as a guarantee; inside a delve the permission comes back in the
  clear and the comparison itself comes back hidden, which cost 716 errors in
  one run. Umbra now asks the question instead of asking permission, and where
  the client will not answer it settles the portrait on a timer rather than
  reloading it for every model in the world
- `/uuf dev check` says per frame whether the unit's identity is secret, which
  is what separates a refusal from a model that has not arrived. It also names
  frames by name where two of them share a unit: the party header's child and
  the party stand-in both answer for `party1` and printed the same label
- `/uuf dev party` says what each member signed up as, whether the client
  answered in the clear, whether the run was taken inside an instance, and
  whether this client has the art. The role is a fact about a person in your
  group rather than about a unit in the world, so that it survives inside an
  instance had to be measured before anything was drawn from it
- `/uuf check` reports both halves of that comparison per frame — whether the
  client says the two tokens may be compared, and what comparing them actually
  answers. In a delve those two lines read `readable — true` and `hidden` on
  the same frame, one under the other
- `/uuf debug` says when the client refused to name the unit behind an event,
  once per frame, so a quiet log means the guard never had to act rather than
  that it was never installed

## 0.1 — 20 September 2026

First release, and a pre-release on purpose. Every single frame is built and
five of the six design principles are implemented, verified in the client
where it says so below. What is not here yet: any configuration beyond the
slash commands, group and raid frames, and range fading with them.

Built against Retail 12.1 and the WoW: Forever beta (interface 16001); the
Forever package carries the deviations found on that client.

- Player and target frames as an oUF layout: class color on a 3px edge, portrait
  in its own column, neutral health bar, power as a hairline, castbar
- Auras with an underline: buffs above the frame, debuffs below, each icon on a
  slim line the client colors by dispel type
- A target-of-target frame and a boss column, placed by each layout set, with
  as many boss frames as the client says it has. The target-of-target sits
  above the target in both sets, and the buff row moves up to make room; the
  boss column is centred on the right edge, clear of the quest tracker
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
- `/uuf unlock` shows every frame, including ones with no unit behind them,
  and fills their aura rows, so what you drag is the whole extent
- Dragged frames snap to each other's matching edges and middles and to the
  middle of the screen, with a guide showing what they are about to line up on
- A frame cannot be dropped on top of what another one draws: dragged onto a
  castbar or an aura row, it moves to the nearest place that covers nothing —
  for the pet, the slot the layout keeps for it under the castbar
- A frame cannot be dragged so far that its castbar or its aura rows leave the
  screen, not just its own box
- Pointing at a frame shows the unit's tooltip, the way pointing at the unit
  in the world does
- `/uuf auras umbra` puts away the game's own buff and debuff frames, `/uuf
  auras both` brings them back
- `/uuf` on its own lists the commands one to a line, with what each does
- `/uuf debug` also hands over what was refused before it was switched on,
  which is where everything interesting happens: during the build at login
- `/uuf check` also reports whether the client can compile secure snippets,
  which decides whether group frames can have a secure header
- Incoming healing, damage absorbs and heal absorbs on the health bar: healing
  ghosted in the bar's own green, an absorb hatched so it reads as a shield
  laid over the bar rather than as more health, and a heal absorb eating
  backwards into the health already there
- `/uuf test` fills the health bar's prediction as well, because an absorb
  takes someone else to put on you and cannot be waited for
- Aura rows hold the eighth icon again: the client counts a spacing after
  every button, so the row width it was given was two pixels short and the
  last icon wrapped out of sight
- The portrait column is no longer empty for a target inside a dungeon: the
  client withholds a hostile unit's model there, so the game's own 2D
  portrait stands in until a real model can be had
- A `/uuf` command that runs into an error says so instead of breaking the
  chat frame it was typed into
- The check report can be opened from a key binding as well as from chat
- The report window is built from the game's own panel templates, so it
  looks like the rest of the interface, and colors the verdicts it reports
  while still handing over plain text to copy
- `/uuf check` opens a window instead of filling the chat frame, in plain
  text with a button that selects the whole report for copying. Closing it
  gives the keyboard back, so chat keeps working
- `/uuf check` reports what each frame's portrait was able to load, and
  whether the client hides either value oUF decides that on — for every
  frame, including ones with nothing behind them, so a missing line cannot be
  read two ways
- `/uuf auras` typed in combat now takes effect when the fight ends, and says
  so, instead of silently doing nothing: the game's two aura frames are
  protected
- `Layouts/` split into widgets, tags, auras and the style that assembles them
- Packages for Retail (`_Mainline`) and WoW: Forever (`_Camelot`) from one source
- `Compat/Forever.lua` for the deviations found on the Forever beta client
- MIT license, packaging and lint workflows
