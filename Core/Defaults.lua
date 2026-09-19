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

	background = {0.078, 0.098, 0.145, 0.96},
	border = {0.043, 0.055, 0.082},
	text = {0.902, 0.914, 0.941},
	muted = {0.553, 0.592, 0.671},
	accent = {0.459, 0.863, 0.769},
}

Umbra.layout = {
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
		point = {'BOTTOM', UIParent, 'BOTTOM', -250, 260},
	},
	target = {
		width = 210,
		castbar = true,
		point = {'BOTTOM', UIParent, 'BOTTOM', 250, 260},
	},
	-- Same width as the player frame so the two line up, but shorter: a pet
	-- is something you glance at, not something you read.
	pet = {
		width = 210,
		nameHeight = 11,
		healthHeight = 14,
		portrait = 28,
		fontSize = 11,
		point = {'BOTTOM', UIParent, 'BOTTOM', -250, 207},
	},
}

-- A frame may override any layout value; anything it does not name falls back.
for _, config in pairs(Umbra.frames) do
	setmetatable(config, {__index = Umbra.layout})
end

function Umbra:FrameHeight(config)
	local height = config.nameHeight + config.gap + config.healthHeight
		+ config.gap + config.powerHeight

	if config.classPower then
		height = height + config.gap + config.pipHeight
	end

	return height
end
