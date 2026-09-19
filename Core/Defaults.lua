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

	background = {0.078, 0.098, 0.145, 0.96},
	border = {0.043, 0.055, 0.082},
	text = {0.902, 0.914, 0.941},
	muted = {0.553, 0.592, 0.671},
	accent = {0.459, 0.863, 0.769},
}

Umbra.layout = {
	classEdge = 3,
	portrait = 40,
	gap = 2,
	inset = 4,

	nameHeight = 14,
	healthHeight = 24,
	powerHeight = 4,
	castbarHeight = 16,

	fontSize = 12,
	rangeAlpha = 0.45,
}

Umbra.frames = {
	player = {
		width = 278,
		point = {'BOTTOM', UIParent, 'BOTTOM', -270, 260},
	},
	target = {
		width = 278,
		point = {'BOTTOM', UIParent, 'BOTTOM', 270, 260},
	},
}

function Umbra:FrameHeight()
	local l = self.layout
	return l.nameHeight + l.gap + l.healthHeight + l.gap + l.powerHeight
end
