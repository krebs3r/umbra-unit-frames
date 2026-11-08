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

--[[ The duration, in Umbra's words
The client words the countdown on a container's icon itself, and its default
takes the minute from `MINUTE_ONELETTER_ABBR`. That is `%d m` in English and
in German on Retail, `%d min` on a German Forever client and on Portuguese
ones everywhere, and a word of its own in Russian, Korean and Traditional
Chinese. Measured on German Forever on 7 November 2026 at 1.3125 pixels per
unit: `25 min` is 45 pixels wide on a 34 pixel icon, so neighbouring labels
overlap by 7 to 10 pixels and the first one hangs over the frame's edge. Even
`25 m` is 36 there, wider than the icon if clear of the next one. No setting
of the client's own formatter gets rid of the `min`: it is the locale's word,
and German keeps the space as well.

So the words are ours, the same ones the rows below print where there is no
container: whole seconds, then minutes, hours and days, one letter and no
space. `49m` is 32 pixels at this font, in Friz Quadrata measured against the
same screenshot, and every two-digit count is as wide as every other, because
the digits are.

**The value never comes through here.** A `NumericRuleFormatter` is a set of
rules the client applies: oUF hands it to `SetDurationText`, the button's own
binding samples the aura's duration and formats it, and the result lands in a
label whose text is a secret aspect. Nothing in this file reads that label.
That is what keeps it working inside an instance, where the duration is hidden.

**It is asked, then tested, before it is used.** The first attempt at a format
was reverted, because it guessed at a signature and came back as `9 Minuten 46
Sekunden`. This one follows Blizzard's documentation for 12.1.5 and Forever
1.60.1, which are the same, and the formatter is then made to word a handful
of plain numbers here, at load time, where nothing is secret. Anything that
does not come back as a count and the expected letter — a refusal, a different
rounding by more than one, a word instead of a letter — leaves the client's
own default in place, which is what every client showed before. `/uuf dev
check` says which of the two a client got, and `/uuf dev debug` why.
--]]
local DURATION_PROBES = {
	-- seconds, the letter, the count Remaining() below would print
	{8.7, 's', 8},
	{59.9, 's', 59},
	{1500, 'm', 25},
	{3599, 'm', 60},
	{5400, 'h', 2},
	{172800, 'd', 2},
}

local function Speaks(formatter)
	for _, probe in ipairs(DURATION_PROBES) do
		local text = formatter:FormatNumber(probe[1])
		local count, letter = tostring(text):match('^(%d+)(%a)$')

		if letter ~= probe[2] or math.abs((tonumber(count) or -99) - probe[3]) > 1 then
			return false, ('%s seconds came back as %q'):format(probe[1], tostring(text))
		end
	end

	return true
end

local function DurationFormatter()
	local util = type(_G.C_StringUtil) == 'table' and C_StringUtil

	if not util or type(util.CreateNumericRuleFormatter) ~= 'function' then
		return nil, 'no NumericRuleFormatter on this client'
	end

	-- Documented as Nearest 0, Up 1, Down 2. Asked for rather than indexed
	-- blind, like the dispel style above.
	local rounding = type(_G.Enum) == 'table' and Enum.NumericRuleFormatRounding
	local up = rounding and rounding.Up or 1
	local down = rounding and rounding.Down or 2

	local made, formatter = pcall(util.CreateNumericRuleFormatter)
	if not made or not formatter then return nil, tostring(formatter) end

	-- The same rounding as Remaining() and as the client's own buff frame:
	-- seconds down, every larger unit up.
	local set, refusal = pcall(formatter.SetBreakpoints, formatter, {
		{threshold = 0, step = 1, rounding = down, format = '%.0fs'},
		{threshold = 60, format = '%.0fm', components = {{div = 60, step = 1, rounding = up}}},
		{threshold = 3600, format = '%.0fh', components = {{div = 3600, step = 1, rounding = up}}},
		{threshold = 86400, format = '%.0fd', components = {{div = 86400, step = 1, rounding = up}}},
	})
	if not set then return nil, tostring(refusal) end

	local spoke, speaks, why = pcall(Speaks, formatter)
	if not spoke or not speaks then return nil, tostring(why or speaks) end

	return formatter
end

local durationFormatter, durationRefusal = DurationFormatter()

-- Read by `/uuf dev check`, which reports whose words the countdown is in.
Umbra.auraDurationFormatter = durationFormatter

if not durationFormatter then
	Umbra:Debug("aura duration format refused, the client's own stays:", durationRefusal)
end

--[[ Label(fontString, l)
Re-dresses a label oUF created with a Blizzard font, and lets go of its anchor
so the caller can place it. oUF has already set one, and a second point on top
of it stretches the label rather than moving it.

NumberFontNormal is too large for these icons and carries no shadow, and
these labels sit on spell art rather than on a surface Umbra chose.
--]]
local function Label(fontString, l)
	fontString:ClearAllPoints()
	fontString:SetFontObject(Umbra.Font(l.font))
	Umbra:Paint(fontString, colors.text)
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
	Umbra:Paint(backdrop, colors.border)

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
		-- sized for Blizzard's icons, which on one of ours overhangs both
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
	-- taller than the icon by the gap and the line underneath it. No width
	-- is set: what keeps the label inside the icon is the format at the top
	-- of this file, and a clamp would only cut a longer word into `25 m…`.
	if button.Time then
		Label(button.Time, l)
		button.Time:SetJustifyH('CENTER')
		button.Time:SetPoint('CENTER', button, 'TOPLEFT', l.icon / 2, -l.icon / 2)
	end

	local line = button:CreateTexture(nil, 'ARTWORK')
	line:SetPoint('TOPLEFT', button, 'TOPLEFT', 0, -(l.icon + l.gap))
	line:SetSize(l.icon, l.underline)
	line:SetTexture(media.bar)
	-- The helpful line follows the theme; the harmful one is a unit color and
	-- never changes, which also keeps the preview's cycled dispel colors on
	-- its harmful stand-ins from being painted over by a switch.
	if l.harmful then
		line:SetVertexColor(unpack(colors.auraHarmful))
	else
		Umbra:Paint(line, colors.auraHelpful, nil, 'vertex')
	end
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
- The duration is a label on a timer, in the words the container is given
  at the top of this file: `8s`, `25m`, `2h`, `3d`. Two copies of one rule,
  because these values are in the open and a timer is simpler than asking
  the formatter five times a second; a change to one is a change to both.
- Right-clicking a buff off goes through `CancelUnitBuff`, the call the
  client's own buff frame makes on that client, and only out of combat.
--]]
local AURA_SCAN_LIMIT = 40
local TICK = 0.2

local function Remaining(seconds)
	if seconds >= 86400 then return ('%dd'):format(math.ceil(seconds / 86400)) end
	if seconds >= 3600 then return ('%dh'):format(math.ceil(seconds / 3600)) end
	if seconds >= 60 then return ('%dm'):format(math.ceil(seconds / 60)) end

	return ('%ds'):format(math.max(0, math.floor(seconds)))
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

-- A theme switch repaints every line as neutral; our own rows then color the
-- dispellable ones again, the way a UNIT_AURA would. oUF gives an element of
-- ours no ForceUpdate, so this is the way in.
function Umbra.RefreshOwnAuras(frame)
	if frame.UmbraOwnAuras and Umbra:FrameUnit(frame) then
		UpdateOwnRows(frame, 'UmbraTheme')
	end
end

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

	-- Our words for the countdown, read by oUF when it builds each button
	-- and handed on to the client. Nil where the formatter was refused,
	-- which leaves the client's own default exactly as it was.
	element.durationFormatter = durationFormatter

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
Hangs the frame's aura rows where the set in force wants them, with the
debuffs switch applied (`Umbra:Stack`).

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
	local stack = self:Stack(config, layout)

	for _, filter in ipairs(stack.above) do
		local element = containers[filter]

		if element then
			element:ClearAllPoints()
			element:SetPoint('BOTTOMLEFT', frame, 'TOPLEFT', 0,
				self:StackOffset(config, layout, 'above', filter))
			Grow(element, true)
		end
	end

	for _, filter in ipairs(stack.below) do
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
