local _, ns = ...
local Umbra = ns.Umbra

--[[ Themes
Two sets of colors for the interface around a unit, and nothing else. On WoW:
Forever the frames take on the client's own look — near-black plates with a
line of bronze along their edge — and everywhere else they stay the slate and
teal they have always been. `/uuf theme` picks one by name, and `auto`, the
default, picks by client. The options window and the onboarding go one step
further on Forever itself: there they wear the client's own window frame
(`Core/Window.lua`). Under the Forever theme on any other client they wear
the palette, a bronze border and a gold title.

**A theme changes the interface, never the unit.** The health bar, incoming
healing, the absorbs, the class and reaction colors, the resources and the
harmful underline are the same in both, so the line under the README's design
principles holds whichever is on: accent color belongs to the interface,
class color to the unit, the health bar to health. What a theme may change is listed in
THEMED below, and nothing outside that list is ever touched.

The Forever values were sampled on 7 November 2026 off lossless screenshots of
the client's own art: the tooltip and the zone plaque are flat dark panels
with a one-pixel bronze line, lit from the top left, and that is what a frame
body wears here. A second pass then tried to break them, and moved three:

- The rim, the accent and the muted text all sat within 10 CIEDE2000 of the
  warrior class color, so a warrior's edge read as one more side of a bronze
  frame. Each is now at least 11 away, and the rim draws no line down the
  left side, which stays the class edge's.
- The cast bar moved from its old gold to an amber: under bronze chrome the
  old color read as chrome, and a cast is unit information.
- The rim is one physical pixel, not one unit. At 1.3125 pixels per unit a
  unit renders as one pixel in one place and two in the next.

**Switching repaints what is already built.** Every setting takes effect where
you stand, and colors are no exception, so everything painted from the palette
at build time is painted through `Umbra:Paint`, which remembers it. A switch
rewrites the palette in place — files hold on to `Umbra.colors` and to its
inner tables, so a new table would leave them stale — and paints every
remembered region again. What a runtime path colors on its own (the health
fill, the power line, the class-power pips, a dispel underline) is not
remembered. Where such a surface has a palette color underneath until its
owner speaks — the class edge and portrait tint, the power percentage, a
helpful underline — that placeholder is remembered, and the owner is asked to
put the unit's color back over it straight after the repaint.
--]]

local colors = Umbra.colors

-- The keys a theme may change. Both palettes carry every one of them, so a
-- table captured by reference exists from the start, and a switch back
-- leaves nothing of the other palette behind.
local THEMED = {
	'background', 'border', 'portraitGround', 'text', 'muted', 'accent',
	'auraHelpful', 'cast', 'title', 'rimTop', 'rimRight', 'rimBottom',
}

local function RGB(r, g, b, a)
	return {r / 255, g / 255, b / 255, a}
end

local function Copy(color)
	return {color[1], color[2], color[3], color[4]}
end

Umbra.palettes = {
	-- Filled below from `Umbra.colors` as Core/Defaults.lua wrote it, so the
	-- slate and teal are written down once.
	umbra = {},

	forever = {
		-- Forever's plaque measured #110D09 and its tooltip #161017; this is
		-- a touch lighter than either, without the tooltip's violet, and
		-- keeps the plate's own opacity.
		background = RGB(21, 18, 15, 0.96),

		-- The black band Forever lays under every bronze line.
		border = RGB(10, 8, 6),

		portraitGround = RGB(38, 34, 28),
		text = RGB(240, 233, 218),

		-- Nearly neutral, and far from the warrior's tan.
		muted = RGB(166, 160, 148),

		-- From Forever's specular highlights: the minimap ring's lip and the
		-- plaque's corner.
		accent = RGB(240, 204, 140),

		auraHelpful = RGB(166, 160, 148),

		-- 4.13:1 under white, 3.42:1 under the text color.
		cast = RGB(186, 104, 22),

		-- `NORMAL_FONT_COLOR`, measured off "Aktive Quests" as #FFD200. Only
		-- ever on a window's title: on a frame it would be the yellow of the
		-- target level's difficulty.
		title = {1, 0.82, 0},

		-- Forever's own panel lines run from #9A846B at the top to #8B6E4A
		-- at the bottom, lit from the top left, so the right side is a step
		-- darker than the top.
		rimTop = RGB(154, 128, 92),
		rimRight = RGB(128, 104, 72),
		rimBottom = RGB(104, 80, 52),
	},
}

for _, key in ipairs(THEMED) do
	Umbra.palettes.umbra[key] = Copy(colors[key])
end

-- Whether a frame body wears the rim. Under Umbra's own colors it does not,
-- which is how every frame has looked since the first release.
local RIMMED = {umbra = false, forever = true}

--[[ Umbra:ThemeName()
The palette in force: the one chosen by name, or by client for `auto`. Safe
before the saved variables exist, though nothing asks that early: what is
painted at file load goes through Paint, and ApplyTheme repaints it once the
choice can be read.
--]]
function Umbra:ThemeName()
	local chosen = UmbraUnitFramesDB and UmbraUnitFramesDB.theme

	if chosen == 'umbra' or chosen == 'forever' then
		return chosen
	end

	return self.isForever and 'forever' or 'umbra'
end

--[[ Umbra:Paint(region, color, alpha, method)
Paints a region from a palette color and remembers it, so a theme switch can
paint it again. The last call for a region wins, which is what lets a label
built in the text color by `Widgets.Text` be repainted muted by its owner.

`color` is the palette's own table, not a copy: a switch rewrites that table,
and the repaint reads it again. `alpha` overrides the color's own fourth
value. `method` is only needed for a texture that carries art of its own and
takes its color as a vertex color; everything else is told apart by type.
--]]
local painted = setmetatable({}, {__mode = 'k'})

local function Apply(region, entry)
	local color = entry.color
	local r, g, b = color[1], color[2], color[3]
	local a = entry.alpha or color[4] or 1
	local kind = entry.method or region:GetObjectType()

	if kind == 'vertex' then
		region:SetVertexColor(r, g, b, a)
	elseif kind == 'Texture' then
		region:SetColorTexture(r, g, b, a)
	elseif kind == 'FontString' or kind == 'EditBox' then
		region:SetTextColor(r, g, b, a)
	elseif kind == 'StatusBar' then
		region:SetStatusBarColor(r, g, b, a)
	end
end

function Umbra:Paint(region, color, alpha, method)
	if not region or not color then return region end

	local entry = {color = color, alpha = alpha, method = method}
	painted[region] = entry
	Apply(region, entry)

	return region
end

--[[ The rim
Three lines on a frame body's own outermost pixels — top, right and bottom —
and none down the left, which belongs to the class edge. The top and bottom
lines start where the portrait begins, so the left side is the class edge and
the dark gap beside it, both on the body's whole height, and the bronze frames
the portrait and the bars. Started where the edge ends, the lines capped that
gap at both ends and boxed it in; asked on 8 November 2026, after both were
laid side by side on lossless screenshots. While the rim lay outside, an edge
that stopped a pixel short of the lines read as standing outside the frame;
inside, the edge reaches the body's first and last row just as the lines do.
The colors stay at least 11 CIEDE2000 from the warrior's tan, though with the
gap between them the two no longer touch.

**Inside the body, not around it.** It began a pixel outside, and two things
Umbra had kept exact came apart: the frame stood a pixel wider on the right
than the cast bar under it and the aura row over it, all three cut to the same
222 units; and where two frames are stacked two units apart — the target of
the target over the target — the two lines filled the gap like a groove.
Inside, every edge is where the metrics put it, stacked frames keep their gap,
and the line belongs to the plate the way the line on Forever's own tooltip
does. Moved on 8 November 2026, after both were laid side by side on lossless
screenshots. What it costs is the outermost pixel of whatever touches the
edge: the last row of the power hairline or the class-power pips, the first
and last row of the portrait, the last row of the level plate, and on a party
member the first row of the role mark.

One physical pixel each, worked out from the region's effective scale and
`PixelUtil.GetPixelToUIUnitFactor()`, which every client has. A frame's own
scale is set before its rim is measured and never changes after — the
onboarding's preview, at 1.15, is the one that has one — so a change of UI
scale or of the screen's resolution is the only thing that moves the answer,
and the rims are measured again then.

The lines are textures of a child frame of their own, a few levels above the
frame: regions of the frame itself would draw under every child — the
portrait, its 2D stand-in, the bars, the level plate — and be covered
wherever one touches the edge. The child sits above the level plate and below
the mover's overlay, and takes no mouse, so a click still reaches the unit.
--]]
local rims = {}

local function PixelSize(region)
	local util = type(_G.PixelUtil) == 'table' and PixelUtil
	local factor = util and type(util.GetPixelToUIUnitFactor) == 'function'
		and util.GetPixelToUIUnitFactor()
	local scale = region:GetEffectiveScale()

	if not factor or not scale or scale <= 0 then return 1 end

	return factor / scale
end

-- The windows' frame on Forever draws one-pixel lines of its own
-- (Core/Window.lua), measured the same way.
Umbra.PixelSize = PixelSize

--[[ Umbra:Outline(region, frame, inward)
The one-unit border of a window of ours, which the Forever theme turns into
its bronze line. A unit renders as one pixel in one place and two in the
next, which a near-black border hid and a bronze one does not, so under a
rimmed theme it is one physical pixel instead. Under Umbra's own theme it is
the unit it always was. `inward` is for a window whose border is its own area
with the ground inset, rather than a texture lying outside it. On Forever the
options window and the onboarding hide it inside the client's own frame.

Windows are not secure, so this is placed again whenever it changes, fight or
no fight.
--]]
local outlines = {}

local function PlaceOutline(outline)
	local d = RIMMED[Umbra:ThemeName()] and PixelSize(outline.frame) or 1

	if outline.inward then d = -d end

	outline.region:ClearAllPoints()
	outline.region:SetPoint('TOPLEFT', outline.frame, 'TOPLEFT', -d, d)
	outline.region:SetPoint('BOTTOMRIGHT', outline.frame, 'BOTTOMRIGHT', d, -d)
end

function Umbra:Outline(region, frame, inward)
	local outline = {region = region, frame = frame, inward = inward}

	outlines[#outlines + 1] = outline
	PlaceOutline(outline)

	return region
end

local function SizeRim(rim)
	local px = PixelSize(rim.owner)
	local span = rim.width - rim.start - px

	-- The right line runs the full height and owns both corners; the top and
	-- bottom start where the portrait begins and end where the right line
	-- begins, a pixel short of the frame's edge, so nothing is drawn twice.
	rim.top:ClearAllPoints()
	rim.top:SetPoint('TOPLEFT', rim.owner, 'TOPLEFT', rim.start, 0)
	rim.top:SetSize(span, px)

	rim.right:ClearAllPoints()
	rim.right:SetPoint('TOPRIGHT', rim.owner, 'TOPRIGHT', 0, 0)
	rim.right:SetSize(px, rim.height)

	rim.bottom:ClearAllPoints()
	rim.bottom:SetPoint('BOTTOMLEFT', rim.owner, 'BOTTOMLEFT', rim.start, 0)
	rim.bottom:SetSize(span, px)
end

local function ShowRim(rim, shown)
	rim.top:SetShown(shown)
	rim.right:SetShown(shown)
	rim.bottom:SetShown(shown)
end

-- How far above the frame the lines sit: over the portrait (+2), its 2D
-- stand-in (+3) and the level plate (+4) that Layouts/Shared.lua stacks, and
-- under the mover's overlay (+10).
local RIM_LEVEL = 5

-- `start` is where the portrait begins, past the class edge and its gap:
-- where the top and bottom lines begin.
function Umbra:Rim(frame, start, width, height)
	local rim = {owner = frame, start = start, width = width, height = height}

	local holder = CreateFrame('Frame', nil, frame)
	holder:SetPoint('TOPLEFT', frame, 'TOPLEFT', 0, 0)
	holder:SetSize(width, height)
	holder:SetFrameLevel(frame:GetFrameLevel() + RIM_LEVEL)
	rim.holder = holder

	rim.top = self:Paint(holder:CreateTexture(nil, 'OVERLAY'), colors.rimTop)
	rim.right = self:Paint(holder:CreateTexture(nil, 'OVERLAY'), colors.rimRight)
	rim.bottom = self:Paint(holder:CreateTexture(nil, 'OVERLAY'), colors.rimBottom)

	SizeRim(rim)
	ShowRim(rim, RIMMED[self:ThemeName()])

	rims[#rims + 1] = rim

	return rim
end

--[[ A new UI scale
Measured again at once, in a fight as much as out of one. The lines are
textures of the rim's own plain frame, only anchored to the unit's button, and
the windows are not secure at all; a party member's frame built mid-fight sizes
its rim the same way.
--]]
local scaler = CreateFrame('Frame')

local function SizeAll()
	for _, rim in ipairs(rims) do
		SizeRim(rim)
	end

	for _, outline in ipairs(outlines) do
		PlaceOutline(outline)
	end
end

scaler:SetScript('OnEvent', SizeAll)

Umbra:RegisterEvent(scaler, 'UI_SCALE_CHANGED')
Umbra:RegisterEvent(scaler, 'DISPLAY_SIZE_CHANGED')

--[[ Umbra:ApplyTheme()
Rewrites the palette in place, paints every remembered region again, and asks
the runtime paths to look again. Nothing here is protected, so it is a result
in a fight as much as out of one. Called once from ADDON_LOADED, before any
frame is built, and again from every switch.

Inside an instance a region can carry an aspect the client will not let us
recolor; one refusal is reported and the rest carry on.
--]]
function Umbra:ApplyTheme()
	local name = self:ThemeName()
	local palette = self.palettes[name]

	for _, key in ipairs(THEMED) do
		local into, from = colors[key], palette[key]
		into[1], into[2], into[3], into[4] = from[1], from[2], from[3], from[4]
	end

	local refused

	for region, entry in pairs(painted) do
		local ok, err = pcall(Apply, region, entry)

		if not ok and not refused then
			refused = err
		end
	end

	if refused then
		self:Debug('theme repaint refused:', refused)
	end

	for _, rim in ipairs(rims) do
		ShowRim(rim, RIMMED[name])
	end

	for _, outline in ipairs(outlines) do
		PlaceOutline(outline)
	end

	-- The level in front of the name keeps its color as a cached escape.
	if self.ResetTagColors then
		self.ResetTagColors()
	end

	-- An open report carries its colors in its text; it is written again.
	if self.RecolorReports then
		self.RecolorReports()
	end

	local oUF = ns.oUF

	for _, frame in ipairs(oUF and oUF.objects or {}) do
		-- Probe frames of the header test sit in oUF.objects too, and carry
		-- none of this.
		if frame.umbraConfig then
			frame:UpdateTags()

			if self.RefreshOwnAuras then
				self.RefreshOwnAuras(frame)
			end
		end
	end

	-- The repaint put the muted placeholder back on every class edge and
	-- portrait tint; this puts the unit's color back where there is a unit.
	if self.ApplyHealthStyle then
		self:ApplyHealthStyle()
	end

	-- The options window and the onboarding wear Forever's own window frame
	-- on that client under this theme, and their flat look everywhere else;
	-- Core/Window.lua shows the one and hides the other, once they are built.
	if self.ApplyWindowLook then
		self:ApplyWindowLook()
	end

	return true
end
