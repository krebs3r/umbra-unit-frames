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
--[[ StandIn(element, unit)
Covers the model with the client's own 2D portrait, or uncovers it.

`SetPortraitTexture` is what Blizzard's own unit frames use, and it is asked
for the same unit the model was asked for, so nothing is invented here: if the
client will not name this unit either, the stand-in is its question mark and
that is still an honest answer.
--]]
local function StandIn(element, unit, show)
	local flat = element.umbraFlat
	if not flat then return end

	if show and unit and type(_G.SetPortraitTexture) == 'function' then
		pcall(SetPortraitTexture, element.umbraFlatArt, unit)
	end

	flat:SetShown(show and true or false)
end

local function PortraitPostUpdate(element, unit)
	local missing = ModelPending(element)

	-- Covered the moment there is nothing to show, uncovered the moment there
	-- is. A column that is briefly 2D and then 3D is better than one that is
	-- briefly empty, and the retry below is what makes the second half happen.
	StandIn(element, unit, missing and unit and UnitExists(unit))

	if element.umbraWaiting then return end
	if not unit or not UnitExists(unit) then return end
	if not missing then return end

	element.umbraWaiting = true
	Umbra:Debug('portrait missing for', unit, '— standing in for it')
	RetryPortrait(element, 1)
end

--[[ The frame that is told about every model in the world
`targettarget` is a derived token, so oUF spawns it **eventless**: a 0.5s tick
instead of events, `ouf.lua:405`. Two events are let through anyway, because
the portrait has nothing else to go on — and being on an eventless frame they
are registered without a unit filter, `events.lua:99`. So this one frame hears
UNIT_PORTRAIT_UPDATE and UNIT_MODEL_CHANGED for every unit in the world, and
oUF's portrait element opens by asking whether the unit that changed is ours.

**That question is what throws.** Issue #1, measured on Retail inside a delve: `portrait.lua:48: attempt to perform boolean test on a secret boolean
value`, 716 times in one session. Why the comparison comes back hidden despite
oUF asking permission first is written down in `Secrets.SameUnit`.

**A token compared with itself is refused by nothing**, and that is what the
whole guard below rests on, so it is worth saying where it was measured rather
than assumed: the same session. Every other frame only ever makes that
comparison, and this frame's own 0.5s tick makes it too — thousands of times
in the run that produced the 716 errors, without producing one of them.

So the handler is wrapped rather than the element replaced. oUF keeps its
event handlers in plain fields on the frame, `self[event]`, and calls them
through `onEvent`; standing in front of one costs a closure and leaves the
portrait still being set by oUF's own code rather than by a second copy of it
that could drift — the same reason `RetryPortrait` goes through `ForceUpdate`.

Three answers, three things to do. The event is not ours: drop it, which is
what oUF meant to do. The event is ours: hand it on, naming the frame's own
token so that the comparison oUF makes next is the one it cannot refuse. The
client will not say: settle it on a timer, because "some model somewhere
changed" arriving a few times a second must not reload ours a few times a
second, and one refresh answers all of them.
--]]
local PORTRAIT_SETTLE = 0.5

--[[ Every unit event the portrait element takes
The first two are what issue #1 arrived through, because they are the two an
eventless frame is allowed to keep. The other three reach `portrait.lua:48`
along the same line and have simply not been seen to throw — which is no
reason to leave a line that is known to be unsafe reachable three more ways.

**The portrait is the only element that compares units this way.** Health and
Power gate on `self.__unit ~= unit`, a plain string comparison that no client
can hide, so the three events they share with the portrait are safe for them
and unsafe for it in the same breath. That is what the identity match below is
for: those three fields hold a list of handlers, and only one entry in it is
the portrait's.

`PORTRAITS_UPDATED` is deliberately not here. It is registered unitless and
arrives with no unit at all, which oUF already drops a line above the
comparison.
--]]
local GUARDED_EVENTS = {
	'UNIT_PORTRAIT_UPDATE',
	'UNIT_MODEL_CHANGED',
	'UNIT_CONNECTION',
	'PARTY_MEMBER_ENABLE',
	'PARTY_MEMBER_DISABLE',
}

local function SettlePortrait(frame, element)
	if element.umbraSettling then return end
	element.umbraSettling = true

	C_Timer.After(PORTRAIT_SETTLE, function()
		element.umbraSettling = nil

		local unit = Umbra:FrameUnit(frame)

		if not unit or not UnitExists(unit) then return end
		if not frame:IsVisible() then return end

		element:ForceUpdate()
	end)
end

local function GuardPortraitEvents(frame)
	local element = frame.Portrait
	if not element then return end

	--[[ Which handler is the portrait's
	One function is registered for all five events, so whichever field still
	holds it alone names it, and identity picks it out of the lists the other
	events share. UNIT_PORTRAIT_UPDATE is that field: the portrait element is
	the only thing in oUF that asks for it.

	Anything else there is a frame this cannot reason about, and a guess is
	worth less than saying so.
	--]]
	local path = frame.UNIT_PORTRAIT_UPDATE

	if type(path) ~= 'function' then
		return Umbra:Debug('portrait guard found no handler on',
			tostring(Umbra:FrameUnit(frame)))
	end

	local function guard(self, event, unit, ...)
		local own = Umbra:FrameUnit(self)
		local same = Umbra.Secrets.SameUnit(own, unit)

		if same == false then return end

		if same == nil then
			--[[ Once, and only once
			A guard that does its job silently and one that was never
			reached are the same empty log, and that is the reading-two-ways
			trap this project keeps walking into. So the first refusal on
			each element writes itself down — `/uuf debug` then says whether
			the settling branch was ever taken, without needing a live
			target-of-target at the moment `/uuf check` is typed.

			Once per element rather than per event: this fires for every
			model in the world, and a 60-line buffer is there to hold what
			the build refused, not a transcript.
			--]]
			if not element.umbraRefused then
				element.umbraRefused = true
				Umbra:Debug('unit comparison refused:', tostring(own), 'against',
					tostring(unit), '— settling the portrait on a timer')
			end

			return SettlePortrait(self, element)
		end

		return path(self, event, own, ...)
	end

	for _, name in ipairs(GUARDED_EVENTS) do
		local handler = frame[name]

		if handler == path then
			frame[name] = guard
		elseif type(handler) == 'table' then
			-- `next` rather than `ipairs`: unregistering one handler out of a
			-- list leaves a hole in it, and a hole stops ipairs early.
			for index, func in next, handler do
				if func == path then
					handler[index] = guard
				end
			end
		end
	end
end

oUF:RegisterInitCallback(GuardPortraitEvents)

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

	--[[ The 2D stand-in
	Laid over the model rather than swapped for it. A PlayerModel that is
	hidden does not load, so hiding it would take away the chance of the real
	model ever turning up; this sits a level above and covers it while there
	is nothing to see.

	The client's portrait art is square and this column is not, so the texture
	is cropped rather than stretched: the full height, and as much width as
	that height allows, taken from the middle where the face is.
	--]]
	local flat = CreateFrame('Frame', nil, self)
	flat:SetPoint('TOPLEFT', self, 'TOPLEFT', l.classEdge + l.gap, 0)
	flat:SetSize(l.portrait, height)
	flat:SetFrameLevel(portrait:GetFrameLevel() + 1)
	flat:Hide()

	local flatArt = flat:CreateTexture(nil, 'ARTWORK')
	flatArt:SetAllPoints(flat)

	do
		local trim = 0.08
		local span = 1 - trim * 2
		local half = span * (l.portrait / height) / 2

		flatArt:SetTexCoord(0.5 - half, 0.5 + half, trim, 1 - trim)
	end

	portrait.umbraFlat = flat
	portrait.umbraFlatArt = flatArt

	local tint = CreateColorLayer(self, 0.13)
	tint:SetPoint('TOPLEFT', self, 'TOPLEFT', l.classEdge + l.gap, 0)
	tint:SetSize(l.portrait, height)
	tint:SetFrameLevel(portrait:GetFrameLevel() + 2)
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
