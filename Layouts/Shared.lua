local _, ns = ...
local Umbra = ns.Umbra
local oUF = ns.oUF

local colors = Umbra.colors

local CreateColorLayer = Umbra.Widgets.ColorLayer
local CreateText = Umbra.Widgets.Text
local CreateBar = Umbra.Widgets.Bar
local CreatePrediction = Umbra.Widgets.Prediction

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

--[[ A portrait the client was not ready to give yet
oUF sets the model once, when the unit changes, and never asks again. That is
enough for the player and the pet, whose models are loaded because they are
standing there. It is not enough for a target picked up in a dungeon.

Measured in *Der Steinerne Kern* on 20 September 2026, with `/uuf check`:

	portrait target: UnitIsConnected: readable — true
	portrait target: UnitIsVisible:   readable — true
	portrait target: model: readable — nil

Both halves of oUF's condition readable and true, so it took the real branch
and called `SetUnit` — and the client had nothing to give it. Nothing is
hidden here and nothing is misanchored; the model had simply not streamed in
yet, and oUF's one shot had already been spent. The portrait then stays empty
for that target for as long as it is the target.

DialogueUI answers a related problem by asking `IsUnitModelReadyForUI` and
coming back later when the answer is no. **Gating the retry on that was a
mistake**, and the first version of this made it: the target came back
`model: nil` again on the next run, and the chain had very likely never
started. A gate on an API nobody here had measured is exactly the assumption
this file exists to prevent — if the client answers "ready" while handing over
nothing, the retry never runs and the measurement never happens.

So it now runs on the **symptom** alone, a model file that is plainly nil, and
`/uuf check` asks the ready question separately, where the answer is data
rather than a decision. The retry goes through the element's own
`ForceUpdate`, so the model is still set by oUF's code rather than by a second
copy of it that could drift.

Bounded on purpose: a unit that will never have a model must not leave a timer
running behind it, and that bound is what makes a symptom safe to act on while
the cause is still unknown. It reports itself through `Umbra:Debug`, because a
chain that never ran and one that ran and failed are otherwise the same empty
square.
--]]
local PORTRAIT_RETRIES = 8
local PORTRAIT_DELAY = 0.5

--[[ ModelPending(element)
Whether a model is missing that could still turn up.

A plain nil is the whole test. Anything else — a file id, or a hidden value we
are not allowed to look at — means there is nothing here to wait for.
--]]
local function ModelPending(element)
	if not element.GetModelFileID then return false end

	local ok, file = pcall(element.GetModelFileID, element)

	return ok and not Umbra.Secrets.Is(file) and file == nil
end

local function RetryPortrait(element, tries)
	C_Timer.After(PORTRAIT_DELAY, function()
		local frame = element.__owner
		local unit = frame and Umbra:FrameUnit(frame)

		if not unit or not UnitExists(unit) then
			element.umbraWaiting = nil
			return
		end

		element:ForceUpdate()

		if not ModelPending(element) then
			element.umbraWaiting = nil
			Umbra:Debug('portrait arrived for', unit, 'on try', tries)
			return
		end

		if tries >= PORTRAIT_RETRIES then
			element.umbraWaiting = nil
			Umbra:Debug('portrait never arrived for', unit, 'after', tries, 'tries')
			return
		end

		RetryPortrait(element, tries + 1)
	end)
end

--[[ PortraitPostUpdate(element, unit)
Starts one chain of retries, and only one.

The ForceUpdate inside the chain comes back through here, which is what the
flag is for: without it each attempt would start a chain of its own. Clearing
it when the chain ends is what lets the next target have its own.
--]]
local function PortraitPostUpdate(element, unit)
	if element.umbraWaiting then return end
	if not unit or not UnitExists(unit) then return end
	if not ModelPending(element) then return end

	element.umbraWaiting = true
	Umbra:Debug('portrait missing for', unit, '— waiting for it')
	RetryPortrait(element, 1)
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
	portrait.PostUpdate = PortraitPostUpdate
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

	--[[ What is coming to the bar, and what stands in front of it
	oUF's Health element owns these three and updates them itself, including
	their width: it sets each one as wide as the health bar on every size
	change. So only the height and the one anchor are ours.

	**That anchor is the exception to the geometry rule**, and it is the only
	way the arithmetic can happen at all. Incoming healing starts where
	current health ends, and `current + incoming` cannot be worked out here:
	both are hidden, and adding them throws. The client can do it, so the
	sum is expressed as an anchor — the healing bar begins at the right edge
	of the health fill, the absorb at the right edge of the healing fill —
	and the sum never passes through Lua.

	The rule itself is unharmed, because it is about *reading* geometry:
	nothing asks these bars how wide they came out. oUF sizes them from the
	health bar, whose rectangle is explicit, and otherwise only calls
	SetMinMaxValues and SetValue on them, both of which take hidden numbers.

	Each is as wide as the whole bar while starting somewhere inside it, so
	the overhang is clipped rather than drawn past the frame's edge.
	--]]
	health:SetClipsChildren(true)

	local predictionLevel = health:GetFrameLevel() + 1

	local healing = CreatePrediction(health, colors.healPrediction)
	healing:SetPoint('TOPLEFT', health:GetStatusBarTexture(), 'TOPRIGHT')
	healing:SetHeight(l.healthHeight)
	healing:SetFrameLevel(predictionLevel)
	health.HealingAll = healing

	local absorb = CreatePrediction(health, colors.absorb, true)
	absorb:SetPoint('TOPLEFT', healing:GetStatusBarTexture(), 'TOPRIGHT')
	absorb:SetHeight(l.healthHeight)
	absorb:SetFrameLevel(predictionLevel)
	health.DamageAbsorb = absorb

	-- The one that runs the other way: a heal absorb stands in front of
	-- health that is already there, so it fills backwards from the fill's
	-- own edge into the bar rather than outwards from it.
	local healAbsorb = CreatePrediction(health, colors.healAbsorb)
	healAbsorb:SetPoint('TOPRIGHT', health:GetStatusBarTexture(), 'TOPRIGHT')
	healAbsorb:SetReverseFill(true)
	healAbsorb:SetHeight(l.healthHeight)
	healAbsorb:SetFrameLevel(predictionLevel)
	health.HealAbsorb = healAbsorb

	-- The prediction bars are children of the health bar and therefore draw
	-- above everything the bar itself carries, its labels included. So the
	-- numbers move onto a layer above them, and an absorb can never cover the
	-- value it belongs to. Explicitly sized and anchored to the frame, like
	-- every other widget here; only the parent decides what draws on top.
	local labels = CreateFrame('Frame', nil, health)
	labels:SetPoint('TOPLEFT', self, 'TOPLEFT', columnX, healthY)
	labels:SetSize(columnWidth, l.healthHeight)
	labels:SetFrameLevel(predictionLevel + 1)

	local healthValue = CreateText(labels, 'LEFT', l.fontSize)
	healthValue:SetPoint('TOPLEFT', self, 'TOPLEFT', columnX + l.inset, healthY)
	healthValue:SetSize(columnWidth - l.valueWidth - l.inset * 2, l.healthHeight)

	local healthPercent = CreateText(labels, 'RIGHT', l.fontSize)
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
