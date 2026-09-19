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
	-- The health bar stays neutral so that class color means class and nothing
	-- else. This is also what keeps the bar working inside encounters: a fixed
	-- color needs no curve evaluated against a secret health value.
	health = {0.306, 0.478, 0.333},

	-- Dark enough to carry light text. The interface accent is too bright to
	-- put a label on, and a cast bar is unit information rather than chrome.
	cast = {0.541, 0.416, 0.173},

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
	pet = {
		width = 150,
		point = {'BOTTOM', UIParent, 'BOTTOM', -250, 205},
	},
}

function Umbra:FrameHeight(config)
	local l = self.layout
	local height = l.nameHeight + l.gap + l.healthHeight + l.gap + l.powerHeight

	if config and config.classPower then
		height = height + l.gap + l.pipHeight
	end

	return height
end
