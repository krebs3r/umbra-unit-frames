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
		-- on whichever side the set puts it. No other frame has one under it.
		ownsPet = true,
		-- What you are carrying is worth more rows than what is on you.
		-- Both are whole rows, so no row is half empty.
		auras = {helpful = 16, harmful = 8},
	},
	target = {
		castbar = true,
		-- How much the other side has left to spend with is worth the same
		-- number the player reads about itself. It costs the name the width
		-- of the column, which is why no other frame carries one.
		powerValue = true,
		-- The other way round: what you have put on the target is the reason
		-- to look at it.
		auras = {helpful = 8, harmful = 16},
	},
	-- A focus is a unit you chose to keep watching, and almost always because
	-- of what it is casting, so the castbar is the point of the frame rather
	-- than a decoration on it. One row of harmful auras, because what is on
	-- it is the other reason to have picked it.
	focus = {
		castbar = true,
		auras = {harmful = 8},
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
}

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
		above = {'pet'},
		below = {'helpful', 'harmful'},
	},

	-- Lower third and centered, the arrangement Dragonflight introduced.
	-- Buffs go above the frame. Under it the pet comes first, close enough to
	-- the player to read as belonging to it, and the debuffs hang below the
	-- pet.
	modern = {
		above = {'helpful'},
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
such thing: a target frame has no pet under it, and a pet frame carries no
aura rows.
--]]
function Umbra:StackHeight(config, entry)
	if entry == 'pet' then
		if not config.ownsPet then return end

		return self:FrameHeight(self.frames.pet)
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

	The step is each frame's whole reach — its box and the castbar under it —
	plus a gap, asked rather than written down, so a boss frame that grows
	takes its neighbours down with it instead of landing on them.
	--]]
	local function BossPoints(set)
		local boss = Umbra.frames.boss1
		if not boss then return end

		local step = Umbra:FrameHeight(boss)
			+ Umbra:StackOffset(boss, set, 'below') + boss.gap * 2

		for index = 1, Umbra.bossCount do
			set.points['boss' .. index] = {'TOPRIGHT', UIParent, 'TOPRIGHT',
				-16, -(200 + (index - 1) * step)}
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

		set.points = {
			pet = {'TOPLEFT', UIParent, 'TOPLEFT', inset, -inset},
			player = {'TOPLEFT', UIParent, 'TOPLEFT', inset, playerY},
			target = {'TOPLEFT', UIParent, 'TOPLEFT', targetX, playerY},

			-- Above the target the way the pet sits above the player. In this
			-- set nothing else is up there — the aura rows both hang below —
			-- and the small frame belonging to the big one reads best
			-- directly over it.
			targettarget = {'TOPLEFT', UIParent, 'TOPLEFT', targetX, -inset},

			-- A third column. There is no room to the left of the player
			-- here, because the set is anchored into the corner, so the only
			-- outside this arrangement has is further right.
			focus = {'TOPLEFT', UIParent, 'TOPLEFT', targetX + player.width + column, playerY},
		}

		BossPoints(set)
	end

	do
		local set = Umbra.layouts.modern
		local baseline, spread = 260, 250

		-- The pet is the first thing under the player, so it clears the
		-- castbar and nothing else. The debuff row underneath it is what
		-- moves when the pet changes height, and asks the same stack.
		local petY = baseline - Umbra:StackOffset(player, set, 'below', 'pet') - petHeight

		--[[ Beside, because neither side is free here
		Both frames have their buffs above and their castbar and debuffs
		below, so the only room left is sideways — and sideways is always
		free, because every row is exactly as wide as its frame and nothing
		hangs off the edges.

		Tops aligned rather than bottoms. These points fix the bottom edge and
		the small frame is shorter, so sharing a bottom would leave it
		floating at the wrong end of its neighbour.
		--]]
		local beside = player.width + player.gap * 4
		local glanceY = baseline + Umbra:FrameHeight(target) - Umbra:FrameHeight(glance)

		set.points = {
			player = {'BOTTOM', UIParent, 'BOTTOM', -spread, baseline},
			target = {'BOTTOM', UIParent, 'BOTTOM', spread, baseline},
			pet = {'BOTTOM', UIParent, 'BOTTOM', -spread, petY},
			targettarget = {'BOTTOM', UIParent, 'BOTTOM', spread + beside, glanceY},
			focus = {'BOTTOM', UIParent, 'BOTTOM', -(spread + beside), baseline},
		}

		BossPoints(set)
	end
end
