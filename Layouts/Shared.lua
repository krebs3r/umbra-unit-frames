local _, ns = ...
local Umbra = ns.Umbra
local oUF = ns.oUF

local layout, colors, media = Umbra.layout, Umbra.colors, Umbra.media

--[[ Geometry rule
Every widget gets an explicit size and a single anchor to the frame itself.

Nothing may derive its size from a widget that receives unit data. A widget
handed a hidden value reports hidden geometry, and that spreads along the
anchor chain: oUF asks the health bar for its width on every update, and a bar
sized by anchors to a tag'd font string answers with a value it cannot do
arithmetic on. Explicit sizes keep that question answerable.
--]]

local DECIMAL = _G.DECIMAL_SEPERATOR or '.'

local function Decimal(number)
	local text = ('%.1f'):format(number)

	if DECIMAL ~= '.' then
		text = text:gsub('%.', DECIMAL, 1)
	end

	return text
end

--[[ FormatHealth(value)
Health at a glance: three significant digits and a magnitude.

The client's own helpers are not dependable for this. AbbreviateNumbers works
off locale-specific breakpoints and hands back the raw digits in locales that
have no thousands step, which is how a bar came to read 29408.
--]]
local function FormatHealth(value)
	if value >= 1e6 then
		return Decimal(value / 1e6) .. 'M'
	elseif value >= 1e3 then
		return Decimal(value / 1e3) .. 'k'
	end

	return ('%d'):format(value)
end

--[[ CreateColorLayer(parent, alpha)
A flat, single-color surface that can carry a class color.

Inside an instance a unit's class is hidden and C_ClassColor answers with a
hidden color. SetStatusBarColor takes those; SetColorTexture and SetVertexColor
have no such guarantee. So anything tinted by class identity is a StatusBar
pinned to full rather than a plain texture.
--]]
local function CreateColorLayer(parent, alpha)
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

local function CreateText(parent, justify, size)
	local fs = parent:CreateFontString(nil, 'OVERLAY')
	fs:SetFont(media.font, size or layout.fontSize)
	fs:SetJustifyH(justify)
	fs:SetJustifyV('MIDDLE')
	fs:SetTextColor(unpack(colors.text))

	-- Text sits on top of filled bars, whose color is not ours to choose in
	-- every case. A shadow keeps it legible without an outline font.
	fs:SetShadowColor(0, 0, 0, 0.85)
	fs:SetShadowOffset(1, -1)

	return fs
end

local function CreateBar(parent, color)
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
	if layout.barShade > 0 then
		local shade = bar:CreateTexture(nil, 'ARTWORK', nil, 1)
		shade:SetAllPoints()
		shade:SetColorTexture(1, 1, 1, 1)

		-- Without the gradient this is a white block over the bar, so it only
		-- stays if the gradient took.
		if not pcall(shade.SetGradient, shade, 'VERTICAL',
			CreateColor(0, 0, 0, layout.barShade),
			CreateColor(1, 1, 1, layout.barGloss)) then
			shade:Hide()
		end
	end

	return bar
end

local function UpdateIdentity(element, unit)
	local color = Umbra.Secrets.UnitColor(unit)
	if not color then return end

	local frame = element.__owner
	frame.ClassEdge:SetStatusBarColor(color:GetRGB())
	frame.PortraitTint:SetStatusBarColor(color:GetRGB())
end

local function Style(self, unit)
	-- Frame configs fall back to the shared layout, so `l` answers for both.
	local config = Umbra.frames[unit] or Umbra.frames.player
	local l = config

	local width, height = config.width, Umbra:FrameHeight(config)
	local columnX = l.classEdge + l.gap + l.portrait + l.gap
	local columnWidth = width - columnX - l.inset
	local healthY = -(l.nameHeight + l.gap)
	local powerY = healthY - (l.healthHeight + l.gap)
	local pipY = powerY - (l.powerHeight + l.gap)

	self:SetSize(width, height)
	self:RegisterForClicks('AnyUp')

	local background = self:CreateTexture(nil, 'BACKGROUND')
	background:SetAllPoints()
	background:SetColorTexture(unpack(colors.background))

	-- Class color lives here and on the name, never on the health bar.
	local edge = CreateColorLayer(self)
	edge:SetPoint('TOPLEFT', self, 'TOPLEFT', 0, 0)
	edge:SetSize(l.classEdge, height)
	self.ClassEdge = edge

	-- A PlayerModel renders on nothing, so without a ground of its own the
	-- portrait shows whatever is behind the frame, and the class tint above it
	-- lands on that instead of on a neutral surface.
	local ground = self:CreateTexture(nil, 'BACKGROUND', nil, 1)
	ground:SetPoint('TOPLEFT', self, 'TOPLEFT', l.classEdge + l.gap, 0)
	ground:SetSize(l.portrait, height)
	ground:SetColorTexture(unpack(colors.portraitGround))

	local portrait = CreateFrame('PlayerModel', nil, self)
	portrait:SetPoint('TOPLEFT', self, 'TOPLEFT', l.classEdge + l.gap, 0)
	portrait:SetSize(l.portrait, height)
	self.Portrait = portrait

	local tint = CreateColorLayer(self, 0.13)
	tint:SetPoint('TOPLEFT', self, 'TOPLEFT', l.classEdge + l.gap, 0)
	tint:SetSize(l.portrait, height)
	tint:SetFrameLevel(portrait:GetFrameLevel() + 1)
	self.PortraitTint = tint

	local nameWidth = columnWidth

	-- Power is a hairline and cannot hold a label, so the number goes in the
	-- header where there is room for it. Only worth the space on the player.
	if config.powerValue then
		nameWidth = columnWidth - l.valueWidth - l.gap

		local powerValue = CreateText(self, 'RIGHT', l.fontSize)
		powerValue:SetPoint('TOPRIGHT', self, 'TOPRIGHT', -l.inset, 0)
		powerValue:SetSize(l.valueWidth, l.nameHeight)
		powerValue:SetTextColor(unpack(colors.muted))
		self:Tag(powerValue, '[perpp]%')
	end

	local name = CreateText(self, 'LEFT', l.fontSize)
	name:SetPoint('TOPLEFT', self, 'TOPLEFT', columnX, 0)
	name:SetSize(nameWidth, l.nameHeight)

	-- No color flag is set, so oUF leaves the color applied here alone and
	-- never evaluates a curve against a hidden value.
	local health = CreateBar(self, colors.health)
	health:SetPoint('TOPLEFT', self, 'TOPLEFT', columnX, healthY)
	health:SetSize(columnWidth, l.healthHeight)
	health.PostUpdateColor = UpdateIdentity
	self.Health = health

	-- Parented to the bar so they draw above it, but anchored to the frame so
	-- that no geometry is routed through a widget that receives unit data.
	local healthValue = CreateText(health, 'LEFT', l.fontSize)
	healthValue:SetPoint('TOPLEFT', self, 'TOPLEFT', columnX + l.inset, healthY)
	healthValue:SetSize(columnWidth - l.valueWidth - l.inset * 2, l.healthHeight)

	local healthPercent = CreateText(health, 'RIGHT', l.fontSize)
	healthPercent:SetPoint('TOPRIGHT', self, 'TOPRIGHT', -(l.inset * 2), healthY)
	healthPercent:SetSize(l.valueWidth, l.healthHeight)

	-- Power colors come from the client's own PowerBarColor table, and where
	-- Blizzard ships a texture for a resource, colorPowerAtlas uses that
	-- rather than a flat approximation of it.
	local power = CreateBar(self, colors.muted)
	power:SetPoint('TOPLEFT', self, 'TOPLEFT', columnX, powerY)
	power:SetSize(columnWidth, l.powerHeight)
	power.colorPower = true
	power.colorPowerAtlas = true
	self.Power = power

	if config.classPower then
		local pips = {}

		for index = 1, 10 do
			local pip = CreateBar(self, colors.accent)
			pip:SetPoint('TOPLEFT', self, 'TOPLEFT', columnX, pipY)
			pip:SetSize(columnWidth, l.pipHeight)
			pip:Hide()
			pips[index] = pip
		end

		-- How many points the class has is not known until oUF reports it,
		-- and it changes with specialisation, so the row is laid out then.
		pips.PostUpdate = function(element, _, max, _, hasMaxChanged)
			if not hasMaxChanged or not max or max < 1 then return end

			local slot = (columnWidth - (max - 1) * l.gap) / max

			for index = 1, max do
				element[index]:ClearAllPoints()
				element[index]:SetPoint('TOPLEFT', self, 'TOPLEFT',
					columnX + (index - 1) * (slot + l.gap), pipY)
				element[index]:SetSize(slot, l.pipHeight)
			end
		end

		self.ClassPower = pips
	end

	if config.castbar then
		local castbar = CreateBar(self, colors.cast)
		castbar:SetPoint('TOPLEFT', self, 'BOTTOMLEFT', 0, -l.gap)
		castbar:SetSize(width, l.castbarHeight)

		castbar.Text = CreateText(castbar, 'LEFT', l.fontSize)
		castbar.Text:SetPoint('LEFT', castbar, 'LEFT', l.inset, 0)
		castbar.Text:SetSize(width - l.valueWidth - l.inset * 3, l.castbarHeight)

		castbar.Time = CreateText(castbar, 'RIGHT', l.fontSize)
		castbar.Time:SetPoint('RIGHT', castbar, 'RIGHT', -l.inset, 0)
		castbar.Time:SetSize(l.valueWidth, l.castbarHeight)
		castbar.Time:SetTextColor(unpack(colors.muted))

		self.Castbar = castbar
	end

	self:Tag(name, '[umbra:identity][name]|r')
	self:Tag(healthValue, '[umbra:health]')
	self:Tag(healthPercent, '[perhp]%')
end

--[[ Abbreviating a value we are not allowed to read
AbbreviateNumbers shortens hidden values, because the client does the work
natively rather than handing the number to us first. What it will not do is
invent a thousands step for a locale that has none, and German has none, which
is why health read as an unbroken run of digits for so long.

Passing our own breakpoints fixes that. The shape mirrors what
C_StringUtil.GetDefaultAbbreviationBreakpoints returns: the client divides by
significandDivisor, floors, divides by fractionDivisor, and appends the
abbreviation. abbreviationIsGlobal false means the text is literal rather than
the name of a global holding a localized string.
--]]
local abbreviation

local function AbbreviationOptions()
	if abbreviation then return abbreviation end

	abbreviation = {
		breakpointData = {
			{breakpoint = 1000000, abbreviation = 'M', significandDivisor = 10000,
				fractionDivisor = 100, abbreviationIsGlobal = false},
			{breakpoint = 1000, abbreviation = 'K', significandDivisor = 100,
				fractionDivisor = 10, abbreviationIsGlobal = false},
			{breakpoint = 1, abbreviation = '', significandDivisor = 1,
				fractionDivisor = 1, abbreviationIsGlobal = false},
		},
	}

	if CreateAbbreviateConfig then
		abbreviation.config = CreateAbbreviateConfig(abbreviation.breakpointData)
	end

	return abbreviation
end

oUF.Tags.Methods['umbra:health'] = function(unit)
	local current = UnitHealth(unit)

	if not AbbreviateNumbers then
		return Umbra.Secrets.Is(current) and current or FormatHealth(current)
	end

	local ok, text = pcall(AbbreviateNumbers, current, AbbreviationOptions())
	if ok then return text end

	-- Our breakpoints were refused; the client's own still beat raw digits.
	return AbbreviateNumbers(current)
end

oUF.Tags.Events['umbra:health'] = 'UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION'

--[[ Tag: umbra:identity
Opens a color escape for the unit's class or reaction color.

GenerateHexColorMarkup works on a hidden color, which is why the name can stay
class-colored inside an instance even though we cannot read the class.
--]]
oUF.Tags.Methods['umbra:identity'] = function(unit)
	local color = Umbra.Secrets.UnitColor(unit)
	return color and color:GenerateHexColorMarkup() or ''
end

oUF.Tags.Events['umbra:identity'] = 'UNIT_FACTION UNIT_FLAGS'

oUF:RegisterStyle('Umbra', Style)
