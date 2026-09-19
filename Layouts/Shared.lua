local _, ns = ...
local Umbra = ns.Umbra
local oUF = ns.oUF

local layout, colors, media = Umbra.layout, Umbra.colors, Umbra.media

--[[ CreateColorLayer(parent, alpha)
A flat, single-color surface that can carry a class color.

Inside an instance a unit's class is secret and C_ClassColor answers with a
secret color. SetStatusBarColor takes those; SetColorTexture and SetVertexColor
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

local function CreateText(parent, justify)
	local fs = parent:CreateFontString(nil, 'OVERLAY')
	fs:SetFont(media.font, layout.fontSize)
	fs:SetJustifyH(justify)
	fs:SetTextColor(unpack(colors.text))
	return fs
end

local function UpdateIdentity(element, unit)
	local color = Umbra.Secrets.UnitColor(unit)
	if not color then return end

	local frame = element.__owner
	frame.ClassEdge:SetStatusBarColor(color:GetRGB())
	frame.PortraitTint:SetStatusBarColor(color:GetRGB())
end

local function Style(self, unit)
	local config = Umbra.frames[unit] or Umbra.frames.player

	self:SetSize(config.width, Umbra:FrameHeight())
	self:RegisterForClicks('AnyUp')

	local background = self:CreateTexture(nil, 'BACKGROUND')
	background:SetAllPoints()
	background:SetColorTexture(unpack(colors.background))

	-- Class color lives here and on the name, never on the health bar.
	local edge = CreateColorLayer(self)
	edge:SetPoint('TOPLEFT')
	edge:SetPoint('BOTTOMLEFT')
	edge:SetWidth(layout.classEdge)
	self.ClassEdge = edge

	local portrait = CreateFrame('PlayerModel', nil, self)
	portrait:SetPoint('TOPLEFT', edge, 'TOPRIGHT', layout.gap, 0)
	portrait:SetPoint('BOTTOMLEFT', edge, 'BOTTOMRIGHT', layout.gap, 0)
	portrait:SetWidth(layout.portrait)
	self.Portrait = portrait

	local tint = CreateColorLayer(self, 0.13)
	tint:SetAllPoints(portrait)
	tint:SetFrameLevel(portrait:GetFrameLevel() + 1)
	self.PortraitTint = tint

	local stack = CreateFrame('Frame', nil, self)
	stack:SetPoint('TOPLEFT', portrait, 'TOPRIGHT', layout.gap, 0)
	stack:SetPoint('BOTTOMRIGHT', self, 'BOTTOMRIGHT', -layout.inset, 0)

	local name = CreateText(stack, 'LEFT')
	name:SetPoint('TOPLEFT')
	name:SetHeight(layout.nameHeight)

	local healthValue = CreateText(stack, 'RIGHT')
	healthValue:SetPoint('TOPRIGHT')
	healthValue:SetHeight(layout.nameHeight)
	healthValue:SetTextColor(unpack(colors.muted))

	name:SetPoint('RIGHT', healthValue, 'LEFT', -layout.gap, 0)

	-- The bar stays neutral: no color flag is set, so oUF leaves the color we
	-- apply here alone and never evaluates a curve against a secret value.
	local health = CreateFrame('StatusBar', nil, stack)
	health:SetStatusBarTexture(media.bar)
	health:SetStatusBarColor(unpack(colors.health))
	health:SetPoint('TOPLEFT', name, 'BOTTOMLEFT', 0, -layout.gap)
	health:SetPoint('TOPRIGHT', healthValue, 'BOTTOMRIGHT', 0, -layout.gap)
	health:SetHeight(layout.healthHeight)
	health.PostUpdateColor = UpdateIdentity
	self.Health = health

	local healthBackground = health:CreateTexture(nil, 'BACKGROUND')
	healthBackground:SetAllPoints()
	healthBackground:SetColorTexture(unpack(colors.border))

	local power = CreateFrame('StatusBar', nil, stack)
	power:SetStatusBarTexture(media.bar)
	power:SetPoint('TOPLEFT', health, 'BOTTOMLEFT', 0, -layout.gap)
	power:SetPoint('TOPRIGHT', health, 'BOTTOMRIGHT', 0, -layout.gap)
	power:SetHeight(layout.powerHeight)
	power.colorPower = true
	self.Power = power

	local powerBackground = power:CreateTexture(nil, 'BACKGROUND')
	powerBackground:SetAllPoints()
	powerBackground:SetColorTexture(unpack(colors.border))

	local castbar = CreateFrame('StatusBar', nil, self)
	castbar:SetStatusBarTexture(media.bar)
	castbar:SetStatusBarColor(unpack(colors.accent))
	castbar:SetPoint('TOPLEFT', self, 'BOTTOMLEFT', 0, -layout.gap)
	castbar:SetPoint('TOPRIGHT', self, 'BOTTOMRIGHT', 0, -layout.gap)
	castbar:SetHeight(layout.castbarHeight)

	local castbarBackground = castbar:CreateTexture(nil, 'BACKGROUND')
	castbarBackground:SetAllPoints()
	castbarBackground:SetColorTexture(unpack(colors.background))

	castbar.Text = CreateText(castbar, 'LEFT')
	castbar.Text:SetPoint('LEFT', layout.inset, 0)

	castbar.Time = CreateText(castbar, 'RIGHT')
	castbar.Time:SetPoint('RIGHT', -layout.inset, 0)
	castbar.Time:SetTextColor(unpack(colors.muted))

	self.Castbar = castbar

	self:Tag(name, '[umbra:identity][name]|r')
	self:Tag(healthValue, '[perhp]%')
end

--[[ Tag: umbra:identity
Opens a color escape for the unit's class or reaction color.

GenerateHexColorMarkup works on a secret color, which is why the name can stay
class-colored inside an instance even though we cannot read the class.
--]]
oUF.Tags.Methods['umbra:identity'] = function(unit)
	local color = Umbra.Secrets.UnitColor(unit)
	return color and color:GenerateHexColorMarkup() or ''
end

oUF.Tags.Events['umbra:identity'] = 'UNIT_FACTION UNIT_FLAGS'

oUF:RegisterStyle('Umbra', Style)
