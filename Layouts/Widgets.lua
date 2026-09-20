local _, ns = ...
local Umbra = ns.Umbra

local metrics, colors, media = Umbra.metrics, Umbra.colors, Umbra.media

--[[ Geometry rule
Every widget gets an explicit size and a single anchor to the frame itself.

Nothing may derive its size from a widget that receives unit data. A widget
handed a hidden value reports hidden geometry, and that spreads along the
anchor chain: oUF asks the health bar for its width on every update, and a bar
sized by anchors to a tag'd font string answers with a value it cannot do
arithmetic on. Explicit sizes keep that question answerable.

The helpers below build the surfaces every frame is made of. None of them
anchors or sizes anything; that is the caller's job, and deliberately so.
--]]
local Widgets = {}
Umbra.Widgets = Widgets

--[[ Widgets.ColorLayer(parent, alpha)
A flat, single-color surface that can carry a class color.

Inside an instance a unit's class is hidden and C_ClassColor answers with a
hidden color. SetStatusBarColor takes those; SetColorTexture and SetVertexColor
have no such guarantee. So anything tinted by class identity is a StatusBar
pinned to full rather than a plain texture.
--]]
function Widgets.ColorLayer(parent, alpha)
	local bar = CreateFrame('StatusBar', nil, parent)
	bar:SetStatusBarTexture(media.bar)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(1)
	bar:SetStatusBarColor(unpack(colors.muted))

	if alpha then
		bar:SetAlpha(alpha)
	end

	return bar
end

function Widgets.Text(parent, justify, size)
	local fs = parent:CreateFontString(nil, 'OVERLAY')
	fs:SetFont(media.font, size or metrics.fontSize)
	fs:SetJustifyH(justify)
	fs:SetJustifyV('MIDDLE')
	fs:SetTextColor(unpack(colors.text))

	-- Text sits on top of filled bars, whose color is not ours to choose in
	-- every case. A shadow keeps it legible without an outline font.
	fs:SetShadowColor(0, 0, 0, 0.85)
	fs:SetShadowOffset(1, -1)

	return fs
end

--[[ Widgets.Prediction(parent, color, hatched)
A bar for health that is not there yet, or for something standing in front of
it: incoming healing, a damage absorb, a heal absorb.

No ground and no shading, unlike Widgets.Bar. These lie *on* the health bar
rather than beside it, and each is as wide as that bar while starting
somewhere in the middle of it — a ground of its own would paint over the rest
of the health bar with nothing in it.

`hatched` lays the stripe tile over the fill, which is how an absorb says it
is not health. The tile is a plain texture rather than the bar's own fill, so
that `SetHorizTile` repeats it at its native size instead of stretching one
copy across the whole region. It is white and takes its color here, and if the
file is ever missing the flat fill underneath is still the right color and the
right width.
--]]
function Widgets.Prediction(parent, color, hatched)
	local bar = CreateFrame('StatusBar', nil, parent)
	bar:SetStatusBarTexture(media.bar)
	bar:SetStatusBarColor(unpack(color))

	if hatched then
		local hatch = bar:CreateTexture(nil, 'OVERLAY')
		hatch:SetTexture(media.hatch, 'REPEAT', 'REPEAT')
		hatch:SetHorizTile(true)
		hatch:SetVertTile(true)
		hatch:SetVertexColor(1, 1, 1, 0.45)

		-- The one anchor in this file that goes to a fill. The region it has
		-- to cover is the one the client computed from a hidden value, and
		-- nothing here ever asks it how big that turned out to be.
		hatch:SetAllPoints(bar:GetStatusBarTexture())

		bar.Hatch = hatch
	end

	return bar
end

function Widgets.Bar(parent, color)
	local bar = CreateFrame('StatusBar', nil, parent)
	bar:SetStatusBarTexture(media.bar)
	bar:SetStatusBarColor(unpack(color))

	local background = bar:CreateTexture(nil, 'BACKGROUND')
	background:SetAllPoints()
	background:SetColorTexture(unpack(colors.border))

	-- A flat fill reads as paint rather than as a bar. The shading lies over
	-- the whole bar rather than over the fill, because the fill's geometry
	-- follows a hidden value and must not be anchored to. Sublevel 1 puts it
	-- above the fill and still below the labels.
	if metrics.barShade > 0 then
		local shade = bar:CreateTexture(nil, 'ARTWORK', nil, 1)
		shade:SetAllPoints()
		shade:SetColorTexture(1, 1, 1, 1)

		-- Without the gradient this is a white block over the bar, so it only
		-- stays if the gradient took.
		if not pcall(shade.SetGradient, shade, 'VERTICAL',
			CreateColor(0, 0, 0, metrics.barShade),
			CreateColor(1, 1, 1, metrics.barGloss)) then
			shade:Hide()
		end
	end

	return bar
end
