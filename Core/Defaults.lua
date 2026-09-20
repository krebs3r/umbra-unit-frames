local _, ns = ...
local Umbra = ns.Umbra

--[[ Layout and palette
Hardcoded for now. These become the defaults of the saved profile once the
configuration lands, and mirror the schema the design studio exports.
--]]

Umbra.media = {
	bar = [[Interface\Buttons\WHITE8X8]],
	font = (GameFontNormal:GetFont()),
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

	-- An icon small enough that a row of them stays under the frame width,
	-- and a line thick enough to read as a color rather than as an edge.
	-- Measured rather than chosen: at 22 the duration label filled the icon
	-- edge to edge, and two neighbours read as one run of text. 26 leaves the
	-- label room to be legible and still fits seven to a row at this width.
	auraSize = 26,
	auraSpacing = 2,
	auraUnderline = 2,

	-- The client's own countdown font is sized for Blizzard's icons and runs
	-- off both sides of ours, so Umbra brings its own.
	auraFontSize = 11,

	fontSize = 12,
	rangeAlpha = 0.45,

	-- How far the vertical shading darkens the bottom of a bar. Zero leaves
	-- the fill exactly as its color says, which matters for the power bar,
	-- where the color is really one of Blizzard's own textures.
	barShade = 0.28,
	barGloss = 0.12,
}

-- Width is set by the longest thing a frame has to show, which is an NPC name
-- rather than a player name. Much past this the frame reads as a bar with a
-- lot of empty space in it.
Umbra.frames = {
	player = {
		width = 210,
		castbar = true,
		classPower = true,
		powerValue = true,
		-- What you are carrying is worth more rows than what is on you.
		-- Both are whole rows of seven, so no row is half empty.
		auras = {helpful = 14, harmful = 7},
	},
	target = {
		width = 210,
		castbar = true,
		-- The other way round: what you have put on the target is the reason
		-- to look at it.
		auras = {helpful = 7, harmful = 14},
	},
	-- Same width as the player frame so the two line up, but shorter: a pet
	-- is something you glance at, not something you read.
	pet = {
		width = 210,
		nameHeight = 11,
		healthHeight = 14,
		portrait = 28,
		fontSize = 11,
	},
}

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

Both the aura code and FrameExtent need this number, and they have to agree on
it: one hangs a row under the castbar, the other measures how far the whole
frame reaches.
--]]
function Umbra:CastbarReach(config)
	if not config.castbar then return 0 end

	return config.gap + config.castbarHeight
end

--[[ Umbra:AuraBlockHeight(config, count)
How tall a block of `count` aura icons is at this frame's width.

The flow layout wraps inside the container, so the container has to be given a
height that holds every icon the group may create; one sized for a single row
would clip the second.
--]]
function Umbra:AuraBlockHeight(config, count)
	local step = config.auraSize + config.auraSpacing
	local perRow = math.max(1, math.floor((config.width + config.auraSpacing) / step))
	local rows = math.ceil(count / perRow)
	local buttonHeight = config.auraSize + config.gap + config.auraUnderline

	return rows * (buttonHeight + config.auraSpacing) - config.auraSpacing
end

--[[ Layout sets
Two whole arrangements, switched with `/uuf layout`.

A set decides three things at once, because they only hold together as a set:
where the frames sit on the screen, which side of a frame each aura row hangs
on, and whether the pet sits above the player or below it. The pet can only go
above when nothing else is up there, so the aura rows have to move with it.

`above` and `below` are ordered outwards from the frame: the first entry is
the one nearest to it.
--]]
Umbra.layouts = {
	-- Top left, where the player frame lived before Dragonflight moved it.
	-- The pet is the topmost thing in the stack, so both aura rows hang below.
	classic = {
		above = {},
		below = {'helpful', 'harmful'},
		petAbove = true,
	},

	-- Lower third and centered, the arrangement Dragonflight introduced.
	-- Buffs go above the frame, which leaves the space under it for the
	-- castbar, the debuffs and the pet.
	modern = {
		above = {'helpful'},
		below = {'harmful'},
		petAbove = false,
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

--[[ Umbra:FrameExtent(config, layout)
How far a frame reaches past its own box, above it and below it.

A frame is not only the box `FrameHeight` answers for: a castbar hangs below
it, and each aura row the set puts on a side adds to that side. Anything
placed next to the frame has to clear the whole reach.
--]]
function Umbra:FrameExtent(config, layout)
	local above, below = 0, self:CastbarReach(config)

	if not config.auras then
		return above, below
	end

	for _, filter in ipairs(layout.above) do
		if config.auras[filter] then
			above = above + config.gap + self:AuraBlockHeight(config, config.auras[filter])
		end
	end

	for _, filter in ipairs(layout.below) do
		if config.auras[filter] then
			below = below + config.gap + self:AuraBlockHeight(config, config.auras[filter])
		end
	end

	return above, below
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
	local gap = Umbra.metrics.gap
	local player, pet = Umbra.frames.player, Umbra.frames.pet
	local petHeight = Umbra:FrameHeight(pet)

	do
		local set = Umbra.layouts.classic
		local inset = 16

		-- The pet is placed first because it is the top of the stack, and the
		-- player starts a whole pet frame below it.
		local playerY = -(inset + petHeight + gap)

		-- Both frames carry two rows of auras underneath, so the gap between
		-- them has to read as a gap and not as a seam between two blocks.
		local column = 64

		set.points = {
			pet = {'TOPLEFT', UIParent, 'TOPLEFT', inset, -inset},
			player = {'TOPLEFT', UIParent, 'TOPLEFT', inset, playerY},
			target = {'TOPLEFT', UIParent, 'TOPLEFT', inset + player.width + column, playerY},
		}
	end

	do
		local set = Umbra.layouts.modern
		local baseline, spread = 260, 250

		-- The pet is below, so it has to clear everything the player reaches
		-- down into, and then stand its own height further down again.
		local _, reach = Umbra:FrameExtent(player, set)

		set.points = {
			player = {'BOTTOM', UIParent, 'BOTTOM', -spread, baseline},
			target = {'BOTTOM', UIParent, 'BOTTOM', spread, baseline},
			pet = {'BOTTOM', UIParent, 'BOTTOM', -spread, baseline - reach - gap - petHeight},
		}
	end
end
