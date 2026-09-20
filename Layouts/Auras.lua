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
	fontString:SetFont(media.font, l.font)
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
		Umbra:Debug('aura container unavailable:', filter, element)
		return
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
	element.showDuration = true
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
