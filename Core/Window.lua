local _, ns = ...
local Umbra = ns.Umbra

--[[ Forever's own window frame
On WoW: Forever the client's windows wear a heavy bronze frame: Blizzard's
`ButtonFrameTemplateNoPortrait`, a dark title strip with a red close button,
and a rock ground under it. Soundstone and Hourstone wear it there since
their 0.4.0, and the options window and the onboarding wear it too, on that
client and while the theme resolves to `forever`. Everywhere else, and under
`umbra` on Forever, they stay the flat windows they have been since 0.6 and
0.9. The plan, the measurements it rests on and what is still to be seen are
in `docs/development.md`, *The windows in Forever's own frame*.

**A look changes the surface, never the content.** Every row stays where it
is in both looks and the windows keep their heights. The theme switch is a
row of the options window itself, so a click on it re-skins the window under
the pointer, and nothing may move away from it. The frame's title strip and
separator take the place of the flat header; the switches lie in the client's
dropdown field; the checkboxes take the colors of Forever's own; the push
buttons get the client's red twins; the onboarding's previews sit in an
inset. Notes, hatching and the palette's labels stay as they are.

**Built once, then only shown and hidden.** A window registers what it is
made of with `Window.New`, and `look:Apply()` puts it in the look in force:
the frame's pieces are built the first time they are wanted, in a `pcall` of
their own, so a failure leaves the window flat rather than unopened. After
that a switch builds nothing. Nothing of the frame goes through
`Umbra:Paint`, which remembers a region and paints it again with
`SetColorTexture` on every switch: on an atlas that would wipe the art.

Not reached through `Umbra.Widgets`: `Layouts/Widgets.lua` puts the unit
frames' kit there once it loads, and only `Core/Onboarding.lua`'s own local
keeps the windows' one.
--]]

local Window = {}
Umbra.Window = Window

local ART = {
	layout = 'ButtonFrameTemplateNoPortrait',
	ground = [[Interface\FrameGeneral\UI-Background-Rock]],
	close = {normal = 'RedButton-Exit', pushed = 'RedButton-exit-pressed', highlight = 'RedButton-Highlight'},
	streaks = '_UI-Frame-TopTileStreaks',
	field = 'common-dropdown-textholder',
	inset = 'InsetFrameTemplate',
}

-- Where the nine-slice's box lies around the window, as Soundstone measured
-- the art: its metal begins 4.4 units inside the box on the left and reaches
-- 3.35 above it and 0.35 below it, which puts it flush with the window there.
-- The right-hand number is Soundstone's and Hourstone's. Soundstone's own
-- reading of the art would have put the metal a unit outside the right edge;
-- measured on the onboarding on 11 November 2026, it is flush there too.
local BORDER = {left = -4.4, top = -3.35, right = 0.5, bottom = 0.35}

-- The frame's few colors of its own, never from the palette. The divider is
-- the flat look's outline, as on Hourstone's format toggle; the checkbox is
-- Forever's settings checkbox, measured by Soundstone on lossless
-- screenshots: the box, the top of its bronze edge (the sides and the bottom
-- measured within a few steps of it) and the median of its gold check.
local DIVIDER = {104 / 255, 80 / 255, 52 / 255}
local CHECK_EDGE = {0x57 / 255, 0x46 / 255, 0x39 / 255}
local CHECK_BOX = {0x10 / 255, 0x0C / 255, 0x08 / 255}
local CHECK_MARK = {0xED / 255, 0xC6 / 255, 0x05 / 255}

--[[ Which pieces the client can draw
Forever only: Mists, the Anniversary realms and Classic Era have other art
under the frame's names, and Retail's is not Forever's. There every atlas is
asked for, and only a table counts; the UI source says which names are
referenced, not what a client draws. Without the frame nothing else is used,
and each of the other pieces falls back on its own. The rock is a file, which
cannot be asked for; it goes with the frame, as in Blizzard's own template.
Asked once: a client's atlases do not change while it runs. The question
itself is `Umbra.AtlasKnown`, in `Core/Init.lua`.
--]]
local AtlasKnown = Umbra.AtlasKnown

local function LayoutKnown(name)
	if type(NineSliceUtil) ~= 'table' or type(NineSliceUtil.ApplyLayoutByName) ~= 'function'
		or type(NineSliceLayouts) ~= 'table' then
		return false
	end

	local pieces = NineSliceLayouts[name]

	if type(pieces) ~= 'table' then return false end

	for _, piece in pairs(pieces) do
		if type(piece) == 'table' and piece.atlas and not AtlasKnown(piece.atlas) then
			return false
		end
	end

	return true
end

local art

local function Art()
	if art then return art end

	art = {}

	if not Umbra.isForever then return art end

	art.window = LayoutKnown(ART.layout) and AtlasKnown(ART.close.normal)
		and AtlasKnown(ART.close.pushed) and AtlasKnown(ART.close.highlight)
	art.streaks = art.window and AtlasKnown(ART.streaks)
	art.field = art.window and AtlasKnown(ART.field)
	art.inset = art.window and LayoutKnown(ART.inset)

	return art
end

-- The frame is worn on Forever, under a theme that resolves to `forever`,
-- where the client has its art.
local function Wanted()
	return Umbra.isForever and Umbra:ThemeName() == 'forever' and Art().window == true
end

-- `NORMAL_FONT_COLOR`, read rather than copied; Forever measured `#FFD200`.
local function TitleColor()
	local color = NORMAL_FONT_COLOR

	if type(color) == 'table' and type(color.GetRGB) == 'function' then
		local ok, r, g, b = pcall(color.GetRGB, color)

		if ok and type(r) == 'number' and type(g) == 'number' and type(b) == 'number' then
			return r, g, b
		end
	end

	return 1, 210 / 255, 0
end

--[[ One physical pixel
The dividers and the checkboxes' edges are one physical pixel, as the theme's
lines are, and are measured again when the UI scale or the screen changes.
The handler is registered when the first of them is built, so on the other
clients it never is.
--]]
local lines = {}
local scaler

local function Measure(fn)
	lines[#lines + 1] = fn
	fn()

	if not scaler then
		scaler = CreateFrame('Frame')
		scaler:SetScript('OnEvent', function()
			for _, line in ipairs(lines) do line() end
		end)

		Umbra:RegisterEvent(scaler, 'UI_SCALE_CHANGED')
		Umbra:RegisterEvent(scaler, 'DISPLAY_SIZE_CHANGED')
	end
end

--[[ The push buttons
A flat button of `Umbra.PlainButton` gets a twin from `UIPanelButtonTemplate`
at its own rectangle, which Forever draws in Retail's red art with a gold
label. A click on the twin is the flat button's click. What a window's
Refresh sets on a button goes through these four, which set the twin too,
so the two never disagree about the text, whether the button is there,
whether it can be used, or whether it is held down.

`PlainButton` itself stays as it is: the report window and the page under
Options › AddOns use it as well.
--]]

-- Which of the pair is on screen: the flat button, or its twin in the frame.
local function Place(button)
	local wanted = button.wanted ~= false

	button:SetShown(wanted and not button.framed)

	if button.twin then
		button.twin:SetShown(wanted and button.framed == true)
	end
end

function Window.Text(button, text)
	button.UmbraLabel:SetText(text)

	if button.twin then button.twin:SetText(text) end
end

function Window.Shown(button, shown)
	button.wanted = shown and true or false
	Place(button)
end

function Window.Enabled(button, enabled)
	button:SetEnabled(enabled)

	if button.twin then button.twin:SetEnabled(enabled) end
end

-- Held: the twin's highlight stays on, the client's way of marking a button
-- that is engaged. Under the flat look the window's own accent line says it.
function Window.Held(button, held)
	button.held = held and true or false

	if button.twin then
		if button.held then button.twin:LockHighlight() else button.twin:UnlockHighlight() end
	end
end

local function Twin(button)
	local ok, twin = pcall(CreateFrame, 'Button', nil, button:GetParent(), 'UIPanelButtonTemplate')

	if not ok or not twin then return end

	twin:SetAllPoints(button)
	twin:SetText(button.UmbraLabel:GetText() or '')
	twin:SetEnabled(button:IsEnabled())
	twin:RegisterForClicks('LeftButtonUp')

	-- The flat button is hidden meanwhile, so its own action is called.
	twin:SetScript('OnClick', function(_, mouse)
		local action = button:GetScript('OnClick')

		if action then action(button, mouse) end
	end)

	button.twin = twin
	Window.Held(button, button.held)

	return twin
end

--[[ Window.New(frame)
The look of one window. The window says what it is made of — the flat
pieces the frame replaces, its switches, checkboxes, buttons and previews,
and anything that stands elsewhere in the frame — and calls `Apply` once
it is built. `Umbra:ApplyWindowLook()` calls it again on every switch.
--]]
local looks = {}
local Look = {}
Look.__index = Look

function Window.New(frame)
	local look = setmetatable({
		frame = frame,
		flat = {},
		switches = {},
		checks = {},
		buttons = {},
		previews = {},
		places = {},
		made = {},
		twins = {},
	}, Look)

	looks[#looks + 1] = look

	return look
end

-- Regions of the flat window that the frame replaces.
function Look:Flat(...)
	for index = 1, select('#', ...) do
		self.flat[#self.flat + 1] = (select(index, ...))
	end
end

-- A switch of `Segmented`: its buttons, the gap between them, its parent.
function Look:Switch(control)
	self.switches[#self.switches + 1] = control
end

-- A box of `Check`.
function Look:Check(control)
	self.checks[#self.checks + 1] = control
end

-- A button of `Umbra.PlainButton`.
function Look:Button(button)
	self.buttons[#self.buttons + 1] = button
end

-- A preview box and the four lines of its flat outline.
function Look:Preview(box, outline)
	self.previews[#self.previews + 1] = {box = box, outline = outline}
end

-- A region placed differently in the frame: each a list of SetPoint
-- arguments.
function Look:Place(region, flat, framed)
	self.places[#self.places + 1] = {region = region, flat = flat, framed = framed}
end

-- A piece of the frame, shown with it and hidden without it.
function Look:Made(piece)
	self.made[#self.made + 1] = piece

	return piece
end

-- The frame itself: the client's nine-slice over the window, the rock and
-- the streaks under the title strip, the title and the red close button.
local function BuildFrame(look, found)
	local frame = look.frame
	local level = frame:GetFrameLevel()

	-- Above the content, as Blizzard's own nine-slice is, and taking no mouse,
	-- so the window still drags from anywhere and its controls still click.
	local border = look:Made(CreateFrame('Frame', nil, frame))
	border:SetPoint('TOPLEFT', frame, 'TOPLEFT', BORDER.left, BORDER.top)
	border:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', BORDER.right, BORDER.bottom)
	border:SetFrameLevel(level + 10)
	border:EnableMouse(false)
	NineSliceUtil.ApplyLayoutByName(border, ART.layout)

	-- Only Forever crops the bottom corners of a short frame, and only through
	-- a container that holds the nine-slice; the height is the box's. The
	-- windows never change height, so once is enough.
	if type(NineSliceUtil.UpdateCornerCropping) == 'function' then
		pcall(NineSliceUtil.UpdateCornerCropping, {NineSlice = border, layoutType = ART.layout},
			frame:GetHeight() + BORDER.top - BORDER.bottom)
	end

	local ground = look:Made(frame:CreateTexture(nil, 'BACKGROUND', nil, -6))
	ground:SetTexture(ART.ground, 'REPEAT', 'REPEAT')
	ground:SetHorizTile(true)
	ground:SetVertTile(true)
	ground:SetPoint('TOPLEFT', border, 'TOPLEFT', 7, -21)
	ground:SetPoint('BOTTOMRIGHT', border, 'BOTTOMRIGHT', -2, 2)

	if found.streaks then
		local streaks = look:Made(frame:CreateTexture(nil, 'BACKGROUND', nil, -5))
		streaks:SetAtlas(ART.streaks)
		streaks:SetHorizTile(true)
		streaks:SetHeight(43)
		streaks:SetPoint('TOPLEFT', border, 'TOPLEFT', 6, -21)
		streaks:SetPoint('TOPRIGHT', border, 'TOPRIGHT', -2, -21)
	end

	-- The title and the close button ride above the border.
	local top = look:Made(CreateFrame('Frame', nil, frame))
	top:SetAllPoints(border)
	top:SetFrameLevel(level + 12)
	top:EnableMouse(false)

	-- Blizzard's window title: size 12, centered on the border, 6 below its
	-- top, in the client's gold.
	local title = top:CreateFontString(nil, 'OVERLAY')
	title:SetFontObject(GameFontNormal)
	title:SetTextColor(TitleColor())
	title:SetWordWrap(false)
	title:SetPoint('TOP', border, 'TOP', 0, -6)
	title:SetText('Umbra Unit Frames')

	-- Forever's close button, at Blizzard's own size and place, with the
	-- window's own action: the stock one goes through HideUIPanel.
	local close = CreateFrame('Button', nil, top)
	close:SetSize(28, 28)
	close:SetPoint('TOPRIGHT', border, 'TOPRIGHT', 0, 3)
	close:SetNormalAtlas(ART.close.normal)
	close:SetPushedAtlas(ART.close.pushed)
	close:SetHighlightAtlas(ART.close.highlight, 'ADD')
	close:RegisterForClicks('LeftButtonUp')
	close:SetScript('OnClick', function() frame:Hide() end)
end

-- A switch in one of the client's dropdown fields, drawn over all of its
-- parts, with a one-pixel divider in each gap.
local function BuildSwitch(look, control)
	local buttons = control.buttons
	local first, last = buttons[1], buttons[#buttons]
	local parent = control.parent

	local field = look:Made(parent:CreateTexture(nil, 'BORDER'))
	field:SetAtlas(ART.field, true)
	field:ClearAllPoints()
	field:SetPoint('TOPLEFT', first, 'TOPLEFT', -8, 7)
	field:SetPoint('BOTTOMRIGHT', last, 'BOTTOMRIGHT', 8, -9)

	for index = 2, #buttons do
		local divider = look:Made(parent:CreateTexture(nil, 'ARTWORK'))
		divider:SetColorTexture(DIVIDER[1], DIVIDER[2], DIVIDER[3], 1)
		divider:SetHeight(15)

		Measure(function()
			local d = Umbra.PixelSize(parent)

			divider:ClearAllPoints()
			divider:SetPoint('TOP', buttons[index], 'TOPLEFT', -control.gap / 2, -(buttons[index]:GetHeight() - 15) / 2)
			divider:SetWidth(d)
		end)
	end

	control.art = true
end

-- A checkbox in Forever's colors, in Umbra's own shape: the edge one pixel,
-- the mark a filled square where the flat look has its pip.
local function BuildCheck(look, control)
	local button, outline = control.button, control.outline

	local edge = look:Made(button:CreateTexture(nil, 'BACKGROUND', nil, 1))
	edge:SetColorTexture(CHECK_EDGE[1], CHECK_EDGE[2], CHECK_EDGE[3], 1)
	edge:SetAllPoints(outline)

	local box = look:Made(button:CreateTexture(nil, 'BORDER', nil, 1))
	box:SetColorTexture(CHECK_BOX[1], CHECK_BOX[2], CHECK_BOX[3], 1)

	Measure(function()
		local d = Umbra.PixelSize(button)

		box:ClearAllPoints()
		box:SetPoint('TOPLEFT', edge, 'TOPLEFT', d, -d)
		box:SetPoint('BOTTOMRIGHT', edge, 'BOTTOMRIGHT', -d, d)
	end)

	-- Shown by the control's Refresh, which knows whether it is ticked.
	local mark = button:CreateTexture(nil, 'ARTWORK', nil, 1)
	mark:SetColorTexture(CHECK_MARK[1], CHECK_MARK[2], CHECK_MARK[3], 1)
	mark:SetPoint('TOPLEFT', outline, 'TOPLEFT', 3, -3)
	mark:SetPoint('BOTTOMRIGHT', outline, 'BOTTOMRIGHT', -3, 3)
	mark:Hide()
	control.mark = mark
end

-- Blizzard's inset around a preview box, on a frame of its own one level up:
-- the box keeps its parent, size and scale, so what was measured in it holds.
local function BuildInset(look, preview)
	local box = preview.box

	local inset = look:Made(CreateFrame('Frame', nil, box:GetParent()))
	inset:SetAllPoints(box)
	inset:SetFrameLevel(box:GetFrameLevel() + 1)
	inset:EnableMouse(false)
	NineSliceUtil.ApplyLayoutByName(inset, ART.inset)
end

local function Build(look)
	local found = Art()

	BuildFrame(look, found)

	if found.field then
		for _, control in ipairs(look.switches) do BuildSwitch(look, control) end
	end

	for _, control in ipairs(look.checks) do BuildCheck(look, control) end

	if found.inset then
		for _, preview in ipairs(look.previews) do BuildInset(look, preview) end
	end

	-- A button whose twin cannot be made stays flat.
	for _, button in ipairs(look.buttons) do
		look.twins[#look.twins + 1] = Twin(button)
	end
end

local function SetPoints(region, points)
	region:ClearAllPoints()

	for _, point in ipairs(points) do
		region:SetPoint(unpack(point))
	end
end

-- Shows one look and hides the other.
local function Show(look, framed)
	look.framed = framed

	for _, region in ipairs(look.flat) do region:SetShown(not framed) end
	for _, piece in ipairs(look.made) do piece:SetShown(framed) end

	for _, control in ipairs(look.switches) do
		local inField = framed and control.art == true

		control.framed = inField

		for _, button in ipairs(control.buttons) do
			button.ground:SetShown(not inField)
		end
	end

	for _, control in ipairs(look.checks) do
		local boxed = framed and control.mark ~= nil

		control.framed = boxed
		control.outline:SetShown(not boxed)
		control.box:SetShown(not boxed)
	end

	for _, preview in ipairs(look.previews) do
		for _, line in ipairs(preview.outline) do
			line:SetShown(not (framed and Art().inset))
		end
	end

	for _, button in ipairs(look.buttons) do
		button.framed = framed and button.twin ~= nil
		Place(button)
	end

	for _, place in ipairs(look.places) do
		SetPoints(place.region, framed and place.framed or place.flat)
	end
end

--[[ look:Apply()
Puts the window in the look in force. Before anything of the frame exists
and while it is not wanted — on every client but Forever, and under `umbra`
there — this returns at once and the window is exactly the flat one. The
window's Refresh, when it is open, puts the state of every control back over
what the switch showed or hid.
--]]
function Look:Apply()
	local wanted = Wanted() and not self.broken

	if not wanted and not self.built then return end

	if wanted and not self.built then
		local ok, err = pcall(Build, self)

		if ok then
			self.built = true
		else
			-- Whatever was made before the error goes, and the window stays flat
			-- until the next /reload.
			self.broken = true
			wanted = false

			for _, piece in ipairs(self.made) do pcall(piece.Hide, piece) end
			for _, twin in pairs(self.twins) do pcall(twin.Hide, twin) end
			for _, button in ipairs(self.buttons) do button.twin = nil end

			Umbra:Debug('window frame failed:', err)
		end
	end

	Show(self, wanted)

	if self.frame:IsShown() and self.frame.Refresh then
		self.frame:Refresh()
	end
end

-- Called at the end of every theme switch (Core/Theme.lua).
function Umbra:ApplyWindowLook()
	for _, look in ipairs(looks) do
		look:Apply()
	end
end
