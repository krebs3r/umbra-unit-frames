local _, ns = ...
local Umbra = ns.Umbra

local colors = Umbra.colors
local L = Umbra.L

--[[ The options window
What `/uuf` sets, in one small window: a title, four sections, two actions and
a footer — Soundstone's shape, in Umbra's own colors. The sheet it was drawn
from is `assets/design/options-window.svg`, and the numbers below are the ones
`tools/mockups.py` draws it with (`OPT` there); change one, change both.

**It offers nothing the command cannot do.** Every control ends in the same
call a `/uuf` word ends in, so the window and the chat line cannot disagree
about what a setting means, and everything takes effect where you stand, the
way the command always has. Metrics and colors are not here: nothing rebuilds
a frame when one changes, and a control that needs a reload is a different
kind of promise.

**It wears Umbra's furniture, not the client's.** The report window borrows
Blizzard's templates because it holds text; this one holds switches, and a
checkbox that looks different on each of five clients is five designs. So
every piece is a flat rectangle in the palette, the way the frames are built.
--]]

local WIDTH = 280
local EDGE = Umbra.metrics.classEdge
local PAD = 12
local LEFT = EDGE + PAD
local INNER = WIDTH - LEFT - PAD
local HEADER = 36
local SEGMENT = 22
local BOX = 14
local BUTTON = 22

--[[ SETTINGS
What each control reads and writes. `set` answers whether the change happened
now; false means it is waiting for the fight to end, never that it was
refused, and the caller says so rather than reporting a move that has not
happened. The appliers are the ones `/uuf` has always called.
--]]
local SETTINGS = {
	layout = {
		get = function() return UmbraUnitFramesDB.layout end,
		set = function(name)
			UmbraUnitFramesDB.layout = name
			return Umbra:ApplyLayout()
		end,
	},
	health = {
		get = function() return UmbraUnitFramesDB.classHealth end,
		set = function(class)
			UmbraUnitFramesDB.classHealth = class
			Umbra:ApplyHealthStyle()
			return true
		end,
	},
	auras = {
		get = function() return UmbraUnitFramesDB.hideBlizzardAuras end,
		set = function(hide)
			UmbraUnitFramesDB.hideBlizzardAuras = hide
			return Umbra:SetBlizzardAuras(not hide)
		end,
	},
	group = {
		get = function() return UmbraUnitFramesDB.hideBlizzardGroup end,
		set = function(hide)
			UmbraUnitFramesDB.hideBlizzardGroup = hide
			return Umbra:SetBlizzardGroup(not hide)
		end,
	},
	minimap = {
		get = function() return UmbraUnitFramesDB.minimap.shown end,
		set = function(shown)
			UmbraUnitFramesDB.minimap.shown = shown
			Umbra:ShowMinimapButton(shown)
			return true
		end,
	},
}

function Umbra:GetOption(key)
	return SETTINGS[key].get()
end

--[[ Umbra:SetOption(key, value)
The one way a setting changes, from the window and from chat alike. Answers
what the setter answered, and tells an open window, so a word typed in chat
shows up in the switch beside it.
--]]
function Umbra:SetOption(key, value)
	local now = SETTINGS[key].set(value)

	self:OptionsChanged()

	return now
end

local window

-- Whether a fight is on. PLAYER_REGEN_DISABLED fires just before the lockdown
-- starts, so the event is believed over InCombatLockdown at that moment.
local fighting = false

function Umbra:OptionsChanged()
	if window and window:IsShown() then
		window:Refresh()
	end
end

local function Texture(parent, layer, color, alpha, sublevel)
	local texture = parent:CreateTexture(nil, layer, nil, sublevel)
	texture:SetColorTexture(color[1], color[2], color[3], alpha or color[4] or 1)

	return texture
end

local function Label(parent, size, color, text)
	local label = parent:CreateFontString(nil, 'OVERLAY')
	label:SetFontObject(Umbra.Font(size))
	label:SetTextColor(unpack(color))

	if text then label:SetText(text) end

	return label
end

--[[ Hatch(parent)
A control that cannot be used right now, struck through with the tile that
marks an absorb — fainter, so it reads as "not now" rather than as a shield.
It lies over the control and leaves its value readable underneath.
--]]
local function Hatch(parent)
	local hatch = parent:CreateTexture(nil, 'OVERLAY', nil, 7)
	hatch:SetTexture(Umbra.media.hatch, 'REPEAT', 'REPEAT')
	hatch:SetHorizTile(true)
	hatch:SetVertTile(true)
	hatch:SetVertexColor(1, 1, 1, 0.16)
	hatch:Hide()

	return hatch
end

--[[ Note(parent)
Why a control is the way it is, in the red the addon uses for bad news, at the
right edge of the row.
--]]
local function Note(parent)
	local note = Label(parent, 10, colors.auraHarmful)
	note:SetJustifyH('RIGHT')
	note:Hide()

	return note
end

local function Section(parent, y, text)
	local label = Label(parent, 10, colors.muted, L[text]:upper())
	label:SetPoint('TOPLEFT', parent, 'TOPLEFT', LEFT, -(y + 4))

	return label
end

--[[ Segmented(parent, y, key, choices)
Two named states side by side, for a setting that is one of two things rather
than on or off — the reason `/uuf` takes words for these and not a toggle.
The chosen side carries the two-pixel line an aura icon has under it: one mark,
meaning "this one".
--]]
local function Segmented(parent, y, key, choices)
	local control = {buttons = {}}
	local gap = 2
	local width = (INNER - gap * (#choices - 1)) / #choices

	for index, choice in ipairs(choices) do
		local button = CreateFrame('Button', nil, parent)
		button:SetSize(width, SEGMENT)
		button:SetPoint('TOPLEFT', parent, 'TOPLEFT', LEFT + (index - 1) * (width + gap), -y)

		Texture(button, 'BACKGROUND', colors.border):SetAllPoints()

		button.tint = Texture(button, 'BORDER', colors.accent, 0.12)
		button.tint:SetAllPoints()

		button.line = Texture(button, 'ARTWORK', colors.accent)
		button.line:SetPoint('BOTTOMLEFT')
		button.line:SetPoint('BOTTOMRIGHT')
		button.line:SetHeight(2)

		button.label = Label(button, 12, colors.muted, L[choice[2]])
		button.label:SetPoint('CENTER')

		button.value = choice[1]

		button:SetScript('OnClick', function() Umbra:SetOption(key, choice[1]) end)
		button:SetScript('OnEnter', function(self)
			if not self.chosen then self.label:SetTextColor(unpack(colors.text)) end
		end)
		button:SetScript('OnLeave', function(self)
			if not self.chosen then self.label:SetTextColor(unpack(colors.muted)) end
		end)

		control.buttons[index] = button
	end

	control.note = Note(parent)
	control.note:SetPoint('BOTTOMRIGHT', parent, 'TOPRIGHT', -PAD, -(y - 3))

	function control:Refresh(refused)
		local current = Umbra:GetOption(key)

		for _, button in ipairs(self.buttons) do
			button.chosen = current == button.value
			button.tint:SetShown(button.chosen)
			button.line:SetShown(button.chosen)
			button.label:SetTextColor(unpack(button.chosen and colors.accent or colors.muted))
		end

		self.note:SetText(refused and L[refused] or '')
		self.note:SetShown(refused ~= nil)
	end

	return control
end

--[[ Check(parent, y, key, text)
A box of our own rather than UICheckButtonTemplate, which is a different
picture on every client. Ticked is a filled square inset in the box, the shape
a class power pip has — nothing here is drawn with the client's art.
--]]
local function Check(parent, y, key, text)
	local control = {}

	local button = CreateFrame('Button', nil, parent)
	button:SetPoint('TOPLEFT', parent, 'TOPLEFT', LEFT, -y)
	button:SetSize(INNER, BOX)

	local outline = Texture(button, 'BACKGROUND', colors.muted, 0.35)
	outline:SetPoint('TOPLEFT')
	outline:SetSize(BOX, BOX)

	local box = Texture(button, 'BORDER', colors.border)
	box:SetPoint('TOPLEFT', outline, 'TOPLEFT', 1, -1)
	box:SetPoint('BOTTOMRIGHT', outline, 'BOTTOMRIGHT', -1, 1)

	local pip = Texture(button, 'ARTWORK', colors.accent)
	pip:SetPoint('TOPLEFT', outline, 'TOPLEFT', 3, -3)
	pip:SetPoint('BOTTOMRIGHT', outline, 'BOTTOMRIGHT', -3, 3)

	local hatch = Hatch(button)
	hatch:SetAllPoints(outline)

	local label = Label(button, 12, colors.text, L[text])
	label:SetJustifyH('LEFT')
	label:SetWordWrap(false)

	control.note = Note(button)
	control.note:SetPoint('RIGHT', button, 'RIGHT', 0, 0)

	button:SetScript('OnClick', function() Umbra:SetOption(key, not Umbra:GetOption(key)) end)
	button:SetScript('OnEnter', function()
		if button:IsEnabled() then label:SetTextColor(unpack(colors.accent)) end
	end)
	button:SetScript('OnLeave', function()
		if button:IsEnabled() then label:SetTextColor(unpack(colors.text)) end
	end)

	function control:Refresh(refused)
		pip:SetShown(Umbra:GetOption(key) and true or false)
		hatch:SetShown(refused ~= nil)
		button:SetEnabled(refused == nil)

		label:SetTextColor(unpack(refused and colors.muted or colors.text))
		label:SetAlpha(refused and 0.6 or 1)

		self.note:SetText(refused and L[refused] or '')
		self.note:SetShown(refused ~= nil)

		-- While a note stands at the end of the row the label stops short of
		-- it, and the client shortens it rather than printing one over the
		-- other. The width the sheet has is not the width the client's font
		-- takes.
		label:ClearAllPoints()
		label:SetPoint('LEFT', outline, 'RIGHT', 8, 0)

		if refused then
			label:SetPoint('RIGHT', self.note, 'LEFT', -6, 0)
		end
	end

	return control
end

--[[ Where the window was left
Kept like a frame's position, as a point on UIParent. Forever never reads it
back, and a window that opens in the middle is no loss there.
--]]
local function SavePosition(frame)
	local point, _, relativePoint, x, y = frame:GetPoint()

	UmbraUnitFramesDB.options = {point = point, relativePoint = relativePoint,
		x = math.floor(x + 0.5), y = math.floor(y + 0.5)}
end

local function RestorePosition(frame)
	local saved = UmbraUnitFramesDB.options

	frame:ClearAllPoints()

	if saved and saved.point then
		frame:SetPoint(saved.point, UIParent, saved.relativePoint, saved.x, saved.y)
	else
		frame:SetPoint('CENTER', UIParent, 'CENTER', 0, 80)
	end
end

local function Build()
	local frame = CreateFrame('Frame', nil, UIParent)

	-- Named for Escape alone, which is told about a frame by name.
	_G.UmbraOptionsFrame = frame

	frame:SetFrameStrata('DIALOG')
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag('LeftButton')
	frame:SetScript('OnDragStart', frame.StartMoving)
	frame:SetScript('OnDragStop', function(self)
		self:StopMovingOrSizing()
		SavePosition(self)
	end)

	-- The border lies a pixel outside, the ground fills the frame, and the
	-- accent edge stands where a unit frame keeps its class edge: the
	-- interface's color at the place a unit keeps its own.
	local border = Texture(frame, 'BACKGROUND', colors.border)
	border:SetPoint('TOPLEFT', -1, 1)
	border:SetPoint('BOTTOMRIGHT', 1, -1)

	Texture(frame, 'BACKGROUND', colors.background, nil, 1):SetAllPoints()

	local edge = Texture(frame, 'ARTWORK', colors.accent)
	edge:SetPoint('TOPLEFT')
	edge:SetPoint('BOTTOMLEFT')
	edge:SetWidth(EDGE)

	local title = Label(frame, 13, colors.text, 'Umbra Unit Frames')
	title:SetPoint('TOPLEFT', frame, 'TOPLEFT', LEFT, -12)

	local close = CreateFrame('Button', nil, frame)
	close:SetSize(18, 18)
	close:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -PAD + 3, -9)
	Texture(close, 'BACKGROUND', colors.border):SetAllPoints()

	local cross = Label(close, 14, colors.muted, '×')
	cross:SetPoint('CENTER', 0, 1)

	close:SetScript('OnClick', function() frame:Hide() end)
	close:SetScript('OnEnter', function() cross:SetTextColor(unpack(colors.accent)) end)
	close:SetScript('OnLeave', function() cross:SetTextColor(unpack(colors.muted)) end)

	local function Rule(y)
		local rule = Texture(frame, 'ARTWORK', colors.muted, 0.18)
		rule:SetPoint('TOPLEFT', frame, 'TOPLEFT', EDGE, -y)
		rule:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', 0, -y)
		rule:SetHeight(1)
	end

	Rule(HEADER)

	-- The rows, top to bottom, each advancing `y` by what it takes. The same
	-- walk `options_layout` makes in the sheet.
	local y = HEADER
	local controls = {}

	local function Add(kind, ...)
		if kind == 'section' then
			Section(frame, y, ...)
			y = y + 22
		elseif kind == 'segment' then
			local key = ...
			controls[key] = Segmented(frame, y, ...)
			y = y + SEGMENT + 8
		else
			local key = ...
			controls[key] = Check(frame, y, ...)
			y = y + BOX + 10
		end
	end

	Add('section', 'Layout')
	Add('segment', 'layout', {{'modern', 'Modern'}, {'classic', 'Classic'}})
	Add('section', 'Health bar')
	Add('segment', 'health', {{false, 'Neutral'}, {true, 'Class color'}})
	Add('section', 'Blizzard frames')
	Add('check', 'auras', 'Hide Blizzard buffs & debuffs')
	Add('check', 'group', 'Hide Blizzard group manager')
	Add('section', 'Display')
	Add('check', 'minimap', 'Show minimap button')

	-- The buttons stand under a heading of their own rather than under a
	-- rule: "Frames" says what they move and reset, so each label can be one
	-- word, in German as well.
	Add('section', 'Frames')

	local half = (INNER - 6) / 2

	local unlock = Umbra.PlainButton(frame, L['Unlock'], half)
	unlock:SetPoint('TOPLEFT', frame, 'TOPLEFT', LEFT, -y)

	unlock.line = Texture(unlock, 'ARTWORK', colors.accent)
	unlock.line:SetPoint('BOTTOMLEFT')
	unlock.line:SetPoint('BOTTOMRIGHT')
	unlock.line:SetHeight(2)

	unlock.hatch = Hatch(unlock)
	unlock.hatch:SetAllPoints()

	unlock:SetScript('OnClick', function()
		Umbra:SetLocked(not Umbra.locked)
	end)

	local reset = Umbra.PlainButton(frame, L['Reset'], half)
	reset:SetPoint('TOPLEFT', unlock, 'TOPRIGHT', 6, 0)
	reset:SetScript('OnClick', function() Umbra:ResetPositions() end)

	y = y + BUTTON + 14

	-- A release is a number and gets its `v`; a checkout says `dev`, or
	-- `dev-<commit>` once tools/install.ps1 has stamped it, and `vdev` reads
	-- as a typo.
	local version = Umbra.version:find('^%d') and ('v' .. Umbra.version) or Umbra.version

	local command = Label(frame, 9, colors.muted, '/uuf help  ·  ' .. version)
	command:SetPoint('TOPLEFT', frame, 'TOPLEFT', LEFT, -y)
	command:SetAlpha(0.7)

	--[[ The heart is a texture here, not a character
	In chat it is U+2665 and draws, because the chat frame's font has it. The
	labels here are set in Friz Quadrata, which does not, and the client puts
	an empty box where the glyph should be — measured in the first build of
	this window. So the footer draws Media/heart, ours for the same reason the
	hatch is ours, in the red the chat heart is.
	--]]
	if Umbra.author then
		local credit = Label(frame, 9, colors.muted, 'by ' .. Umbra.author)
		credit:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -PAD, -y)
		credit:SetAlpha(0.7)

		local heart = frame:CreateTexture(nil, 'OVERLAY')
		heart:SetTexture(Umbra.media.heart)
		heart:SetVertexColor(unpack(colors.auraHarmful))
		heart:SetSize(8, 8)
		heart:SetPoint('RIGHT', credit, 'LEFT', -3, 0)
	end

	frame:SetSize(WIDTH, y + 9 + PAD)

	--[[ What the window refuses, and why
	Only what the client itself refuses. The layout is not one of them: a set
	picked in a fight is kept and applied when it ends, which is what `/uuf
	layout` has always done, so the switch stays live and says so. Unlocking
	is refused outright, as the command refuses it — locking is not, because
	being left with frames you can still drag is the worse place to be.

	On a client where the party column stood down there is no column to hand
	the group over to, and the switch for Blizzard's panel would promise a
	swap that cannot happen.
	--]]
	function frame:Refresh()
		controls.layout:Refresh(fighting and 'applies after combat' or nil)
		controls.health:Refresh()
		controls.auras:Refresh()
		controls.group:Refresh(Umbra.groupStoodDown and 'not on this client' or nil)
		controls.minimap:Refresh()

		local unlocked = not Umbra.locked
		local refused = fighting and not unlocked

		unlock.UmbraLabel:SetText(L[unlocked and 'Lock' or 'Unlock'])
		unlock.UmbraLabel:SetTextColor(unpack(unlocked and colors.accent or colors.text))
		unlock.UmbraLabel:SetAlpha(refused and 0.45 or 1)
		unlock.line:SetShown(unlocked)
		unlock.hatch:SetShown(refused)
		unlock:SetEnabled(not refused)
	end

	-- PlainButton puts its own color back on leaving; the unlock button's
	-- color says whether the frames are loose, so the state has the last word.
	-- A refused button does not light up either.
	unlock:HookScript('OnLeave', function() frame:Refresh() end)
	unlock:HookScript('OnEnter', function(self)
		if not self:IsEnabled() then frame:Refresh() end
	end)

	frame:RegisterEvent('PLAYER_REGEN_DISABLED')
	frame:RegisterEvent('PLAYER_REGEN_ENABLED')
	frame:SetScript('OnEvent', function(self, event)
		fighting = event == 'PLAYER_REGEN_DISABLED'

		if self:IsShown() then self:Refresh() end
	end)

	frame:SetScript('OnShow', function(self) self:Refresh() end)

	frame:Hide()
	RestorePosition(frame)

	if type(_G.UISpecialFrames) == 'table' then
		tinsert(UISpecialFrames, 'UmbraOptionsFrame')
	end

	return frame
end

--[[ Umbra:ToggleOptions() / Umbra:ShowOptions()
Opens the window, building it the first time. Built through `pcall`, the way
the report is: `/uuf` runs inside the chat box's Enter handling, and a window
that throws while it is built must not take the chat frame with it. Answers
whether there is a window to show.
--]]
local function Ensure()
	if window then return true end

	fighting = InCombatLockdown()

	local ok, built = pcall(Build)

	if not ok then
		Umbra:Debug('options window failed:', built)
		print(Umbra.prefix .. 'the options window could not be built: ' .. tostring(built)
			.. '. /uuf help lists the commands, which do the same.')

		return false
	end

	window = built

	return true
end

function Umbra:ShowOptions()
	if Ensure() then window:Show() end
end

function Umbra:ToggleOptions()
	if not Ensure() then return end

	window:SetShown(not window:IsShown())
end

--[[ A page in the client's own options
Options › AddOns is where people look first, so Umbra is listed there — as a
page with one button that opens this window, rather than a second copy of the
switches built from Blizzard's widgets. Two sets of controls for one setting
are two places for them to disagree.

The Settings API is on all five clients, checked against each one's interface
code: `RegisterCanvasLayoutCategory`, `RegisterAddOnCategory` and
`OpenToCategory` are in Blizzard_Settings_Shared on live, forever, classic,
classic_anniversary and classic_era alike. It is still asked for rather than
assumed, and a client without it simply has no page.
--]]
local function Canvas()
	local canvas = CreateFrame('Frame')

	local logo = canvas:CreateTexture(nil, 'ARTWORK')
	logo:SetTexture([[Interface\AddOns\UmbraUnitFrames\Media\logo]])
	logo:SetSize(64, 64)
	logo:SetPoint('TOPLEFT', canvas, 'TOPLEFT', 16, -16)

	local title = Label(canvas, 16, colors.text, 'Umbra Unit Frames')
	title:SetPoint('TOPLEFT', logo, 'TOPRIGHT', 14, -6)

	local body = Label(canvas, 12, colors.muted,
		L['Every setting lives in a small window of its own, and takes effect where you stand.'])
	body:SetPoint('TOPLEFT', title, 'BOTTOMLEFT', 0, -8)
	body:SetPoint('RIGHT', canvas, 'RIGHT', -16, 0)
	body:SetJustifyH('LEFT')

	local open = Umbra.PlainButton(canvas, L['Open Umbra options'], 180)
	open:SetPoint('TOPLEFT', logo, 'BOTTOMLEFT', 0, -16)

	-- The client's panel is closed first: it would otherwise sit over half the
	-- screen next to a window that is now the one being worked with.
	open:SetScript('OnClick', function()
		if _G.SettingsPanel and SettingsPanel:IsShown() then
			pcall(HideUIPanel, SettingsPanel)
		end

		Umbra:ShowOptions()
	end)

	local hint = Label(canvas, 11, colors.muted, L['or type /uuf'])
	hint:SetPoint('LEFT', open, 'RIGHT', 12, 0)

	return canvas
end

local registrar = CreateFrame('Frame')
registrar:RegisterEvent('PLAYER_LOGIN')
registrar:SetScript('OnEvent', function(self)
	self:UnregisterEvent('PLAYER_LOGIN')

	local settings = _G.Settings

	if type(settings) ~= 'table' or type(settings.RegisterCanvasLayoutCategory) ~= 'function' then
		Umbra:Debug('no Settings API, no page in the options')
		return
	end

	local ok, err = pcall(function()
		local category = settings.RegisterCanvasLayoutCategory(Canvas(), 'Umbra Unit Frames')
		settings.RegisterAddOnCategory(category)
		Umbra.settingsCategory = category
	end)

	if not ok then
		Umbra:Debug('options page refused:', err)
	end
end)
