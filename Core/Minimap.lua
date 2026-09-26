local _, ns = ...
local Umbra = ns.Umbra

--[[ Two more ways into the options window
Typing `/uuf` is one; these are the two that need no typing. The addon
compartment is the client's own list under the minimap, on the clients that
have one. The minimap button is ours, for the clients that do not, and off by
default where the compartment is — two icons for one addon is one too many.

Which client has which was checked against each one's interface code, not
assumed: `AddonCompartment.lua` is in Blizzard_Minimap on live and forever,
and absent on classic, classic_anniversary and classic_era. So Mists, the
Anniversary realms and Classic Era get the button, and it is still asked for
at runtime rather than read off a flag.
--]]

local L = Umbra.L

local ICON = [[Interface\AddOns\UmbraUnitFrames\Media\logo]]
local TITLE = 'Umbra Unit Frames'

local function Tooltip(owner, hint)
	if not GameTooltip then return end

	GameTooltip:SetOwner(owner, 'ANCHOR_LEFT')
	GameTooltip:SetText(TITLE, 1, 1, 1)
	GameTooltip:AddLine(hint, unpack(Umbra.colors.muted))
	GameTooltip:Show()
end

local function HideTooltip()
	if GameTooltip then GameTooltip:Hide() end
end

--[[ The compartment entry
The table is the one Blizzard's own addons hand over. `func` receives the
button and the mouse button, and a left click is the only thing it does:
there is one window, so there is nothing for a right click to choose between.
--]]
local function RegisterCompartment()
	if not Umbra:HasCompartment() then return end

	local ok, err = pcall(AddonCompartmentFrame.RegisterAddon, AddonCompartmentFrame, {
		text = TITLE,
		icon = ICON,
		notCheckable = true,
		func = function() Umbra:ToggleOptions() end,
		funcOnEnter = function(button)
			Tooltip(type(button) == 'table' and button or AddonCompartmentFrame, L['Click for the options.'])
		end,
		funcOnLeave = HideTooltip,
	})

	if not ok then
		Umbra:Debug('addon compartment refused:', err)
	end
end

--[[ The minimap button
Blizzard's tracking-button geometry, the one LibDBIcon, Soundstone and
Hourstone use: a round ground, the icon, and the tracking border over both.
The border's transparent padding differs between Retail and the Classic
families, so the sizes do too — and Forever runs Retail's code with Classic's
art, which is why this asks `isRetail` rather than `isMainline`.

Dragged around the rim, not across the screen, and kept as an angle.
--]]
local button

local function Position()
	local angle = math.rad(UmbraUnitFramesDB.minimap.angle or 200)
	local x, y = math.cos(angle), math.sin(angle)

	-- On a square minimap the rim is a square, and a point on the circle
	-- would float inside it at the corners.
	if type(_G.GetMinimapShape) == 'function' and GetMinimapShape() == 'SQUARE' then
		local scale = 1 / math.max(math.abs(x), math.abs(y))
		x, y = x * scale, y * scale
	end

	button:ClearAllPoints()
	button:SetPoint('CENTER', Minimap, 'CENTER',
		x * (Minimap:GetWidth() / 2 + 5), y * (Minimap:GetHeight() / 2 + 5))
end

local function Build()
	local retail = Umbra.isRetail

	button = CreateFrame('Button', 'UmbraMinimapButton', Minimap)
	button:SetSize(31, 31)
	button:SetFrameStrata('MEDIUM')
	button:SetFrameLevel(Minimap:GetFrameLevel() + 8)

	local ground = button:CreateTexture(nil, 'BACKGROUND')
	ground:SetTexture([[Interface\Minimap\UI-Minimap-Background]])
	ground:SetSize(retail and 24 or 20, retail and 24 or 20)

	local icon = button:CreateTexture(nil, 'ARTWORK')
	icon:SetTexture(ICON)
	icon:SetSize(retail and 18 or 17, retail and 18 or 17)

	if retail then
		ground:SetPoint('CENTER')
		icon:SetPoint('CENTER')
	else
		ground:SetPoint('TOPLEFT', 7, -5)
		icon:SetPoint('TOPLEFT', 7, -6)
	end

	local border = button:CreateTexture(nil, 'OVERLAY')
	border:SetTexture([[Interface\Minimap\MiniMap-TrackingBorder]])
	border:SetSize(retail and 50 or 53, retail and 50 or 53)
	border:SetPoint('TOPLEFT')

	button:SetHighlightTexture([[Interface\Minimap\UI-Minimap-ZoomButton-Highlight]])
	button:RegisterForClicks('LeftButtonUp')
	button:RegisterForDrag('LeftButton')

	-- A drag ends in a mouse-up, and that must not also open the window.
	local dragged

	button:SetScript('OnClick', function()
		if dragged then
			dragged = nil
			return
		end

		Umbra:ToggleOptions()
	end)

	button:SetScript('OnEnter', function(self)
		Tooltip(self, L['Click for the options, drag to move.'])
	end)
	button:SetScript('OnLeave', HideTooltip)

	button:SetScript('OnDragStart', function(self)
		HideTooltip()
		dragged = true

		self:SetScript('OnUpdate', function()
			local mx, my = Minimap:GetCenter()
			local cx, cy = GetCursorPosition()
			local scale = Minimap:GetEffectiveScale()

			UmbraUnitFramesDB.minimap.angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx)) % 360
			Position()
		end)
	end)

	button:SetScript('OnDragStop', function(self)
		self:SetScript('OnUpdate', nil)
	end)

	button:SetScript('OnHide', function(self)
		self:SetScript('OnUpdate', nil)
	end)

	Minimap:HookScript('OnSizeChanged', Position)
	Position()
end

--[[ Umbra:ShowMinimapButton(shown)
Shows or hides the button, which exists from login whether it is wanted or
not.

**It is built at login, not when it is first switched on.** Addons that
gather minimap buttons into a bag of their own — MinimapButtonButton, measured
on Retail on 26 September 2026 — scan the minimap's children once, a frame
after PLAYER_LOGIN and again a second later, and take whatever matches a name
like `...MinimapButton`. The first version built this lazily, and on Retail,
where it is off by default, switching it on made a button nobody scanned for:
it stayed on the rim while every other addon's sat in the bag. Built at login
and merely hidden, it is there to be found, and a collector that hooks
Show and Hide follows the switch from then on.

Once taken, a collector blocks SetPoint and SetParent on the button, so the
angle kept here stops mattering, which is the point of using one.
--]]
function Umbra:ShowMinimapButton(shown)
	if button then
		button:SetShown(shown)
	end
end

local loader = CreateFrame('Frame')
loader:RegisterEvent('PLAYER_LOGIN')
loader:SetScript('OnEvent', function(self)
	self:UnregisterEvent('PLAYER_LOGIN')

	RegisterCompartment()

	if not Minimap then return end

	local ok, err = pcall(Build)

	if not ok then
		button = nil
		Umbra:Debug('minimap button failed:', err)
		return
	end

	Umbra:ShowMinimapButton(UmbraUnitFramesDB.minimap.shown)
end)
