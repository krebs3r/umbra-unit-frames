local _, ns = ...
local Umbra = ns.Umbra

--[[ Layout and palette
Hardcoded for now. These become the defaults of the saved profile once the
configuration lands, and mirror the schema the design studio exports.
--]]

Umbra.media = {
	bar = [[Interface\Buttons\WHITE8X8]],
	font = (GameFontNormal:GetFont()),

	-- The hatching over an absorb. Ours rather than one of Blizzard's, for
	-- the same reason the signature is a character and not a texture: a path
	-- into the client's own art cannot be asked whether it survived the last
	-- patch, and a missing one draws nothing at all. This one ships in the
	-- addon, so it is there exactly as long as the addon is.
	--
	-- 32x32, white, with the stripe repeating every 8 pixels in both
	-- directions, so the tile meets itself seamlessly whatever size the
	-- client stretches the region to. White because the color comes from
	-- SetVertexColor.
	hatch = [[Interface\AddOns\UmbraUnitFrames\Media\hatch]],
}

Umbra.colors = {
	-- RGB 78/122/85, sampled from the reference shot rather than guessed at.
	-- The bar stays neutral so that class color means class and nothing else,
	-- which is also what keeps it working inside encounters: a fixed color
	-- needs no curve evaluated against a hidden health value.
	health = {0.306, 0.478, 0.333},

	-- The ground the portrait model stands on. Opaque, so the world behind
	-- the frame never tints it and the class tint above reads as a tint.
	portraitGround = {0.137, 0.169, 0.235},

	-- Dark enough to carry light text. The interface accent is too bright to
	-- put a label on, and a cast bar is unit information rather than chrome.
	cast = {0.659, 0.486, 0.200},

	-- The line under an aura icon, for the auras the client reports no dispel
	-- type for — which is most of them. Where there is a dispel type, the
	-- client paints its own color over a second line on the same rectangle.
	auraHelpful = {0.553, 0.592, 0.671},
	auraHarmful = {0.698, 0.365, 0.365},

	--[[ What is coming to the health bar, and what is standing in front of it
	Three surfaces on the same bar, and they have to be told apart at a
	glance without reading a number.

	Incoming healing is the health color again, ghosted: it is health that is
	not there yet, so it belongs to the same quantity rather than beside it.
	An absorb is not health at all and takes a color of its own, hatched so
	that it reads as a shield laid over the bar rather than as more of it. A
	heal absorb is the one that eats backwards into health already there, and
	is the only one of the three that is bad news, so it is the only red.
	--]]
	healPrediction = {0.306, 0.478, 0.333, 0.55},
	absorb = {0.604, 0.702, 0.839, 0.65},
	healAbsorb = {0.545, 0.220, 0.259, 0.75},

	background = {0.078, 0.098, 0.145, 0.96},
	border = {0.043, 0.055, 0.082},
	text = {0.902, 0.914, 0.941},
	muted = {0.553, 0.592, 0.671},
	accent = {0.459, 0.863, 0.769},
}

--[[ Umbra.power
Resource colors, where Umbra's differ from the client's.

A bar and the number above it have to be the same color, and the only way to
guarantee that is to make them read the same entry. The Power element colors
the bar from `oUF.colors.power`, and oUF's `[powercolor]` tag builds its color
escape from the very same one.

That rules out `colorPowerAtlas`. It paints the bar with one of Blizzard's
textures and never calls SetStatusBarColor at all, so the number has nothing
to match: sampled off a screenshot, the mana hairline rendered at `35/106/196`
while the percentage above it read `0/0/255`, which is what PowerBarColor
actually holds for mana. The value below is that hairline.

Anything not named here keeps the client's own color, and costs nothing —
whatever the table says, both surfaces now say the same thing.
--]]
Umbra.power = {
	MANA = {35, 106, 196},
}

-- Power colors are shared objects: oUF keys each one by its token and again
-- by its Enum.PowerType number, so restating the RGB in place reaches every
-- alias at once.
do
	local colors = ns.oUF and ns.oUF.colors

	if colors and colors.power then
		for token, rgb in pairs(Umbra.power) do
			local color = colors.power[token]

			if color and color.SetRGB then
				color:SetRGB(rgb[1] / 255, rgb[2] / 255, rgb[3] / 255)
			end
		end
	end
end

Umbra.metrics = {
	classEdge = 3,
	portrait = 38,
	gap = 2,
	inset = 4,

	-- Between two frames of a group column. Wider than `gap`, which separates
	-- the rows inside one frame: the same distance for both would make four
	-- frames read as one tall frame with twelve rows.
	groupSpacing = 6,

	nameHeight = 13,
	healthHeight = 20,
	powerHeight = 4,
	pipHeight = 4,
	castbarHeight = 14,
	valueWidth = 40,

	-- A line thick enough to read as a color rather than as an edge, and an
	-- icon measured rather than chosen: at 22 the duration label filled it
	-- edge to edge and two neighbours read as one run of text. 26 leaves the
	-- label room to be legible.
	auraSize = 26,
	auraSpacing = 2,
	auraUnderline = 2,

	-- How many icons a row holds, and with that how wide every frame is —
	-- see `width` below.
	auraPerRow = 8,

	-- The client's own countdown font is sized for Blizzard's icons and runs
	-- off both sides of ours, so Umbra brings its own.
	auraFontSize = 11,

	fontSize = 12,

	-- How much of the bar's color shows while it carries a unit's — the
	-- fill's own alpha, so the dark behind it mutes whatever color the
	-- client handed over. Muting the color itself would mean arithmetic on
	-- three numbers that are secret inside an instance; an alpha never
	-- touches them.
	-- It is also what makes the two numbers on the bar legible: the text
	-- is near-white, and so are priest white, rogue yellow and monk green
	-- at full strength.
	classBarAlpha = 0.6,

	-- What those two numbers are cut with. Off: an outline at this size
	-- reads as a heavier font rather than as a rim, which is why the bar
	-- is muted instead. 'OUTLINE' or 'THICKOUTLINE' bring it back, and the
	-- shadow under the text is there either way.
	barLabelOutline = '',
	rangeAlpha = 0.45,

	-- How near a dragged edge has to come to another one before it is taken
	-- to mean it. Far enough to catch a hand that was aiming for the line,
	-- near enough that a frame deliberately set a little off stays there.
	snapDistance = 8,

	-- How far the vertical shading darkens the bottom of a bar. Zero leaves
	-- the fill exactly as its color says, which matters for the power bar,
	-- where the color is really one of Blizzard's own textures.
	barShade = 0.28,
	barGloss = 0.12,
}

--[[ The aura row sets the frame width, not the other way round
Width used to be a number chosen for the longest thing a frame shows, which is
an NPC name; the aura row was then cut to fit inside it and never came out
even. Measured on 20 September 2026 at a frame width of 210: the block was
flush on the left and 16 units short on the right, every row, both frames.

So the chain now runs the other way. The duration label has to fit inside the
icon, which settles the icon at 26; a row of them is what a frame is for; and
the width is whatever that row comes to. Nothing is left over on either side,
and the name column gains the difference.
--]]
do
	local m = Umbra.metrics

	m.width = m.auraPerRow * m.auraSize + (m.auraPerRow - 1) * m.auraSpacing
end

-- Every frame takes that width, so the rows under them line up with each
-- other as well as with their own edges.
Umbra.frames = {
	player = {
		castbar = true,
		classPower = true,
		powerValue = true,
		-- The pet frame hangs off this one, so it takes a place in the stack
		-- on whichever side the set puts it.
		owns = {pet = true},
		-- What you are carrying is worth more rows than what is on you.
		-- Both are whole rows, so no row is half empty.
		auras = {helpful = 16, harmful = 8},
	},
	target = {
		castbar = true,
		-- The same arrangement the player has with its pet: the small frame
		-- belonging to this one takes a place in this one's stack, so the
		-- aura row beside it moves rather than being landed on.
		owns = {targettarget = true},
		-- How much the other side has left to spend with is worth the same
		-- number the player reads about itself. It costs the name the width
		-- of the column, which is why no other frame carries one.
		powerValue = true,
		-- The other way round: what you have put on the target is the reason
		-- to look at it.
		auras = {helpful = 8, harmful = 16},
	},
	-- The shared width, so the two line up, but shorter: a pet is something
	-- you glance at, not something you read.
	pet = {
		nameHeight = 11,
		healthHeight = 14,
		portrait = 28,
		fontSize = 11,
	},

	-- Who the target is looking at, which is one question — is it on the tank
	-- or on me — and never worth more than a glance. So it is cut like the
	-- pet: same width, shorter, no castbar and no auras.
	targettarget = {
		nameHeight = 11,
		healthHeight = 14,
		portrait = 28,
		fontSize = 11,
	},

	--[[ The party column
	Keyed `party` rather than `party1`, and that is not a shorthand: `party`
	is the unit oUF guesses for a header child and hands to the style. One
	config answers for every frame the header makes, however many that turns
	out to be and whoever is standing in it — which is the whole point of
	letting the client create them.

	Cut like the pet and the target's target: the shared width, so the column
	lines up with everything else, and short, because four stacked frames are
	already a lot of screen. No castbar, because four of those is a wall of
	moving bars, and no aura rows for the reason the boss column has none.
	--]]
	party = {
		--[[ Not a frame to spawn
		This config has to live in `Umbra.frames` for the style to find it,
		because `party` is the unit oUF hands a header child. But everything
		else in this table is spawned as a single frame by `Layouts/Single.lua`,
		which would put a second frame under the same name and the same saved
		position as the column — and it did, drawing a stray row that looked
		like a child in the wrong place.
		--]]
		header = true,

		-- A cast bar like the single frames have, and it costs nothing
		-- to place: the stack below a frame starts with the castbar's
		-- reach, so the debuff row moves down by exactly its height
		-- and the column grows with it. One member is 69 tall now
		-- rather than 53.
		castbar = true,

		nameHeight = 11,
		healthHeight = 14,
		portrait = 28,
		fontSize = 11,

		-- Debuffs only, and at half the size the single frames use. A
		-- party frame is 33 pixels tall; a 26-pixel icon under it
		-- would read as a second row of frames. At 14 the block is 18
		-- tall, near enough to the health bar it hangs under to belong
		-- to it.
		--
		-- No duration text: at 14 pixels the label the single frames
		-- carry would cover the icon it belongs to. The stack count
		-- stays — it is one glyph, and it is the one that changes what
		-- you do.
		auraSize = 14,
		auraDuration = false,
		auras = {harmful = 8},
	},
}

--[[ As many party frames as this client has
`MAX_PARTY_MEMBERS` is the client's own answer, the way `MAX_BOSS_FRAMES` is
for the boss column, and it is asked for the same reason: a number written
here is wrong on the patch that changes it. Nothing spawns from this — the
header decides how many children there are — it is only how tall the box that
holds them comes out, which has to be known before anyone stands in it.
--]]
Umbra.partyCount = type(_G.MAX_PARTY_MEMBERS) == 'number' and MAX_PARTY_MEMBERS or 4

--[[ As many boss frames as this client has
`MAX_BOSS_FRAMES` is the client's own answer and has changed between
expansions. A number written here would be wrong on the patch that changes it,
and wrong in whichever direction hurts: too few leaves a boss unshown, too
many spawns a frame for a unit that will never exist.

They are identical on purpose. An encounter shows between one and five of
them, and a frame differing from its neighbours in anything but its unit would
be saying something about that boss which nothing here knows. Each keeps its
castbar, which on a boss is the most useful line on the frame, and carries no
aura rows: five stacked frames with rows between them would be a wall.
--]]
Umbra.bossCount = type(_G.MAX_BOSS_FRAMES) == 'number' and MAX_BOSS_FRAMES or 5

for index = 1, Umbra.bossCount do
	Umbra.frames['boss' .. index] = {
		castbar = true,
		nameHeight = 11,
		healthHeight = 14,
		portrait = 28,
		fontSize = 11,
	}
end

-- A frame may override any metric; anything it does not name falls back.
for _, config in pairs(Umbra.frames) do
	setmetatable(config, {__index = Umbra.metrics})
end

function Umbra:FrameHeight(config)
	local height = config.nameHeight + config.gap + config.healthHeight
		+ config.gap + config.powerHeight

	if config.classPower then
		height = height + config.gap + config.pipHeight
	end

	return height
end

--[[ Umbra:CastbarReach(config)
How far the castbar hangs below the frame, gap included. Zero without one.

It is where the stack under a frame starts, so the aura rows, the pet frame
and the reach of the whole side all count from it and cannot disagree.
--]]
--[[ Umbra:ColumnHeight(config, count)
How tall a column of `count` frames of this kind comes to, the spacing between
them counted and none left hanging off the end.

A group header positions its own children, so this is not what places them: it
is what the box around them has to be, for the frame mover to have something
to drag and for a column dragged to the bottom edge to stop while all of it is
still on screen.
--]]
--[[ Umbra:GroupSlotHeight(config)
How much room one member of a group column takes: the frame itself and
everything hanging off either side of it.

Three things have to agree on this number — the header's own spacing,
the column's height, and the stand-ins that stand in for the column
while it is unlocked — and they would disagree the moment a debuff row
appeared under each member. So all three ask here.

It reads the set in force rather than assuming a side. Today both sets
hang a party frame's debuffs below it and neither puts anything above,
so the answer is the same either way; that is a fact about the two sets,
not something this is allowed to rely on.
--]]
function Umbra:GroupSlotHeight(config)
	local layout = self:ActiveLayout()

	return self:StackOffset(config, layout, 'above')
		+ self:FrameHeight(config)
		+ self:StackOffset(config, layout, 'below')
end

function Umbra:ColumnHeight(config, count)
	if count < 1 then return 0 end

	return count * self:GroupSlotHeight(config)
		+ (count - 1) * config.groupSpacing
end

function Umbra:CastbarReach(config)
	if not config.castbar then return 0 end

	return config.gap + config.castbarHeight
end

--[[ Umbra:AuraPerRow(config) / Umbra:AuraButtonHeight(config)
How many icons fit across this frame, and how tall one of them is.

This still counts rather than answering `auraPerRow`, because a frame may
override its width and then the row has to follow. At the shared width the
two agree exactly, by construction: the last icon needs no spacing after it,
so one spacing's worth is added before the division.

A button is a square icon with the line underneath it, which is why the
element is given a width and a height rather than a size.
--]]
function Umbra:AuraPerRow(config)
	local step = config.auraSize + config.auraSpacing

	return math.max(1, math.floor((config.width + config.auraSpacing) / step))
end

--[[ The party row is as long as the frame it hangs under
The single frames pick a count and the shared width follows from it:
`width` is eight 26-pixel icons, by construction. A party frame is that
same width with icons half the size, so any count written down by hand
ends the row somewhere in the middle of the frame — which reads as a row
that failed rather than as a row of what there is.

So it is asked instead of chosen, and the row ends where the frame ends
whatever the icon size becomes. It is a cap, not a promise: fourteen is
how many would fit, not how many anyone carries.
--]]
Umbra.frames.party.auras.harmful = Umbra:AuraPerRow(Umbra.frames.party)

--[[ Umbra:AuraRowLimit(config)
The line width to hand the client's flow layout, which is not the frame width.

`layoutLimit` reaches `SetFlowLayoutMaximumLineSize`, a width in pixels, and
the client fills a line by adding a button *and its spacing* until the next
one would not fit. It therefore asks for `n · (icon + spacing)`, while the
frame is exactly `n · icon + (n - 1) · spacing` wide — the same row without
the gap after the last icon, which nothing draws.

Handing it the frame width was a 2 pixel shortfall on a 222 pixel frame, and
**that cost a whole icon**: eight came to 224 against a limit of 222, so seven
fitted and the eighth wrapped into the next line. Measured in *Thron der
Gezeiten* on 20 September 2026, seven buffs where the reserved block holds
eight, and the preview showed eight the whole time because Umbra packs those
itself with `AuraPerRow` — the arithmetic that adds the trailing spacing back
before dividing.

So both sides now say eight, and each says it the way its own side counts.
--]]
function Umbra:AuraRowLimit(config)
	return self:AuraPerRow(config) * (config.auraSize + config.auraSpacing)
end

function Umbra:AuraButtonHeight(config)
	return config.auraSize + config.gap + config.auraUnderline
end

--[[ Umbra:AuraBlockHeight(config, count)
How tall a block of `count` aura icons is at this frame's width.

The flow layout wraps inside the container, so the container has to be given a
height that holds every icon the group may create; one sized for a single row
would clip the second.
--]]
function Umbra:AuraBlockHeight(config, count)
	local rows = math.ceil(count / self:AuraPerRow(config))

	return rows * (self:AuraButtonHeight(config) + config.auraSpacing) - config.auraSpacing
end

--[[ Layout sets
Two whole arrangements, switched with `/uuf layout`.

A set decides three things at once, because they only hold together as a set:
where the frames sit on the screen, which side of a frame each aura row hangs
on, and whether the pet sits above the player or below it. The pet can only go
above when nothing else is up there, so the aura rows have to move with it.

`above` and `below` are the stack on each side, ordered outwards from the
frame: the first entry is the one nearest to it. The pet takes its place in
that stack the way an aura row does, so that everything on that side is
counted the same way and nothing can land on top of it.
--]]
Umbra.layouts = {
	-- Top left, where the player frame lived before Dragonflight moved it.
	-- The pet is the topmost thing in the stack, so both aura rows hang below.
	classic = {
		above = {'pet', 'targettarget'},
		below = {'helpful', 'harmful'},
	},

	-- Lower third and centered, the arrangement Dragonflight introduced.
	-- Buffs go above the frame. Under it the pet comes first, close enough to
	-- the player to read as belonging to it, and the debuffs hang below the
	-- pet.
	modern = {
		above = {'targettarget', 'helpful'},
		below = {'pet', 'harmful'},
	},
}

Umbra.defaultLayout = 'modern'

--[[ Umbra:LayoutName() / Umbra:ActiveLayout()
The set in force. A saved name this version no longer has falls back to the
default rather than erroring, which is what happens to anyone downgrading.
--]]
function Umbra:LayoutName()
	local name = UmbraUnitFramesDB and UmbraUnitFramesDB.layout

	if name and self.layouts[name] then
		return name
	end

	return self.defaultLayout
end

function Umbra:ActiveLayout()
	return self.layouts[self:LayoutName()]
end

--[[ Umbra:StackHeight(config, entry)
How tall one entry of a stack is on this frame, or nil when this frame has no
such thing: a pet frame carries no aura rows, and nothing but the target has a
target-of-target hanging off it.

An entry names either a frame or an aura block, and `owns` is what says which
frames this one is responsible for. It used to be a single `ownsPet` flag with
the pet's name written into this function, which was the only reason a second
frame could not be put in a stack without editing the function that measures
stacks.
--]]
function Umbra:StackHeight(config, entry)
	if config.owns and config.owns[entry] then
		return self:FrameHeight(self.frames[entry])
	end

	local count = config.auras and config.auras[entry]

	return count and self:AuraBlockHeight(config, count)
end

--[[ Umbra:StackOffset(config, layout, side, entry)
How far past the frame's own edge the named entry begins, the gap before it
included, and nil when this side's stack does not hold it. Named nothing, it
answers how far the whole side reaches instead — the castbar included, since
that hangs below the box as well.

Everything on a side asks this rather than adding the heights up for itself,
which is what keeps the pet frame and the row beside it from drifting apart:
one count changing moves both. Writing either of them down as a number is how
the pet once ended up underneath a row of debuffs.
--]]
function Umbra:StackOffset(config, layout, side, entry)
	local offset = side == 'below' and self:CastbarReach(config) or 0

	for _, name in ipairs(layout[side]) do
		if name == entry then
			return offset + config.gap
		end

		local height = self:StackHeight(config, name)

		if height then
			offset = offset + config.gap + height
		end
	end

	-- Asked for something this side does not hold, there is nothing to say.
	if entry then return end

	return offset
end

--[[ Where each set puts its frames
Derived rather than written down. A frame height is made of seven metrics and
a reach of several more, so a number copied out of them goes stale the moment
one of them changes — which is exactly how the pet frame once ended up
underneath a row of debuffs.

The two sets measure from different corners, and a point names a different
edge of the frame in each: `TOPLEFT` fixes the top edge and everything below
it counts downwards, `BOTTOM` fixes the bottom edge and everything counts up.
So each set does its own arithmetic rather than sharing one formula that would
have to know which corner it is in.
--]]
do
	local player, pet = Umbra.frames.player, Umbra.frames.pet
	local target, glance = Umbra.frames.target, Umbra.frames.targettarget
	local petHeight = Umbra:FrameHeight(pet)

	--[[ The boss column
	The right edge, stacked downwards, and the same in both sets. An encounter
	frame is not part of the arrangement you chose; it is something the fight
	brings with it, and it belongs where nothing of yours is.

	**Centred on the right edge rather than hung from the top.** Measured from
	the top it landed in the corner the quest tracker already occupies, and it
	was measured from there only because 200 was easy to write. The middle of
	that edge is where the eye goes for a frame that is not yours, and the
	whole block is centred rather than its first frame, so one boss and five
	sit in the same place on screen.

	The step is each frame's whole reach — its box and the castbar under it —
	plus a gap, asked rather than written down, so a boss frame that grows
	takes its neighbours down with it instead of landing on them. The block is
	the same arithmetic once more: the steps between them, plus the last one's
	own reach, which has no step after it.
	--]]
	local function BossPoints(set)
		local boss = Umbra.frames.boss1
		if not boss then return end

		local reach = Umbra:FrameHeight(boss) + Umbra:StackOffset(boss, set, 'below')
		local step = reach + boss.gap * 2
		local half = ((Umbra.bossCount - 1) * step + reach) / 2

		for index = 1, Umbra.bossCount do
			set.points['boss' .. index] = {'TOPRIGHT', UIParent, 'RIGHT',
				-16, half - (index - 1) * step}
		end
	end

	do
		local set = Umbra.layouts.classic
		local inset = 16

		-- The pet is the top of the stack and sits at the inset, so the
		-- player starts a whole pet frame below that.
		local playerY = -(inset + Umbra:StackOffset(player, set, 'above', 'pet') + petHeight)

		-- Both frames carry two rows of auras underneath, so the gap between
		-- them has to read as a gap and not as a seam between two blocks.
		local column = 64

		local targetX = inset + player.width + column

		-- Its top edge, counting up from the target's top edge: past the gap
		-- the stack keeps, and then its own height.
		local glanceY = playerY
			+ Umbra:StackOffset(target, set, 'above', 'targettarget')
			+ Umbra:FrameHeight(glance)

		set.points = {
			pet = {'TOPLEFT', UIParent, 'TOPLEFT', inset, -inset},
			player = {'TOPLEFT', UIParent, 'TOPLEFT', inset, playerY},
			target = {'TOPLEFT', UIParent, 'TOPLEFT', targetX, playerY},

			-- Derived from the target's own stack, the way the player's
			-- position is derived from the pet's. In this set that lands it
			-- at the inset, level with the pet, because nothing else is above
			-- the target here — but it lands there by arithmetic rather than
			-- by two numbers that would have to be kept equal by hand.
			targettarget = {'TOPLEFT', UIParent, 'TOPLEFT', targetX, glanceY},

			--[[ Under the player's whole left-hand block
			Not under the player *frame*: under the frame, its castbar and
			both aura rows, which is what `StackOffset` answers for a side.
			The column is its own block rather than an entry in that stack,
			so it keeps the wider gap the two columns keep from each other
			instead of the gap rows keep inside one frame.
			--]]
			party = {'TOPLEFT', UIParent, 'TOPLEFT', inset,
				playerY - Umbra:FrameHeight(player)
					- Umbra:StackOffset(player, set, 'below') - column},
		}

		BossPoints(set)
	end

	do
		local set = Umbra.layouts.modern
		local baseline, spread = 260, 250

		-- Its own, because each set does its own arithmetic. The first
		-- version of the party column reached for the one in the block
		-- above, which is local to that block: it read as nil, the client
		-- took nil for zero, and the column sat flush against the edge of
		-- the screen instead of at the inset. Nothing erred.
		local inset = 16

		-- The pet is the first thing under the player, so it clears the
		-- castbar and nothing else. The debuff row underneath it is what
		-- moves when the pet changes height, and asks the same stack.
		local petY = baseline - Umbra:StackOffset(player, set, 'below', 'pet') - petHeight

		--[[ Above the target, with the buffs moving up to make room
		It belongs over the frame it speaks for, the way the pet belongs under
		the player, and putting it beside instead was reading the set's
		crowding as a rule rather than as a problem to solve. It is an entry
		in the target's `above` stack now, nearest the frame, so the buff row
		is pushed up by exactly its height and neither can land on the other.
		--]]
		local glanceY = baseline + Umbra:FrameHeight(target)
			+ Umbra:StackOffset(target, set, 'above', 'targettarget')

		set.points = {
			player = {'BOTTOM', UIParent, 'BOTTOM', -spread, baseline},
			target = {'BOTTOM', UIParent, 'BOTTOM', spread, baseline},
			pet = {'BOTTOM', UIParent, 'BOTTOM', -spread, petY},
			targettarget = {'BOTTOM', UIParent, 'BOTTOM', spread, glanceY},

			--[[ The left edge, on its own line
			This set gathers everything about you into the lower middle,
			and a party column does not belong in that gathering: it is
			about four other people. So it goes to the left, where this
			set has left room.

			**Centred on that edge rather than standing on the set's
			baseline.** Sharing the baseline was the tidier idea and sat
			too low in use — the column grew by a debuff row per member
			and the bottom edge stayed put, so all of that growth went
			upward from a line that was already low. Centred, the column
			keeps clear of the client's own group panel above it and of
			the chat frame below, whatever the screen height, and it no
			longer has to know what the player and the target are doing
			at the other end of the screen.

			`/uuf dev party` prints the screen height and where the
			client's panel reaches, so a column that still sits wrong
			can be answered with a number rather than with another
			guess.
			--]]
			party = {'LEFT', UIParent, 'LEFT', inset, 0},
		}

		BossPoints(set)
	end
end
