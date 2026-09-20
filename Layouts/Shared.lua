local _, ns = ...
local Umbra = ns.Umbra
local oUF = ns.oUF

local colors = Umbra.colors

local CreateColorLayer = Umbra.Widgets.ColorLayer
local CreateText = Umbra.Widgets.Text
local CreateBar = Umbra.Widgets.Bar

--[[ The Umbra style
One style for every single frame. What differs between them lives in
Umbra.frames as a config, and anything a config does not name falls back to
the shared layout through its metatable.

The widgets themselves are in Layouts/Widgets.lua, the tags in Layouts/Tags.lua
and the aura containers in Layouts/Auras.lua. The geometry rule that all of
them follow is written down in Widgets.lua.
--]]

--[[ Tooltip(frame)
The tooltip you get from pointing at a unit in the world, on the frame that
stands for it.

oUF leaves this to the layout, which is easy to miss because it does set the
click attributes: it builds a SecureUnitButton with `*type1 = target` and no
`OnEnter` at all, and the only tooltips in the library are ones single
elements put on themselves.

**Blizzard's own `UnitFrame_OnEnter` cannot be used here.** It reads
`self.unit`, and an oUF frame has no such field: the unit lives in
`frame.__unit`, which `Private.UpdateUnits` keeps current, and again as the
secure `unit` attribute. Handing our frames to it threw
`bad argument #1 to GetUnit` on every hover, because what reached
`C_TooltipInfo.GetUnit` was nil.

So the unit is asked for through `Umbra:FrameUnit`, which knows where oUF
actually keeps it.
--]]
local function Tooltip(frame)
	frame:SetScript('OnEnter', function(self)
		local unit = Umbra:FrameUnit(self)

		-- Normally a frame for a unit that is not there is hidden by
		-- RegisterUnitWatch. Unlocking lets go of that watch on purpose, so
		-- pointing at an empty frame is an expected state and says nothing.
		if not unit or not UnitExists(unit) then return end

		if GameTooltip:IsForbidden() then return end

		-- SetDefaultAnchor puts the tooltip where the client's own setting
		-- says it goes, including "anchored to the cursor". A plain owner is
		-- what is left where that helper is missing, as it may be on Forever.
		if not pcall(GameTooltip_SetDefaultAnchor, GameTooltip, self) then
			GameTooltip:SetOwner(self, 'ANCHOR_BOTTOMRIGHT')
		end

		GameTooltip:SetUnit(unit)
	end)

	frame:SetScript('OnLeave', function()
		if GameTooltip:IsForbidden() then return end

		GameTooltip:Hide()
	end)
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

	Tooltip(self)

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

	-- Every number on the right edge shares this inset, so they stack into one
	-- column. The health percentage needs it because it sits inside its own
	-- bar and has to clear the bar's edge; the power percentage sits in the
	-- header with no bar around it and would otherwise sit an inset further
	-- out than the number directly below it.
	local valueRight = l.inset * 2

	local nameWidth = columnWidth

	-- Power is a hairline and cannot hold a label, so the number goes in the
	-- header where there is room for it. Only worth the space on the player.
	if config.powerValue then
		-- The name stops a gap short of the number column.
		nameWidth = (width - valueRight - l.valueWidth - l.gap) - columnX

		local powerValue = CreateText(self, 'RIGHT', l.fontSize)
		powerValue:SetPoint('TOPRIGHT', self, 'TOPRIGHT', -valueRight, 0)
		powerValue:SetSize(l.valueWidth, l.nameHeight)
		powerValue:SetTextColor(unpack(colors.muted))

		-- The number reads in the color of the bar it belongs to. oUF's
		-- powercolor tag opens a color escape from the client's own
		-- PowerBarColor, the same route [umbra:identity] takes for a class
		-- color, so nothing has to be read off a hidden value. The muted
		-- color above stays as what shows if the escape ever comes back
		-- empty.
		self:Tag(powerValue, '[powercolor][perpp]%|r')
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
	healthPercent:SetPoint('TOPRIGHT', self, 'TOPRIGHT', -valueRight, healthY)
	healthPercent:SetSize(l.valueWidth, l.healthHeight)

	-- Power colors come from oUF's table, which Core/Defaults.lua restates
	-- where Umbra disagrees with the client. No colorPowerAtlas: a bar painted
	-- with one of Blizzard's textures has no color for the number above it to
	-- match, and at four pixels tall there is no texture to see anyway.
	local power = CreateBar(self, colors.muted)
	power:SetPoint('TOPLEFT', self, 'TOPLEFT', columnX, powerY)
	power:SetSize(columnWidth, l.powerHeight)
	power.colorPower = true
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

	-- Kept so that a set switch can re-anchor this frame's rows later
	-- without having to work out which config it was built from.
	self.umbraConfig = config

	Umbra:AddAuras(self, unit, config)

	self:Tag(name, '[umbra:identity][name]|r')
	self:Tag(healthValue, '[umbra:health]')
	self:Tag(healthPercent, '[perhp]%')
end

oUF:RegisterStyle('Umbra', Style)
