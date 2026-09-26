local _, ns = ...
local Umbra = ns.Umbra
local oUF = ns.oUF

local colors, media = Umbra.colors, Umbra.media

--[[ Auras with an underline
A slim colored line beneath each icon in place of a prominent full border.

The color cannot be chosen here. A unit's aura data is hidden inside
instances, so the dispel type is not something this addon may read and branch
on. AuraButton:AddDispelTypeTexture is the client's answer to exactly that: it
takes a texture of ours and colors it by the aura's dispel type without the
value ever passing through us. The style decides which art the client puts on
the texture, and PreserveAsset keeps ours — which is how a flat line gets a
dispel color instead of becoming Blizzard's border.

The development notes weighed one AuraGroup per dispel type, and worried about
ordering auras across those groups. Coloring per button removes the question:
two containers, helpful and harmful, each in the client's own sort order.

Every icon carries two lines stacked on the same rectangle. The lower one is
ours and always shows; the upper one is registered with the client and only
appears for an aura that has a dispel type. Neither needs to know what the
other is doing, so an aura the client reports no dispel type for — which is
most of them — keeps a neutral line rather than whatever color the dispel
texture happens to be left at.
--]]

-- Present since 12.0, and Forever is still missing parts of the Retail
-- surface. Indexing a missing Enum table throws, and a throw at file scope
-- takes the rest of the file with it, so the style is asked for rather than
-- assumed.
local styles = type(_G.Enum) == 'table' and Enum.CustomAuraButtonDispelTypeTextureStyle
local PRESERVE_ASSET = styles and styles.PreserveAsset

Umbra.hasAuraUnderline = PRESERVE_ASSET ~= nil

--[[ Label(fontString, l)
Re-dresses a label oUF created with a Blizzard font, and lets go of its anchor
so the caller can place it. oUF has already set one, and a second point on top
of it stretches the label rather than moving it.

NumberFontNormal is too large for a 22 pixel icon and carries no shadow, and
these labels sit on spell art rather than on a surface Umbra chose.
--]]
local function Label(fontString, l)
	fontString:ClearAllPoints()
	fontString:SetFontObject(Umbra.Font(l.font))
	fontString:SetTextColor(unpack(colors.text))
	fontString:SetShadowColor(0, 0, 0, 0.85)
	fontString:SetShadowOffset(1, -1)
end

--[[ PostCreateButton(element, button)
Re-cuts the button oUF built for us.

oUF sizes the icon to the whole button, and the button here is taller than it
is wide to leave room for the line. So the icon is pinned to the square at the
top, and everything that belongs on the icon follows it there.

oUF passes the group options along as a third argument, and they are ignored:
the metrics come off the element, where they do not travel on to the client.
--]]
local function PostCreateButton(element, button)
	local l = element.umbra
	if not l then return end
	local icon = button.Icon

	-- The border grows inwards, not outwards. Hung outside the button it put
	-- the visible left edge of the whole aura block a pixel to the left of
	-- the frame's own edge, which is the one line the eye checks.
	local backdrop = button:CreateTexture(nil, 'BACKGROUND')
	backdrop:SetPoint('TOPLEFT', button, 'TOPLEFT', 0, 0)
	backdrop:SetSize(l.icon, l.icon)
	backdrop:SetColorTexture(unpack(colors.border))

	local art = l.icon - 2

	icon:ClearAllPoints()
	icon:SetPoint('TOPLEFT', button, 'TOPLEFT', 1, -1)
	icon:SetSize(art, art)

	-- Spell art ships with a wide beveled border baked in, which at this size
	-- takes more of the icon than the symbol does.
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	if button.Cooldown then
		button.Cooldown:ClearAllPoints()
		button.Cooldown:SetPoint('TOPLEFT', button, 'TOPLEFT', 1, -1)
		button.Cooldown:SetSize(art, art)

		-- The cooldown frame draws its own countdown, centered and in a font
		-- sized for Blizzard's icons, which on a 22 pixel one overhangs both
		-- edges. Ours goes on the Time label below instead.
		pcall(button.Cooldown.SetHideCountdownNumbers, button.Cooldown, true)
	end

	-- The button is exactly as wide as the icon, so both labels can anchor to
	-- its own corners.
	if button.Count then
		Label(button.Count, l)
		button.Count:SetPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT', -1, l.underline + l.gap)
	end

	-- In the middle of the icon square, not of the button: the button is
	-- taller than the icon by the gap and the line underneath it.
	if button.Time then
		Label(button.Time, l)
		button.Time:SetJustifyH('CENTER')
		button.Time:SetPoint('CENTER', button, 'TOPLEFT', l.icon / 2, -l.icon / 2)
	end

	local line = button:CreateTexture(nil, 'ARTWORK')
	line:SetPoint('TOPLEFT', button, 'TOPLEFT', 0, -(l.icon + l.gap))
	line:SetSize(l.icon, l.underline)
	line:SetTexture(media.bar)
	line:SetVertexColor(unpack(l.harmful and colors.auraHarmful or colors.auraHelpful))
	button.Underline = line

	if not PRESERVE_ASSET or not button.AddDispelTypeTexture then return end

	local dispel = button:CreateTexture(nil, 'OVERLAY')
	dispel:SetPoint('TOPLEFT', button, 'TOPLEFT', 0, -(l.icon + l.gap))
	dispel:SetSize(l.icon, l.underline)
	dispel:SetTexture(media.bar)
	button.DispelUnderline = dispel

	-- showWithoutDispelType is left off on purpose: this line is the whole
	-- statement that the aura can be dispelled, so it has nothing to say
	-- about one that cannot be.
	local ok = pcall(button.AddDispelTypeTexture, button, dispel, {
		style = PRESERVE_ASSET,
		showWhenHelpful = not l.harmful,
		showWhenHarmful = l.harmful,
		customDispelColorMap = oUF.colors.dispel,
	})

	if not ok then
		-- Unregistered it is a white bar over the neutral line, not a no-op.
		dispel:Hide()
		Umbra:Debug('dispel underline refused')
	end
end

--[[ Rows of our own, where the client has no container
oUF 14 builds its aura rows out of the client's `AuraContainer` widget, which
arrived with Midnight. Mists of Pandaria Classic runs almost all of the same
API and not that: `CreateFrame('AuraContainer')` throws there, measured
against Blizzard's own interface code for 5.5.4, where neither the widget nor
`AddDispelTypeTexture` appears. Without an answer here the frames on that
client simply have no auras.

So where the container is refused, the row is built here instead, out of
plain frames, and read with `C_UnitAuras.GetAuraDataByIndex` — which that
client has. Whether this path is taken is decided by the refusal and not by
the client's name, so a client that gains the widget stops using it.

**It is the same button.** Each one is cut by PostCreateButton, the function
that cuts a container's, so the icon, the labels and the line are one
geometry. And it is packed by `Umbra:AuraPerRow`, the arithmetic that reserves
the block, the same way Layouts/Preview.lua packs its stand-ins — so the three
cannot drift apart.

What the client did for the container has to be done here. It is done with
the values that are in the open, and a value that is not leaves its part of
the button blank rather than being branched on:

- The dispel color is set in Lua from `oUF.colors.dispel`, the table the
  container is handed on Retail.
- The duration is a label on a timer, in whole seconds, minutes or hours.
- Right-clicking a buff off goes through `CancelUnitBuff`, the call the
  client's own buff frame makes on that client, and only out of combat.
--]]
local AURA_SCAN_LIMIT = 40
local TICK = 0.2

local function Remaining(seconds)
	if seconds >= 3600 then return ('%d h'):format(math.ceil(seconds / 3600)) end
	if seconds >= 60 then return ('%d m'):format(math.ceil(seconds / 60)) end

	return ('%d s'):format(math.max(0, math.floor(seconds)))
end

local function TickTime(button, elapsed)
	button.umbraTick = (button.umbraTick or 0) + elapsed
	if button.umbraTick < TICK then return end
	button.umbraTick = 0

	button.Time:SetText(Remaining(button.umbraExpires - GetTime()))
end

local function OwnEnter(button)
	if GameTooltip:IsForbidden() then return end

	local element = button:GetParent()
	if not element.umbraUnit or not button.umbraIndex then return end

	GameTooltip:SetOwner(button, 'ANCHOR_BOTTOMLEFT')
	GameTooltip:SetUnitAura(element.umbraUnit, button.umbraIndex, element.umbraFilter)
end

local function OwnLeave()
	if GameTooltip:IsForbidden() then return end

	GameTooltip:Hide()
end

local function OwnClick(button)
	if InCombatLockdown() or not button.umbraIndex then return end

	local element = button:GetParent()
	CancelUnitBuff(element.umbraUnit, button.umbraIndex, element.umbraFilter)
end

local function OwnButton(element, index)
	local l = element.umbra
	local button = CreateFrame('Button', nil, element)
	button:SetSize(l.icon, l.icon + l.gap + l.underline)

	button.Icon = button:CreateTexture(nil, 'BORDER')

	button.Cooldown = CreateFrame('Cooldown', nil, button, 'CooldownFrameTemplate')
	button.Cooldown:SetDrawEdge(false)

	-- Above the cooldown's sweep, the way the container raises its labels.
	local labels = CreateFrame('Frame', nil, button)
	labels:SetAllPoints()
	labels:SetFrameLevel(button.Cooldown:GetFrameLevel() + 1)

	button.Count = labels:CreateFontString(nil, 'OVERLAY')

	if element.showDuration then
		button.Time = labels:CreateFontString(nil, 'OVERLAY')
	end

	PostCreateButton(element, button)

	button:SetScript('OnEnter', OwnEnter)
	button:SetScript('OnLeave', OwnLeave)

	if element.cancelButton then
		button:RegisterForClicks(element.cancelButton)
		button:SetScript('OnClick', OwnClick)
	end

	element.buttons[index] = button

	return button
end

local function Hidden(value)
	return Umbra.Secrets.Is(value)
end

--[[ Fill(button, data)
One aura onto one button. Every value that decides something is asked
whether it is hidden first; the texture takes a hidden icon as it is.
--]]
local function Fill(button, data)
	button.Icon:SetTexture(data.icon)

	local count = data.applications

	if count ~= nil and not Hidden(count) and count > 1 then
		button.Count:SetText(count)
	else
		button.Count:SetText('')
	end

	local duration, expires = data.duration, data.expirationTime
	local timed = duration ~= nil and expires ~= nil and not Hidden(duration)
		and not Hidden(expires) and duration > 0

	if timed then
		button.Cooldown:SetCooldown(expires - duration, duration)
		button.Cooldown:Show()
	else
		button.Cooldown:Hide()
	end

	if button.Time then
		button.umbraExpires = timed and expires or nil
		button.umbraTick = TICK
		button.Time:SetText('')
		button:SetScript('OnUpdate', timed and TickTime or nil)
	end

	-- Most auras have no dispel type and keep the neutral line.
	local line = button.Underline
	if not line then return end

	local kind = data.dispelName
	local dispel = oUF.colors.dispel
	local color = kind ~= nil and not Hidden(kind) and dispel and dispel[kind]

	if color and color.GetRGB then
		line:SetVertexColor(color:GetRGB())
	else
		local harmful = button:GetParent().umbra.harmful
		line:SetVertexColor(unpack(harmful and colors.auraHarmful or colors.auraHelpful))
	end
end

--[[ Umbra.LayOwnAuraRow(element)
Packs the buttons the way the preview packs its stand-ins: from the row's
bottom edge upwards above the frame, from its top edge downwards below it.
--]]
function Umbra.LayOwnAuraRow(element)
	local config = element.umbraConfig
	local step = config.auraSize + config.auraSpacing
	local lineStep = Umbra:AuraButtonHeight(config) + config.auraSpacing
	local perRow = Umbra:AuraPerRow(config)
	local upwards = element.umbraUpwards

	for index, button in ipairs(element.buttons) do
		local column = (index - 1) % perRow
		local line = math.floor((index - 1) / perRow)

		button:ClearAllPoints()

		if upwards then
			button:SetPoint('BOTTOMLEFT', element, 'BOTTOMLEFT', column * step, line * lineStep)
		else
			button:SetPoint('TOPLEFT', element, 'TOPLEFT', column * step, -line * lineStep)
		end
	end
end

local function UpdateOwnRow(element, unit)
	element.umbraUnit = unit

	local shown = 0

	if unit and UnitExists(unit) then
		for index = 1, AURA_SCAN_LIMIT do
			if shown >= element.maxFrameCount then break end

			local data = C_UnitAuras.GetAuraDataByIndex(unit, index, element.umbraFilter)
			if not data then break end

			shown = shown + 1

			local button = element.buttons[shown]

			if not button then
				button = OwnButton(element, shown)
				Umbra.LayOwnAuraRow(element)
			end

			button.umbraIndex = index
			Fill(button, data)
			button:Show()
		end
	end

	for index = shown + 1, #element.buttons do
		local button = element.buttons[index]

		button.umbraIndex = nil
		button:SetScript('OnUpdate', nil)
		button:Hide()
	end
end

--[[ The element that keeps them current
UNIT_AURA for the frame's own unit, and oUF's update of every element for the
rest: a new target, a header child handed a different unit, and the tick of a
frame spawned without events, which is how the target-of-target hears
anything at all.
--]]
local function UpdateOwnRows(self, event, unit)
	local own = Umbra:FrameUnit(self)

	-- oUF already matches unit events to the frame, and refuses UNIT_AURA
	-- to a frame spawned without events, which reads on its tick instead.
	-- This is the cheap second look for a vehicle swap, where the frame's
	-- unit and the one the event names can part for a moment.
	if event == 'UNIT_AURA' and unit ~= own then return end

	for _, element in ipairs(self.UmbraOwnAuras) do
		UpdateOwnRow(element, own)
	end
end

local function EnableOwnRows(self)
	if not self.UmbraOwnAuras then return end

	self:RegisterEvent('UNIT_AURA', UpdateOwnRows)

	return true
end

local function DisableOwnRows(self)
	if not self.UmbraOwnAuras then return end

	self:UnregisterEvent('UNIT_AURA', UpdateOwnRows)
end

oUF:AddElement('UmbraOwnAuras', UpdateOwnRows, EnableOwnRows, DisableOwnRows)

--[[ Umbra.OwnAuraRow(frame, config, filter, count, harmful, cancel)
The row itself, carrying the fields a container carries, so that everything
after Spawn — AnchorAuras, Grow and PostCreateButton — reads it the same way.
--]]
function Umbra.OwnAuraRow(frame, config, filter, count, harmful, cancel)
	local element = CreateFrame('Frame', nil, frame)
	element:SetSize(config.width, Umbra:AuraBlockHeight(config, count))

	element.umbraOwn = true
	element.umbraConfig = config
	element.umbraFilter = filter
	element.buttons = {}
	element.maxFrameCount = count
	element.showDuration = config.auraDuration ~= false
	element.cancelButton = cancel

	element.umbra = {
		icon = config.auraSize,
		underline = config.auraUnderline,
		gap = config.gap,
		font = config.auraFontSize,
		harmful = harmful,
	}

	frame.UmbraOwnAuras = frame.UmbraOwnAuras or {}
	table.insert(frame.UmbraOwnAuras, element)

	return element
end

--[[ Spawn(frame, config, filter, count, harmful, cancel)
One aura container for this frame, built and sized but not yet placed.

Where it hangs and which way it grows is AnchorAuras's job, because the set in
force can change while the game is running and a container has to follow that
without being rebuilt.
--]]
local function Spawn(frame, config, filter, count, harmful, cancel)
	local buttonHeight = Umbra:AuraButtonHeight(config)

	-- Core/Defaults.lua owns this, because the frame positions are derived
	-- from the same number and the two must not drift apart.
	local height = Umbra:AuraBlockHeight(config, count)

	-- CreateAuras reaches for AuraContainer, AnchorUtil and a template that
	-- Forever may not have; a missing one throws rather than answering nil.
	local ok, element = pcall(frame.CreateAuras, frame, {
		initialAnchor = 'TOPLEFT',
		growthX = 'RIGHT',
		growthY = 'DOWN',
		-- Not the frame width: the client counts a spacing after every
		-- button, including the last one, and two pixels short of that cost
		-- the eighth icon its place in the row. Core/Defaults.lua owns the
		-- arithmetic and says what was measured.
		layoutLimit = Umbra:AuraRowLimit(config),
	})

	if not ok then
		Umbra:Debug('aura container unavailable:', filter, element,
			'— building the row ourselves')
		return Umbra.OwnAuraRow(frame, config, filter, count, harmful, cancel)
	end

	element:SetSize(config.width, height)

	element.maxFrameCount = count
	element.elementSpacing = config.auraSpacing
	element.lineSpacing = config.auraSpacing

	-- width and height rather than size: the button is a square icon plus the
	-- line underneath it.
	element.width = config.auraSize
	element.height = buttonHeight

	element.showCount = true

	-- Off where the icon is too small to carry the label — the party
	-- column asks for that. Absent from a config it stays on, so the
	-- single frames never learn about this.
	element.showDuration = config.auraDuration ~= false
	element.cancelButton = cancel
	element.PostCreateButton = PostCreateButton

	-- Read back in PostCreateButton. It stays off the group options, which go
	-- to the client and are typed.
	element.umbra = {
		icon = config.auraSize,
		underline = config.auraUnderline,
		gap = config.gap,
		font = config.auraFontSize,
		harmful = harmful,
	}

	if not pcall(element.AddGroup, element, filter) then
		Umbra:Debug('aura group refused:', filter)
		return
	end

	return element
end

--[[ Grow(element, upwards)
Turns a container round.

A row above the frame fills from its bottom edge upwards; one below fills from
its top edge downwards. A set switch can move a row from one side to the
other, so this is set again every time rather than once at creation.
--]]
local function Grow(element, upwards)
	if element.umbraOwn then
		element.umbraUpwards = upwards
		return Umbra.LayOwnAuraRow(element)
	end

	pcall(element.SetFlowLayoutAnchorPoint, element, upwards and 'BOTTOMLEFT' or 'TOPLEFT')
	pcall(element.SetFlowLayoutGrowthDirection, element, 1, upwards and 1 or -1)
end

--[[ Umbra:AnchorAuras(frame, config)
Hangs the frame's aura rows where the set in force wants them.

Creates nothing, so a set switch can run it again on frames that already
exist. Each row asks the stack where it begins rather than counting what came
before it, which is the same answer the pet frame gets for its own place in
that stack — so a row and the frame beside it cannot land on each other.

A fixed offset is safe at all because the block heights are reserved from the
aura counts rather than from what the unit happens to be carrying: a frame
with no buffs keeps the row empty instead of letting the debuffs slide up into
it.
--]]
function Umbra:AnchorAuras(frame, config)
	local containers = frame.UmbraAuras
	if not containers then return end

	local layout = self:ActiveLayout()

	for _, filter in ipairs(layout.above) do
		local element = containers[filter]

		if element then
			element:ClearAllPoints()
			element:SetPoint('BOTTOMLEFT', frame, 'TOPLEFT', 0,
				self:StackOffset(config, layout, 'above', filter))
			Grow(element, true)
		end
	end

	for _, filter in ipairs(layout.below) do
		local element = containers[filter]

		if element then
			element:ClearAllPoints()
			element:SetPoint('TOPLEFT', frame, 'BOTTOMLEFT', 0,
				-self:StackOffset(config, layout, 'below', filter))
			Grow(element, false)
		end
	end
end

-- Layouts/Preview.lua re-cuts its stand-ins through this, so that what the
-- preview shows is the real button geometry rather than a second copy of it
-- that could drift. It hands over a stand-in element rather than a container,
-- and a plain frame with no AddDispelTypeTexture, which is what stops at the
-- return above: the client will not register a texture on one.
Umbra.AuraButtonLook = PostCreateButton

--[[ Umbra:AddAuras(frame, unit, config)
One container per filter, then handed to AnchorAuras to be placed.
--]]
function Umbra:AddAuras(frame, unit, config)
	local counts = config.auras
	if not counts or not frame.CreateAuras then return end

	frame.UmbraAuras = {}

	if counts.helpful then
		-- Right-clicking a buff off only works on your own, and asking for it
		-- anywhere else costs a mouse button on the frame underneath. The
		-- button reads this when it is built, so it goes in before the group.
		local cancel = unit == 'player' and 'RightButtonUp' or nil

		frame.UmbraAuras.helpful = Spawn(frame, config, 'HELPFUL', counts.helpful, false, cancel)
	end

	if counts.harmful then
		frame.UmbraAuras.harmful = Spawn(frame, config, 'HARMFUL', counts.harmful, true)
	end

	self:AnchorAuras(frame, config)
end
